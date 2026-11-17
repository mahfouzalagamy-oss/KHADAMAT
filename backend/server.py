import asyncio
import hashlib
import json
import logging
import os
import random
import re
import uuid
from contextlib import suppress
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Literal, Optional

import jwt
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, Field
from pymongo import ASCENDING, DESCENDING, IndexModel, ReturnDocument
from starlette.middleware.cors import CORSMiddleware

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / ".env")

try:
    from emergentintegrations.llm.chat import LlmChat, UserMessage  # type: ignore
except ImportError:
    LlmChat = None
    UserMessage = None

import socket
_mongo_url = os.environ.get("MONGO_URL", "mongodb://127.0.0.1:27017")
_use_mock = False
if "localhost" in _mongo_url or "127.0.0.1" in _mongo_url:
    try:
        with socket.create_connection(("127.0.0.1", 27017), timeout=0.5):
            pass
    except OSError:
        _use_mock = True

if _use_mock:
    from mongomock_motor import AsyncMongoMockClient
    client = AsyncMongoMockClient()
else:
    client = AsyncIOMotorClient(_mongo_url)
db = client[os.environ.get("DB_NAME", "khadamat_db")]
APP_ENV = os.environ.get("APP_ENV", "development").strip().lower()
IS_PRODUCTION = APP_ENV == "production"

JWT_SECRET = os.environ.get("JWT_SECRET", "" if IS_PRODUCTION else "khadamat-dev-secret-change-in-prod-2026")
if IS_PRODUCTION and (not JWT_SECRET or "dev-secret" in JWT_SECRET or len(JWT_SECRET) < 32):
    raise RuntimeError("CRITICAL SECURITY ERROR: Strong JWT_SECRET env var (>=32 chars) must be set when APP_ENV=production.")

ALLOW_DEMO_OTP = os.environ.get("ALLOW_DEMO_OTP", "false" if IS_PRODUCTION else "true").lower() == "true"
DEMO_OTP = os.environ.get("DEMO_OTP", "" if IS_PRODUCTION else "123456") if ALLOW_DEMO_OTP else ""
SEED_DEFAULT_ADMIN = os.environ.get("SEED_DEFAULT_ADMIN", "false" if IS_PRODUCTION else "true").lower() == "true"

EMERGENT_LLM_KEY = os.environ.get("EMERGENT_LLM_KEY", "")
DEMO_AUTO_OFFERS = os.environ.get("DEMO_AUTO_OFFERS", "true") == "true"
logger = logging.getLogger(__name__)

INDEXES: dict[str, list[IndexModel]] = {
    "users": [
        IndexModel([("id", ASCENDING)], name="id", unique=True),
        IndexModel([("phone", ASCENDING)], name="phone", unique=True),
    ],
    "technicians": [
        IndexModel([("user_id", ASCENDING)], name="user_id", unique=True),
        IndexModel([("company_id", ASCENDING)], name="company_id"),
        IndexModel([("identity_status", ASCENDING)], name="identity_status"),
    ],
    "requests": [
        IndexModel([("id", ASCENDING)], name="id", unique=True),
        IndexModel([("customer_id", ASCENDING), ("created_at", DESCENDING)], name="customer"),
        IndexModel([("technician_id", ASCENDING), ("created_at", DESCENDING)], name="tech"),
        IndexModel([("status", ASCENDING), ("category_id", ASCENDING)], name="status_cat"),
    ],
    "offers": [
        IndexModel([("request_id", ASCENDING)], name="request_id"),
        IndexModel([("id", ASCENDING)], name="id", unique=True),
    ],
    "messages": [
        IndexModel([("request_id", ASCENDING), ("created_at", ASCENDING)], name="req_time"),
        IndexModel([("client_id", ASCENDING)], name="client_id"),
    ],
    "notifications": [
        IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)], name="user_time"),
    ],
    "invoices": [
        IndexModel([("id", ASCENDING)], name="id", unique=True),
        IndexModel([("technician_id", ASCENDING)], name="technician_id"),
    ],
    "payments": [
        IndexModel([("request_id", ASCENDING)], name="request_id"),
    ],
    "otp_challenges": [
        IndexModel([("phone", ASCENDING)], name="phone", unique=True),
    ],
}


async def ensure_indexes() -> None:
    for collection, models in INDEXES.items():
        for model in models:
            try:
                await db[collection].create_indexes([model])
            except Exception as exc:
                logger.error("ensure_indexes(%s.%s): %s", collection, model.document["name"], exc)


app = FastAPI()


@app.get("/health", include_in_schema=False)
@app.head("/health", include_in_schema=False)
async def health():
    return {"status": "ok"}


api = APIRouter(prefix="/api")
bearer = HTTPBearer(auto_error=False)
NO_ID = {"_id": 0}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def new_id() -> str:
    return str(uuid.uuid4())


