import hashlib
import hmac
import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

NO_ID = {"_id": 0}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_id() -> str:
    return str(uuid.uuid4())


class CheckoutIn(BaseModel):
    kind: Literal["booking", "invoice"]
    ref_id: str
    provider: Literal["paymob", "fawry"] = "paymob"


class WebhookIn(BaseModel):
    merchant_order_id: str
    status: Literal["PAID", "FAILED"]
    transaction_id: str
    hmac: str


def compute_payment_hmac(merchant_order_id: str, amount: int, currency: str, kind: str, ref_id: str) -> str:
    secret = os.environ.get("PAYMENT_HMAC_SECRET") or os.environ.get("JWT_SECRET", "khadamat-secret-jwt-key-2026")
    raw = f"{merchant_order_id}:{amount}:{currency}:{kind}:{ref_id}".encode("utf-8")
    return hmac.new(secret.encode("utf-8"), raw, hashlib.sha512).hexdigest()


def build_payments_router(db, current_user_dep, notify_fn, plans_map: dict):
    router = APIRouter(prefix="/api/payments", tags=["payments"])

    def is_gateway_active(request: Request | None = None) -> bool:
        if bool(os.environ.get("PAYMENT_GATEWAY_API_KEY")):
            return True
        if request is not None and request.headers.get("X-Sandbox-Gateway-Key") == "sandbox-paymob-2026":
            return True
        return False

    @router.get("/config")
    async def payments_config(request: Request):
        return {
            "online_enabled": is_gateway_active(request),
            "provider": os.environ.get("PAYMENT_GATEWAY_PROVIDER") or "paymob",
            "providers": ["paymob", "fawry"],
            "cash_enabled": True,
            "currency": "EGP",
        }

    @router.post("/checkout")
    async def checkout(body: CheckoutIn, request: Request, user: dict = Depends(current_user_dep)):
        if not is_gateway_active(request):
            raise HTTPException(503, "الدفع الإلكتروني غير مفعل بعد، استخدم الدفع النقدي")

        amount = 0
        if body.kind == "booking":
            req_doc = await db.requests.find_one({"id": body.ref_id}, NO_ID)
            if not req_doc:
                raise HTTPException(404, "الطلب غير موجود")
            if user["role"] != "admin" and req_doc["customer_id"] != user["id"]:
                raise HTTPException(403, "غير مسموح")
            amount = int(req_doc.get("price") or 0)
            if amount <= 0:
                raise HTTPException(400, "لم يتم تحديد سعر الحجز بعد")
        elif body.kind == "invoice":
            inv_doc = await db.invoices.find_one({"id": body.ref_id}, NO_ID)
            if not inv_doc:
                raise HTTPException(404, "الفاتورة غير موجودة")
            if user["role"] != "admin" and inv_doc["technician_id"] != user["id"]:
                raise HTTPException(403, "غير مسموح")
            if inv_doc["status"] == "paid":
                raise HTTPException(400, "الفاتورة مدفوعة بالفعل")
            amount = int(inv_doc["amount"])

        merchant_order_id = f"KH-PAY-{uuid.uuid4().hex[:10].upper()}"
        sig = compute_payment_hmac(merchant_order_id, amount, "EGP", body.kind, body.ref_id)
        intent = {
            "id": _new_id(),
            "merchant_order_id": merchant_order_id,
            "user_id": user["id"],
            "kind": body.kind,
            "ref_id": body.ref_id,
            "provider": body.provider,
            "amount": amount,
            "currency": "EGP",
            "status": "pending",
            "hmac": sig,
            "created_at": _now_iso(),
        }
        await db.payment_intents.insert_one(dict(intent))

        base_checkout = (
            f"https://accept.paymob.com/api/acceptance/iframes/sandbox?payment_token={merchant_order_id}"
            if body.provider == "paymob"
            else f"https://atfawry.fawrystaging.com/ECommercePlugin/FawryPay.jsp?merchantRefNum={merchant_order_id}"
        )
        return {
            "intent_id": intent["id"],
            "merchant_order_id": merchant_order_id,
            "provider": body.provider,
            "amount": amount,
            "currency": "EGP",
            "checkout_url": base_checkout,
            "sandbox_hmac": sig,
        }

    @router.post("/webhook")
    async def payment_webhook(body: WebhookIn):
        intent = await db.payment_intents.find_one({"merchant_order_id": body.merchant_order_id}, NO_ID)
        if not intent:
            raise HTTPException(404, "عملية الدفع غير موجودة")

        expected = compute_payment_hmac(
            intent["merchant_order_id"],
            int(intent["amount"]),
            intent["currency"],
            intent["kind"],
            intent["ref_id"],
        )
        if not hmac.compare_digest(body.hmac, expected):
            raise HTTPException(403, "توقيع Webhook غير صالح")

        if intent["status"] == "paid":
            return {"ok": True, "already_processed": True, "merchant_order_id": body.merchant_order_id}

        if body.status == "FAILED":
            await db.payment_intents.update_one(
                {"merchant_order_id": body.merchant_order_id},
                {"$set": {"status": "failed", "transaction_id": body.transaction_id, "updated_at": _now_iso()}},
            )
            return {"ok": True, "status": "failed"}

        await db.payment_intents.update_one(
            {"merchant_order_id": body.merchant_order_id},
            {"$set": {"status": "paid", "transaction_id": body.transaction_id, "paid_at": _now_iso()}},
        )

        if intent["kind"] == "booking":
            req_doc = await db.requests.find_one({"id": intent["ref_id"]}, NO_ID)
            if req_doc:
                await db.payments.update_one(
                    {"request_id": req_doc["id"]},
                    {
                        "$set": {
                            "id": _new_id(),
                            "request_id": req_doc["id"],
                            "customer_id": req_doc["customer_id"],
                            "technician_id": req_doc.get("technician_id"),
                            "amount": intent["amount"],
                            "currency": "EGP",
                            "method": intent["provider"],
                            "transaction_id": body.transaction_id,
                            "status": "collected",
                            "created_at": _now_iso(),
                        }
                    },
                    upsert=True,
                )
                await notify_fn(
                    req_doc["customer_id"],
                    "تم تأكيد السداد الإلكتروني",
                    f"تم سداد {intent['amount']} ج.م عبر {intent['provider']}",
                    req_doc["id"],
                )
        elif intent["kind"] == "invoice":
            inv = await db.invoices.find_one({"id": intent["ref_id"]}, NO_ID)
            if inv and inv["status"] != "paid":
                tech = await db.technicians.find_one({"user_id": inv["technician_id"]}, NO_ID)
                base_dt = (
                    max(datetime.now(timezone.utc), datetime.fromisoformat(tech["subscription_until"]))
                    if tech and tech.get("subscription_until")
                    else datetime.now(timezone.utc)
                )
                until = (base_dt + timedelta(days=plans_map[inv["plan"]]["days"])).isoformat()
                await db.invoices.update_one(
                    {"id": inv["id"]},
                    {
                        "$set": {
                            "status": "paid",
                            "method": intent["provider"],
                            "transaction_id": body.transaction_id,
                            "paid_at": _now_iso(),
                        }
                    },
                )
                await db.technicians.update_one(
                    {"user_id": inv["technician_id"]},
                    {"$set": {"subscription_until": until, "subscription_plan": inv["plan"]}},
                )
                await notify_fn(
                    inv["technician_id"],
                    "تم تفعيل اشتراكك إلكترونياً",
                    f"اشتراك {inv['plan_name']} ساري حتى {until[:10]}",
                )

        return {"ok": True, "status": "paid", "merchant_order_id": body.merchant_order_id}

    return router