# ---------------------------------------------------------------- reference data
CATEGORIES = [
    {"id": "plumbing", "name": "سباكة", "icon": "water", "services": [
        ("تسليك مواسير وبلاعات", 150, 300), ("تركيب خلاط أو حنفية", 120, 250),
        ("إصلاح تسريب مياه", 150, 400), ("تركيب سخان", 250, 450)]},
    {"id": "electricity", "name": "كهرباء", "icon": "flash", "services": [
        ("إصلاح ماس كهربائي", 150, 350), ("تركيب نجفة أو إضاءة", 100, 250),
        ("تمديد بريزة أو مفتاح", 80, 180), ("فحص لوحة الكهرباء", 200, 400)]},
    {"id": "ac", "name": "تكييف", "icon": "snow", "services": [
        ("صيانة وتنظيف تكييف", 250, 450), ("شحن فريون", 400, 700),
        ("فك وتركيب تكييف", 600, 1100)]},
    {"id": "cleaning", "name": "تنظيف", "icon": "sparkles", "services": [
        ("تنظيف شقة كامل", 500, 1200), ("تنظيف سجاد وأنتريه", 300, 700),
        ("تنظيف بعد التشطيب", 900, 2000)]},
    {"id": "carpentry", "name": "نجارة", "icon": "hammer", "services": [
        ("إصلاح أبواب وشبابيك", 150, 350), ("تركيب مطبخ أو دولاب", 400, 900),
        ("تغيير كالون", 100, 200)]},
    {"id": "painting", "name": "دهانات", "icon": "color-palette", "services": [
        ("دهان غرفة", 1200, 2500), ("معالجة رطوبة وشروخ", 400, 900)]},
    {"id": "appliances", "name": "أجهزة منزلية", "icon": "tv", "services": [
        ("صيانة غسالة", 200, 450), ("صيانة ثلاجة", 250, 550), ("صيانة بوتاجاز", 150, 300)]},
    {"id": "pest", "name": "مكافحة حشرات", "icon": "bug", "services": [
        ("رش شقة ضد الحشرات", 300, 600), ("مكافحة قوارض", 350, 700)]},
]
SERVICES = {}
for cat in CATEGORIES:
    for i, (name, lo, hi) in enumerate(cat["services"]):
        sid = f"{cat['id']}-{i + 1}"
        SERVICES[sid] = {"id": sid, "category_id": cat["id"], "name": name, "price_min": lo,
                         "price_max": hi, "duration_minutes": 60 + 30 * (i % 3)}
CAT_BY_ID = {c["id"]: c for c in CATEGORIES}

AREAS = ["حي الجامعة", "توريل", "المشاية", "جديلة", "سندوب", "الحوار", "شارع الجيش",
         "حي الجمهورية", "المنصورة الجديدة", "طلخا"]

PLANS = {
    "monthly": {"id": "monthly", "name": "شهري", "price": 299, "days": 30},
    "quarterly": {"id": "quarterly", "name": "ربع سنوي", "price": 799, "days": 90},
    "yearly": {"id": "yearly", "name": "سنوي", "price": 2799, "days": 365},
}
STATUS_FLOW = ["booked", "on_the_way", "arrived", "in_progress", "completed"]
STATUS_AR = {"open": "بانتظار العروض", "booked": "تم الحجز", "on_the_way": "الفني في الطريق",
             "arrived": "الفني وصل", "in_progress": "جاري العمل", "completed": "تم الإنجاز",
             "cancelled": "ملغي"}


# ---------------------------------------------------------------- auth helpers
def normalize_eg_phone(value: str) -> str:
    v = re.sub(r"[\s()\-]", "", value or "")
    if v.startswith("+20"):
        v = "0" + v[3:]
    elif v.startswith("0020"):
        v = "0" + v[4:]
    elif v.startswith("20") and len(v) == 12:
        v = "0" + v[2:]
    elif v.startswith("1") and len(v) == 10:
        v = "0" + v
    if not re.fullmatch(r"01[0125][0-9]{8}", v):
        raise HTTPException(422, "رقم الموبايل غير صحيح، استخدم رقم مصري مثل 01012345678")
    return "+20" + v[1:]


def make_token(user: dict) -> str:
    n = datetime.now(timezone.utc)
    return jwt.encode({"sub": user["id"], "role": user["role"], "iat": n, "exp": n + timedelta(days=30)},
                      JWT_SECRET, algorithm="HS256")


async def current_user(cred: Optional[HTTPAuthorizationCredentials] = Depends(bearer)) -> dict:
    if not cred:
        raise HTTPException(401, "يجب تسجيل الدخول")
    try:
        payload = jwt.decode(cred.credentials, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(401, "انتهت الجلسة، سجّل الدخول مرة أخرى")
    user = await db.users.find_one({"id": payload.get("sub")}, NO_ID)
    if not user:
        raise HTTPException(401, "المستخدم غير موجود")
    return user


def require(*roles):
    async def dep(user: dict = Depends(current_user)) -> dict:
        if user["role"] not in roles:
            raise HTTPException(403, "غير مسموح")
        return user
    return dep


async def notify(user_id: str, title: str, body: str, request_id: Optional[str] = None):
    await db.notifications.insert_one({"id": new_id(), "user_id": user_id, "title": title, "body": body,
                                       "request_id": request_id, "read": False, "created_at": now_iso()})


def sub_active(tech: dict) -> bool:
    until = tech.get("subscription_until")
    return bool(until) and until > now_iso()


async def tech_profile(user_id: str) -> dict:
    t = await db.technicians.find_one({"user_id": user_id}, NO_ID)
    if not t:
        raise HTTPException(404, "ملف الفني غير موجود")
    return t


def new_tech_doc(user: dict, categories: List[str], company_id: Optional[str] = None, **extra) -> dict:
    doc = {"user_id": user["id"], "name": user["name"], "phone": user["phone"], "categories": categories,
           "bio": "", "identity_status": "none", "national_id": "", "review_note": "", "rating": 0.0,
           "reviews_count": 0, "jobs_done": 0, "earnings": 0, "online": True, "subscription_until": None,
           "subscription_plan": None, "company_id": company_id, "is_demo": False, "created_at": now_iso()}
    doc.update(extra)
    return doc


# ---------------------------------------------------------------- models
class PhoneIn(BaseModel):
    phone: str


class VerifyIn(BaseModel):
    phone: str
    otp: str = Field(pattern=r"^[0-9]{6}$")
    role: Literal["customer", "technician"] = "customer"
    name: Optional[str] = None


class ProfileIn(BaseModel):
    name: str = Field(min_length=2, max_length=60)


class AiIn(BaseModel):
    text: str = Field(min_length=3, max_length=2000)
    category_id: Optional[str] = None


class RequestIn(BaseModel):
    category_id: str
    service_id: Optional[str] = None
    description: str = Field(min_length=3, max_length=2000)
    urgency: Literal["normal", "urgent"] = "normal"
    area: str
    address: str = Field(min_length=3, max_length=300)
    lat: Optional[float] = None
    lng: Optional[float] = None
    scheduled_at: str
    payment_method: Literal["cash", "online"] = "cash"
    photos: List[str] = Field(default_factory=list, max_length=6)


class OfferIn(BaseModel):
    price: int = Field(ge=50, le=100000)
    eta_minutes: int = Field(ge=10, le=1440)
    note: str = Field(default="", max_length=300)


class StatusIn(BaseModel):
    status: Literal["on_the_way", "arrived", "in_progress", "completed"]


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
    client_id: Optional[str] = None


class TechProfileIn(BaseModel):
    categories: List[str]
    bio: str = Field(default="", max_length=300)
    online: bool = True


class IdentityIn(BaseModel):
    full_name: str = Field(min_length=5, max_length=80)
    national_id: str = Field(pattern=r"^[23][0-9]{13}$")
    id_front_url: Optional[str] = None
    id_back_url: Optional[str] = None


class SubscribeIn(BaseModel):
    plan: Literal["monthly", "quarterly", "yearly"]


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]
    note: str = Field(default="", max_length=300)


class CompanyTechIn(BaseModel):
    phone: str
    name: str = Field(min_length=2, max_length=60)
    categories: List[str]


class CheckoutIn(BaseModel):
    kind: Literal["booking", "invoice"]
    ref_id: str


# ---------------------------------------------------------------- auth routes
@api.post("/auth/request-otp")
async def request_otp(body: PhoneIn):
    phone = normalize_eg_phone(body.phone)
    await db.otp_challenges.update_one(
        {"phone": phone},
        {"$set": {"phone": phone, "otp_hash": hashlib.sha256(DEMO_OTP.encode()).hexdigest(),
                  "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(), "attempts": 0}},
        upsert=True)
    exists = await db.users.find_one({"phone": phone}, {"_id": 0, "id": 1})
    return {"sent": True, "phone": phone, "is_new": not exists, "demo_code": DEMO_OTP}


@api.post("/auth/verify-otp")
async def verify_otp(body: VerifyIn):
    phone = normalize_eg_phone(body.phone)
    c = await db.otp_challenges.find_one({"phone": phone})
    if not c or c["expires_at"] < now_iso() or c["attempts"] >= 5:
        raise HTTPException(400, "انتهت صلاحية الكود، اطلب كود جديد")
    if hashlib.sha256(body.otp.encode()).hexdigest() != c["otp_hash"]:
        await db.otp_challenges.update_one({"phone": phone}, {"$inc": {"attempts": 1}})
        raise HTTPException(400, "الكود غير صحيح")
    await db.otp_challenges.delete_one({"phone": phone})
    user = await db.users.find_one({"phone": phone}, NO_ID)
    if not user:
        user = {"id": new_id(), "phone": phone, "role": body.role,
                "name": (body.name or "").strip() or "مستخدم جديد", "created_at": now_iso()}
        await db.users.insert_one(dict(user))
        if body.role == "technician":
            await db.technicians.insert_one(new_tech_doc(user, []))
    return {"token": make_token(user), "user": user}


@api.get("/me")
async def me(user: dict = Depends(current_user)):
    return user


@api.put("/me")
async def update_me(body: ProfileIn, user: dict = Depends(current_user)):
    await db.users.update_one({"id": user["id"]}, {"$set": {"name": body.name}})
    await db.technicians.update_one({"user_id": user["id"]}, {"$set": {"name": body.name}})
    return {**user, "name": body.name}


# ---------------------------------------------------------------- catalog
@api.get("/catalog")
async def catalog():
    cats = [{"id": c["id"], "name": c["name"], "icon": c["icon"],
             "services_count": len(c["services"]),
             "price_from": min(s[1] for s in c["services"])} for c in CATEGORIES]
    return {"categories": cats, "areas": AREAS, "city": "المنصورة، الدقهلية", "currency": "EGP"}


@api.get("/catalog/{category_id}")
async def category_detail(category_id: str):
    cat = CAT_BY_ID.get(category_id)
    if not cat:
        raise HTTPException(404, "القسم غير موجود")
    services = [s for s in SERVICES.values() if s["category_id"] == category_id]
    return {"id": cat["id"], "name": cat["name"], "icon": cat["icon"], "services": services}


# ---------------------------------------------------------------- AI
AI_SYSTEM = (
    "أنت مساعد لمنصة خدمات منزلية في المنصورة بمصر. المستخدم يكتب وصف لمشكلة في البيت بالعامية المصرية. "
    "رد فقط بكائن JSON صالح بدون أي نص إضافي، بالمفاتيح: "
    '"category_id" (واحد من: ' + ", ".join(c["id"] for c in CATEGORIES) + '), '
    '"refined_description" (وصف واضح ومنظم بالعربي للفني في 2-3 جمل), '
    '"urgency" ("normal" أو "urgent"), '
    '"questions" (قائمة من سؤالين قصيرين للتوضيح), '
    '"tips" (نصيحة أمان قصيرة واحدة), '
    '"price_min" و "price_max" (تقدير بالجنيه المصري كأرقام صحيحة).'
)


@api.post("/ai/describe")
async def ai_describe(body: AiIn, user: dict = Depends(current_user)):
    cat_id = body.category_id if body.category_id in CAT_BY_ID else "plumbing"
    if LlmChat is not None and EMERGENT_LLM_KEY:
        hint = f"\nالقسم المختار: {CAT_BY_ID[body.category_id]['name']}" if body.category_id in CAT_BY_ID else ""
        chat = LlmChat(api_key=EMERGENT_LLM_KEY, session_id=f"ai-{user['id']}-{new_id()}",
                       system_message=AI_SYSTEM).with_model("openai", "gpt-5.6-terra")
        try:
            raw = await chat.send_message(UserMessage(text=body.text + hint))
            match = re.search(r"\{.*\}", raw, re.S)
            data = json.loads(match.group(0) if match else raw)
            cat_id = data.get("category_id") if data.get("category_id") in CAT_BY_ID else cat_id
            return {
                "category_id": cat_id,
                "category_name": CAT_BY_ID[cat_id]["name"],
                "refined_description": str(data.get("refined_description", body.text)),
                "urgency": "urgent" if data.get("urgency") == "urgent" else "normal",
                "questions": [str(q) for q in (data.get("questions") or [])][:3],
                "tips": str(data.get("tips", "")),
                "price_min": int(data.get("price_min") or 150),
                "price_max": int(data.get("price_max") or 400),
            }
        except Exception as exc:
            logger.error("ai_describe failed: %s", exc)
            raise HTTPException(502, "المساعد الذكي غير متاح الآن، اكتب وصفك يدويًا")
    return {
        "category_id": cat_id,
        "category_name": CAT_BY_ID[cat_id]["name"],
        "refined_description": f"فحص وإصلاح: {body.text.strip()}",
        "urgency": "normal",
        "questions": ["هل المشكلة مستمرة منذ أكثر من يوم؟", "هل تحتاج قطع غيار جديدة؟"],
        "tips": "افصل مصدر المياه أو الكهرباء الفرعي عند الضرورة لحين وصول الفني.",
        "price_min": 150,
        "price_max": 400,
    }


# ---------------------------------------------------------------- requests
async def get_request_for(rid: str, user: dict) -> dict:
    r = await db.requests.find_one({"id": rid}, NO_ID)
    if not r:
        raise HTTPException(404, "الطلب غير موجود")
    if user["role"] == "admin":
        return r
    if user["role"] == "customer" and r["customer_id"] == user["id"]:
        return r
    if user["role"] == "technician":
        if r.get("technician_id") == user["id"]:
            return r
        if r["status"] == "open":
            t = await db.technicians.find_one({"user_id": user["id"]}, NO_ID)
            if t and r["category_id"] in t.get("categories", []):
                return {**r, "customer_phone": None, "address": None, "lat": None, "lng": None}
    if user["role"] == "company" and r.get("company_id") == user["id"]:
        return r
    raise HTTPException(403, "غير مسموح")


async def demo_offers(req: dict):
    techs = await db.technicians.find({"is_demo": True, "categories": req["category_id"],
                                       "identity_status": "approved"}, NO_ID).to_list(5)
    svc = SERVICES.get(req.get("service_id") or "")
    lo, hi = (svc["price_min"], svc["price_max"]) if svc else (150, 500)
    for t in techs[:3]:
        price = int(round(random.randint(lo, hi) / 10.0) * 10)
        await db.offers.insert_one({
            "id": new_id(), "request_id": req["id"], "technician_id": t["user_id"],
            "technician_name": t["name"], "rating": t["rating"], "reviews_count": t["reviews_count"],
            "jobs_done": t["jobs_done"], "company_id": t.get("company_id"), "price": price,
            "eta_minutes": random.choice([30, 45, 60, 90]), "note": "معايا كل العدة، وضمان على الشغل",
            "status": "pending", "created_at": now_iso()})
    if techs:
        await notify(req["customer_id"], "وصلتك عروض جديدة", f"{len(techs[:3])} عروض على طلب {req['category_name']}", req["id"])


@api.post("/requests")
async def create_request(body: RequestIn, user: dict = Depends(require("customer"))):
    cat = CAT_BY_ID.get(body.category_id)
    if not cat:
        raise HTTPException(422, "القسم غير موجود")
    if body.area not in AREAS:
        raise HTTPException(422, "المنطقة خارج نطاق الخدمة حاليًا")
    try:
        when = datetime.fromisoformat(body.scheduled_at.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(422, "موعد غير صحيح")
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    if when < datetime.now(timezone.utc) - timedelta(minutes=5):
        raise HTTPException(422, "الموعد لازم يكون في المستقبل")
    svc = SERVICES.get(body.service_id or "")
    req = {
        "id": new_id(), "customer_id": user["id"], "customer_name": user["name"], "customer_phone": user["phone"],
        "category_id": cat["id"], "category_name": cat["name"],
        "service_id": svc["id"] if svc else None, "service_name": svc["name"] if svc else "مشكلة مخصصة",
        "price_min": svc["price_min"] if svc else None, "price_max": svc["price_max"] if svc else None,
        "description": body.description, "urgency": body.urgency, "area": body.area, "address": body.address,
        "lat": body.lat, "lng": body.lng, "photos": body.photos[:6], "scheduled_at": body.scheduled_at, "payment_method": body.payment_method,
        "status": "open", "technician_id": None, "technician_name": None, "technician_phone": None,
        "company_id": None, "price": None, "offer_id": None, "review": None,
        "timeline": [{"status": "open", "at": now_iso()}], "created_at": now_iso(),
    }
    await db.requests.insert_one(dict(req))
    techs = await db.technicians.find({"categories": cat["id"], "identity_status": "approved", "is_demo": False},
                                      {"_id": 0, "user_id": 1}).to_list(200)
    for t in techs:
        await notify(t["user_id"], "طلب جديد في منطقتك", f"{cat['name']} - {body.area}", req["id"])
    if DEMO_AUTO_OFFERS:
        await demo_offers(req)
    return req


@api.get("/requests")
async def my_requests(user: dict = Depends(current_user)):
    q = {"customer_id": user["id"]} if user["role"] == "customer" else (
        {"technician_id": user["id"]} if user["role"] == "technician" else {"company_id": user["id"]})
    items = await db.requests.find(q, NO_ID).sort("created_at", -1).to_list(200)
    for r in items:
        r["offers_count"] = await db.offers.count_documents({"request_id": r["id"], "status": "pending"})
    return items


@api.get("/requests/{rid}")
async def request_detail(rid: str, user: dict = Depends(current_user)):
    r = await get_request_for(rid, user)
    if user["role"] == "technician":
        mine = await db.offers.find_one({"request_id": rid, "technician_id": user["id"]}, NO_ID)
        r["my_offer"] = mine
    payment = await db.payments.find_one({"request_id": rid}, NO_ID)
    r["payment"] = payment
    return r


@api.get("/requests/{rid}/offers")
async def request_offers(rid: str, sort: Literal["price", "rating", "eta"] = "price",
                         user: dict = Depends(current_user)):
    r = await get_request_for(rid, user)
    if user["role"] not in ("customer", "admin"):
        raise HTTPException(403, "غير مسموح")
    key = {"price": ("price", 1), "rating": ("rating", -1), "eta": ("eta_minutes", 1)}[sort]
    offers = await db.offers.find({"request_id": r["id"]}, NO_ID).sort(*key).to_list(50)
    return offers


@api.post("/requests/{rid}/offers")
async def send_offer(rid: str, body: OfferIn, user: dict = Depends(require("technician"))):
    r = await get_request_for(rid, user)
    if r["status"] != "open":
        raise HTTPException(400, "الطلب لم يعد متاحًا")
    t = await tech_profile(user["id"])
    if t["identity_status"] != "approved":
        raise HTTPException(403, "لازم يتم توثيق هويتك أولاً من الإدارة")
    if not sub_active(t):
        raise HTTPException(403, "اشتراكك غير مفعل، اشترك لتقديم العروض")
    if await db.offers.find_one({"request_id": rid, "technician_id": user["id"]}):
        raise HTTPException(400, "قدمت عرض على هذا الطلب بالفعل")
    offer = {"id": new_id(), "request_id": rid, "technician_id": user["id"], "technician_name": t["name"],
             "rating": t["rating"], "reviews_count": t["reviews_count"], "jobs_done": t["jobs_done"],
             "company_id": t.get("company_id"), "price": body.price, "eta_minutes": body.eta_minutes,
             "note": body.note, "status": "pending", "created_at": now_iso()}
    await db.offers.insert_one(dict(offer))
    await notify(r["customer_id"], "عرض جديد", f"{t['name']} قدم عرض بـ {body.price} ج.م", rid)
    return offer


@api.post("/offers/{oid}/accept")
async def accept_offer(oid: str, user: dict = Depends(require("customer"))):
    offer = await db.offers.find_one({"id": oid}, NO_ID)
    if not offer:
        raise HTTPException(404, "العرض غير موجود")
    r = await get_request_for(offer["request_id"], user)
    if r["status"] != "open":
        raise HTTPException(400, "تم اختيار عرض بالفعل")
    tech_user = await db.users.find_one({"id": offer["technician_id"]}, NO_ID)
    updated = await db.requests.find_one_and_update(
        {"id": r["id"], "status": "open"},
        {"$set": {"status": "booked", "technician_id": offer["technician_id"],
                  "technician_name": offer["technician_name"],
                  "technician_phone": tech_user["phone"] if tech_user else None,
                  "company_id": offer.get("company_id"), "price": offer["price"], "offer_id": oid},
         "$push": {"timeline": {"status": "booked", "at": now_iso()}}},
        projection=NO_ID, return_document=ReturnDocument.AFTER)
    if not updated:
        raise HTTPException(400, "تم اختيار عرض بالفعل")
    await db.offers.update_one({"id": oid}, {"$set": {"status": "accepted"}})
    await db.offers.update_many({"request_id": r["id"], "id": {"$ne": oid}}, {"$set": {"status": "rejected"}})
    await notify(offer["technician_id"], "تم قبول عرضك", f"حجز جديد: {r['category_name']} - {r['area']}", r["id"])
    return updated


@api.post("/requests/{rid}/status")
async def update_status(rid: str, body: StatusIn, user: dict = Depends(require("technician"))):
    r = await db.requests.find_one({"id": rid}, NO_ID)
    if not r or r.get("technician_id") != user["id"]:
        raise HTTPException(403, "غير مسموح")
    if r["status"] not in STATUS_FLOW or STATUS_FLOW.index(body.status) != STATUS_FLOW.index(r["status"]) + 1:
        raise HTTPException(400, "ترتيب الحالة غير صحيح")
    await db.requests.update_one({"id": rid}, {"$set": {"status": body.status},
                                               "$push": {"timeline": {"status": body.status, "at": now_iso()}}})
    if body.status == "completed":
        cash = r["payment_method"] == "cash"
        await db.payments.insert_one({
            "id": new_id(), "request_id": rid, "customer_id": r["customer_id"], "technician_id": user["id"],
            "amount": r["price"], "currency": "EGP", "method": r["payment_method"],
            "status": "collected" if cash else "awaiting_gateway", "created_at": now_iso()})
        await db.technicians.update_one({"user_id": user["id"]},
                                        {"$inc": {"jobs_done": 1, "earnings": r["price"] or 0}})
    await notify(r["customer_id"], STATUS_AR[body.status], f"طلب {r['category_name']}", rid)
    return await db.requests.find_one({"id": rid}, NO_ID)


@api.post("/requests/{rid}/cancel")
async def cancel_request(rid: str, user: dict = Depends(require("customer"))):
    r = await get_request_for(rid, user)
    if r["status"] not in ("open", "booked"):
        raise HTTPException(400, "لا يمكن إلغاء الطلب الآن")
    await db.requests.update_one({"id": rid}, {"$set": {"status": "cancelled"},
                                               "$push": {"timeline": {"status": "cancelled", "at": now_iso()}}})
    if r.get("technician_id"):
        await notify(r["technician_id"], "تم إلغاء الحجز", f"{r['category_name']} - {r['area']}", rid)
    return {"ok": True}


@api.post("/requests/{rid}/review")
async def review_request(rid: str, body: ReviewIn, user: dict = Depends(require("customer"))):
    r = await get_request_for(rid, user)
    if r["status"] != "completed":
        raise HTTPException(400, "التقييم متاح بعد إنجاز الطلب")
    if r.get("review"):
        raise HTTPException(400, "قيّمت هذا الطلب بالفعل")
    review = {"rating": body.rating, "comment": body.comment, "at": now_iso()}
    await db.requests.update_one({"id": rid}, {"$set": {"review": review}})
    t = await tech_profile(r["technician_id"])
    count = t["reviews_count"] + 1
    rating = round((t["rating"] * t["reviews_count"] + body.rating) / count, 2)
    await db.technicians.update_one({"user_id": t["user_id"]}, {"$set": {"rating": rating, "reviews_count": count}})
    await notify(t["user_id"], "تقييم جديد", f"{body.rating} نجوم من {r['customer_name']}", rid)
    return review


# ---------------------------------------------------------------- chat
async def chat_request(rid: str, user: dict) -> dict:
    r = await db.requests.find_one({"id": rid}, NO_ID)
    if not r or not r.get("technician_id") or user["id"] not in (r["customer_id"], r["technician_id"]):
        raise HTTPException(403, "المحادثة متاحة بعد الحجز فقط")
    return r


@api.get("/chats")
async def chats(user: dict = Depends(current_user)):
    field = "customer_id" if user["role"] == "customer" else "technician_id"
    rs = await db.requests.find({field: user["id"], "technician_id": {"$ne": None}}, NO_ID).sort(
        "created_at", -1).to_list(100)
    out = []
    for r in rs:
        last = await db.messages.find_one({"request_id": r["id"]}, NO_ID, sort=[("created_at", -1)])
        out.append({"request_id": r["id"], "category_name": r["category_name"], "status": r["status"],
                    "other_name": r["technician_name"] if user["role"] == "customer" else r["customer_name"],
                    "last_message": last["text"] if last else None,
                    "last_at": last["created_at"] if last else r["created_at"]})
    return sorted(out, key=lambda x: x["last_at"], reverse=True)


@api.get("/requests/{rid}/messages")
async def get_messages(rid: str, user: dict = Depends(current_user)):
    await chat_request(rid, user)
    return await db.messages.find({"request_id": rid}, NO_ID).sort("created_at", 1).to_list(500)


@api.post("/requests/{rid}/messages")
async def post_message(rid: str, body: MessageIn, user: dict = Depends(current_user)):
    r = await chat_request(rid, user)
    text = body.text.strip()
    if not text:
        raise HTTPException(422, "الرسالة فارغة")
    if body.client_id:
        dup = await db.messages.find_one({"client_id": body.client_id, "request_id": rid, "sender_id": user["id"]}, NO_ID)
        if dup:
            return dup
    msg = {"id": new_id(), "request_id": rid, "sender_id": user["id"], "sender_name": user["name"],
           "text": text, "client_id": body.client_id, "created_at": now_iso()}
    await db.messages.insert_one(dict(msg))
    other = r["technician_id"] if user["id"] == r["customer_id"] else r["customer_id"]
    await notify(other, f"رسالة من {user['name']}", body.text[:80], rid)
    return msg


# ---------------------------------------------------------------- notifications
@api.get("/notifications")
async def notifications(user: dict = Depends(current_user)):
    items = await db.notifications.find({"user_id": user["id"]}, NO_ID).sort("created_at", -1).to_list(100)
    unread = await db.notifications.count_documents({"user_id": user["id"], "read": False})
    return {"items": items, "unread": unread}


@api.post("/notifications/read")
async def read_notifications(user: dict = Depends(current_user)):
    await db.notifications.update_many({"user_id": user["id"], "read": False}, {"$set": {"read": True}})
    return {"ok": True}


# ---------------------------------------------------------------- technician
@api.get("/tech/dashboard")
async def tech_dashboard(user: dict = Depends(require("technician"))):
    t = await tech_profile(user["id"])
    open_q = {"status": "open", "category_id": {"$in": t["categories"]}}
    open_reqs = await db.requests.find(open_q, {"_id": 0, "customer_phone": 0, "address": 0, "lat": 0, "lng": 0}
                                       ).sort("created_at", -1).to_list(50)
    offered = {o["request_id"] for o in await db.offers.find(
        {"technician_id": user["id"]}, {"_id": 0, "request_id": 1}).to_list(1000)}
    for r in open_reqs:
        r["already_offered"] = r["id"] in offered
    active = await db.requests.find({"technician_id": user["id"], "status": {"$in": STATUS_FLOW[:-1]}},
                                    NO_ID).sort("scheduled_at", 1).to_list(50)
    return {"profile": t, "subscription_active": sub_active(t), "open_requests": open_reqs, "active_jobs": active}


@api.put("/tech/profile")
async def update_tech_profile(body: TechProfileIn, user: dict = Depends(require("technician"))):
    cats = [c for c in body.categories if c in CAT_BY_ID]
    await db.technicians.update_one({"user_id": user["id"]},
                                    {"$set": {"categories": cats, "bio": body.bio, "online": body.online}})
    return await tech_profile(user["id"])


@api.post("/tech/identity")
async def submit_identity(body: IdentityIn, user: dict = Depends(require("technician"))):
    t = await tech_profile(user["id"])
    if t["identity_status"] == "approved":
        raise HTTPException(400, "هويتك موثقة بالفعل")
    await db.technicians.update_one({"user_id": user["id"]}, {"$set": {
        "identity_status": "pending", "national_id": body.national_id, "identity_name": body.full_name,
        "id_front_url": body.id_front_url, "id_back_url": body.id_back_url,
        "identity_submitted_at": now_iso(), "review_note": ""}})
    return await tech_profile(user["id"])


@api.get("/plans")
async def plans():
    return list(PLANS.values())


@api.post("/tech/subscribe")
async def subscribe(body: SubscribeIn, user: dict = Depends(require("technician"))):
    t = await tech_profile(user["id"])
    if await db.invoices.find_one({"technician_id": user["id"], "status": "unpaid"}):
        raise HTTPException(400, "عندك فاتورة غير مدفوعة بالفعل")
    plan = PLANS[body.plan]
    counter = await db.counters.find_one_and_update({"_id": "invoice"}, {"$inc": {"seq": 1}}, upsert=True,
                                                    return_document=ReturnDocument.AFTER)
    count = counter["seq"] - 1
    inv = {"id": new_id(), "number": f"KH-{datetime.now(timezone.utc).year}-{count + 1:05d}",
           "technician_id": user["id"], "technician_name": t["name"], "company_id": t.get("company_id"),
           "plan": plan["id"], "plan_name": plan["name"], "amount": plan["price"], "currency": "EGP",
           "status": "unpaid", "method": None, "created_at": now_iso(), "paid_at": None}
    await db.invoices.insert_one(dict(inv))
    return inv


@api.get("/tech/invoices")
async def tech_invoices(user: dict = Depends(require("technician"))):
    return await db.invoices.find({"technician_id": user["id"]}, NO_ID).sort("created_at", -1).to_list(100)


# payments routes handled by payments_router.py


# ---------------------------------------------------------------- company
@api.get("/company/overview")
async def company_overview(user: dict = Depends(require("company"))):
    techs = await db.technicians.find({"company_id": user["id"]}, {"_id": 0, "national_id": 0}).to_list(200)
    jobs = await db.requests.find({"company_id": user["id"]}, NO_ID).sort("created_at", -1).to_list(100)
    revenue = sum(j["price"] or 0 for j in jobs if j["status"] == "completed")
    invoices = await db.invoices.find({"company_id": user["id"]}, NO_ID).sort("created_at", -1).to_list(100)
    return {"technicians": techs, "jobs": jobs, "revenue": revenue, "invoices": invoices}


@api.post("/company/technicians")
async def company_add_tech(body: CompanyTechIn, user: dict = Depends(require("company"))):
    phone = normalize_eg_phone(body.phone)
    if await db.users.find_one({"phone": phone}):
        raise HTTPException(400, "الرقم مسجل بالفعل")
    tu = {"id": new_id(), "phone": phone, "role": "technician", "name": body.name, "created_at": now_iso()}
    await db.users.insert_one(dict(tu))
    doc = new_tech_doc(tu, [c for c in body.categories if c in CAT_BY_ID], company_id=user["id"])
    await db.technicians.insert_one(dict(doc))
    doc.pop("_id", None)
    return doc


# ---------------------------------------------------------------- admin
@api.get("/admin/stats")
async def admin_stats(user: dict = Depends(require("admin"))):
    completed = await db.requests.find({"status": "completed"}, {"_id": 0, "price": 1}).to_list(10000)
    paid_inv = await db.invoices.find({"status": "paid"}, {"_id": 0, "amount": 1}).to_list(10000)
    return {
        "customers": await db.users.count_documents({"role": "customer"}),
        "technicians": await db.users.count_documents({"role": "technician"}),
        "pending_reviews": await db.technicians.count_documents({"identity_status": "pending"}),
        "requests": await db.requests.count_documents({}),
        "open_requests": await db.requests.count_documents({"status": "open"}),
        "completed": len(completed),
        "gmv": sum(r.get("price") or 0 for r in completed),
        "subscription_revenue": sum(i["amount"] for i in paid_inv),
        "unpaid_invoices": await db.invoices.count_documents({"status": "unpaid"}),
    }


@api.get("/admin/technicians")
async def admin_techs(status: Optional[str] = None, user: dict = Depends(require("admin"))):
    q = {"identity_status": status} if status else {}
    return await db.technicians.find(q, NO_ID).sort("created_at", -1).to_list(300)


@api.post("/admin/technicians/{uid}/identity")
async def admin_identity(uid: str, body: DecisionIn, user: dict = Depends(require("admin"))):
    t = await tech_profile(uid)
    if t["identity_status"] != "pending":
        raise HTTPException(400, "لا يوجد طلب توثيق معلق")
    status = "approved" if body.decision == "approve" else "rejected"
    await db.technicians.update_one({"user_id": uid}, {"$set": {"identity_status": status, "review_note": body.note,
                                                                "reviewed_at": now_iso()}})
    await notify(uid, "تم توثيق هويتك" if status == "approved" else "تم رفض التوثيق",
                 body.note or ("تقدر دلوقتي تقدم عروض" if status == "approved" else "راجع بياناتك وقدم مرة أخرى"))
    return await tech_profile(uid)


@api.get("/admin/invoices")
async def admin_invoices(user: dict = Depends(require("admin"))):
    return await db.invoices.find({}, NO_ID).sort("created_at", -1).to_list(300)


@api.post("/admin/invoices/{iid}/mark-paid")
async def admin_mark_paid(iid: str, user: dict = Depends(require("admin"))):
    inv = await db.invoices.find_one({"id": iid}, NO_ID)
    if not inv or inv["status"] == "paid":
        raise HTTPException(400, "الفاتورة غير موجودة أو مدفوعة")
    t = await tech_profile(inv["technician_id"])
    base = max(datetime.now(timezone.utc), datetime.fromisoformat(t["subscription_until"])) \
        if t.get("subscription_until") else datetime.now(timezone.utc)
    until = (base + timedelta(days=PLANS[inv["plan"]]["days"])).isoformat()
    await db.invoices.update_one({"id": iid}, {"$set": {"status": "paid", "method": "cash", "paid_at": now_iso()}})
    await db.technicians.update_one({"user_id": inv["technician_id"]},
                                    {"$set": {"subscription_until": until, "subscription_plan": inv["plan"]}})
    await notify(inv["technician_id"], "تم تفعيل اشتراكك", f"اشتراك {inv['plan_name']} ساري حتى {until[:10]}")
    return {**inv, "status": "paid"}


@api.get("/admin/requests")
async def admin_requests(user: dict = Depends(require("admin"))):
    return await db.requests.find({}, NO_ID).sort("created_at", -1).to_list(100)


# ---------------------------------------------------------------- seed
SEED_USERS = [
    ("+201000000001", "admin", "إدارة خدمات"),
    ("+201000000002", "company", "شركة النيل للصيانة"),
    ("+201000000003", "technician", "محمود السيد"),
    ("+201000000004", "customer", "أحمد عبد الله"),
]
DEMO_TECHS = [
    ("+201011111111", "كريم الشافعي", ["plumbing", "appliances", "electricity"], 4.8, 126),
    ("+201011111112", "إبراهيم فتحي", ["electricity", "ac", "plumbing", "carpentry"], 4.6, 88),
    ("+201011111113", "مصطفى عادل", ["cleaning", "painting", "pest", "ac", "carpentry", "appliances"], 4.9, 203),
]


async def seed():
    company_id = None
    far = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
    for phone, role, name in SEED_USERS:
        u = await db.users.find_one({"phone": phone}, NO_ID)
        if not u:
            u = {"id": new_id(), "phone": phone, "role": role, "name": name, "created_at": now_iso()}
            await db.users.insert_one(dict(u))
        if role == "company":
            company_id = u["id"]
        if role == "technician" and not await db.technicians.find_one({"user_id": u["id"]}):
            await db.technicians.insert_one(new_tech_doc(
                u, ["plumbing", "electricity", "ac", "appliances"], identity_status="approved",
                subscription_until=far, subscription_plan="yearly", rating=4.7, reviews_count=34, jobs_done=41))
    for phone, name, cats, rating, jobs in DEMO_TECHS:
        u = await db.users.find_one({"phone": phone}, NO_ID)
        if not u:
            u = {"id": new_id(), "phone": phone, "role": "technician", "name": name, "created_at": now_iso()}
            await db.users.insert_one(dict(u))
        if not await db.technicians.find_one({"user_id": u["id"]}):
            await db.technicians.insert_one(new_tech_doc(
                u, cats, company_id=company_id if phone.endswith("2") else None, identity_status="approved",
                subscription_until=far, subscription_plan="yearly", rating=rating, reviews_count=jobs // 2,
                jobs_done=jobs, is_demo=True))


from uploads_router import build_uploads_router
from payments_router import build_payments_router


class PushTokenIn(BaseModel):
    token: str = Field(min_length=10, max_length=500)
    platform: Literal["android", "ios", "web"] = "android"


@api.post("/devices/push-token")
async def register_push_token(body: PushTokenIn, user: dict = Depends(current_user)):
    await db.device_tokens.update_one(
        {"user_id": user["id"], "token": body.token},
        {
            "$set": {
                "user_id": user["id"],
                "role": user["role"],
                "token": body.token,
                "platform": body.platform,
                "updated_at": now_iso(),
            }
        },
        upsert=True,
    )
    return {"ok": True, "platform": body.platform}


@api.get("/devices/push-token")
async def list_my_push_tokens(user: dict = Depends(current_user)):
    return await db.device_tokens.find({"user_id": user["id"]}, NO_ID).to_list(20)

app.include_router(api)
app.include_router(build_payments_router(db, current_user, notify, PLANS))
app.include_router(build_uploads_router(current_user))
app.add_middleware(CORSMiddleware, allow_credentials=True, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")


@app.on_event("startup")
async def startup():
    app.state.index_task = asyncio.create_task(ensure_indexes())
    await seed()


@app.on_event("shutdown")
async def shutdown():
    app.state.index_task.cancel()
    with suppress(asyncio.CancelledError):
        await app.state.index_task
    client.close()