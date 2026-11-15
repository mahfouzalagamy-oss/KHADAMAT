# KHADAMAT backend regression tests: auth, catalog, AI, requests/offers, status flow, review, chat, tech onboarding, company, admin, payments
import os
import random
import uuid
from pathlib import Path
import pytest
import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "frontend" / ".env")
load_dotenv(ROOT / "backend" / ".env")

BASE = os.environ.get("EXPO_PUBLIC_BACKEND_URL", "http://127.0.0.1:8000").rstrip("/") + "/api"
OTP = "123456"
S = {}  # shared state across ordered tests
CREATED = {"users": [], "requests": [], "invoices": []}


def login(phone, role="customer", name=None):
    r = requests.post(f"{BASE}/auth/request-otp", json={"phone": phone}, timeout=20)
    assert r.status_code == 200, r.text
    r = requests.post(f"{BASE}/auth/verify-otp", json={"phone": phone, "otp": OTP, "role": role, "name": name}, timeout=20)
    assert r.status_code == 200, r.text
    d = r.json()
    return {"Authorization": f"Bearer {d['token']}"}, d["user"]


def rand_phone(prefix="0155"):
    return prefix + "".join(random.choice("0123456789") for _ in range(7))


@pytest.fixture(scope="module", autouse=True)
def cleanup():
    yield
    try:
        from pymongo import MongoClient
        db = MongoClient(os.environ.get("MONGO_URL", "mongodb://localhost:27017"))[os.environ.get("DB_NAME", "khadamat_db")]
        ids = CREATED["users"]
        rids = CREATED["requests"]
        db.users.delete_many({"id": {"$in": ids}})
        db.technicians.delete_many({"user_id": {"$in": ids}})
        db.notifications.delete_many({"user_id": {"$in": ids}})
        db.invoices.delete_many({"id": {"$in": CREATED["invoices"]}})
        db.offers.delete_many({"request_id": {"$in": rids}})
        db.messages.delete_many({"request_id": {"$in": rids}})
        db.payments.delete_many({"request_id": {"$in": rids}})
        db.notifications.delete_many({"request_id": {"$in": rids}})
        db.requests.delete_many({"id": {"$in": rids}})
        if S.get("restore_rating") and S.get("tech"):
            rt, rc, jd, earn = S["restore_rating"]
            db.technicians.update_one({"user_id": S["tech"]["id"]}, {"$set": {
                "rating": rt, "reviews_count": rc, "jobs_done": jd - 1, "earnings": (earn or 0) - 200}})
    except Exception as e:  # noqa
        print("cleanup failed", e)


class TestAuth:
    def test_invalid_phone(self):
        r = requests.post(f"{BASE}/auth/request-otp", json={"phone": "12345"})
        assert r.status_code == 422

    def test_wrong_otp(self):
        p = rand_phone()
        requests.post(f"{BASE}/auth/request-otp", json={"phone": p})
        r = requests.post(f"{BASE}/auth/verify-otp", json={"phone": p, "otp": "000000"})
        assert r.status_code == 400

    def test_new_customer_and_me(self):
        p = rand_phone()
        h, u = login(p, "customer", "TEST_عميل")
        CREATED["users"].append(u["id"])
        assert u["role"] == "customer" and u["phone"].startswith("+20")
        S["cust_h"], S["cust"] = h, u
        r = requests.put(f"{BASE}/me", json={"name": "TEST_عميل جديد"}, headers=h)
        assert r.status_code == 200
        me = requests.get(f"{BASE}/me", headers=h).json()
        assert me["name"] == "TEST_عميل جديد"

    def test_me_unauth(self):
        assert requests.get(f"{BASE}/me").status_code == 401


class TestCatalog:
    def test_catalog(self):
        r = requests.get(f"{BASE}/catalog")
        assert r.status_code == 200
        d = r.json()
        S["catalog"] = d
        cats = d["categories"] if isinstance(d, dict) else d
        assert any(c["id"] == "plumbing" for c in cats)

    def test_category_detail(self):
        r = requests.get(f"{BASE}/catalog/plumbing")
        assert r.status_code == 200
        d = r.json()
        S["plumb"] = d
        assert requests.get(f"{BASE}/catalog/nope").status_code == 404


class TestAI:
    def test_ai_describe(self):
        r = requests.post(f"{BASE}/ai/describe", json={"text": "الحنفية في المطبخ بتنقط مية طول الوقت", "category_id": "plumbing"},
                          headers=S["cust_h"], timeout=90)
        assert r.status_code == 200, r.text
        d = r.json()
        for k in ("category_id", "refined_description", "urgency"):
            assert k in d
        assert any("price" in k for k in d.keys())


class TestBookingFlow:
    def test_create_request_and_demo_offers(self):
        cat = S["plumb"]
        services = cat.get("services") or cat.get("category", {}).get("services") or []
        sid = services[0]["id"] if services else None
        body = {"category_id": "plumbing", "service_id": sid, "description": "TEST_تسريب مياه في الحمام",
                "urgency": "normal", "area": "توريل", "address": "TEST_شارع 1", "scheduled_at": "2027-02-01T10:00:00",
                "payment_method": "cash"}
        r = requests.post(f"{BASE}/requests", json=body, headers=S["cust_h"])
        assert r.status_code == 200, r.text
        req = r.json()
        CREATED["requests"].append(req["id"])
        S["rid"] = req["id"]
        assert req["status"] == "open"
        offers = requests.get(f"{BASE}/requests/{req['id']}/offers?sort=price", headers=S["cust_h"]).json()
        assert len(offers) >= 1
        prices = [o["price"] for o in offers]
        assert prices == sorted(prices)
        rat = [o["rating"] for o in requests.get(f"{BASE}/requests/{req['id']}/offers?sort=rating", headers=S["cust_h"]).json()]
        assert rat == sorted(rat, reverse=True)
        eta = [o["eta_minutes"] for o in requests.get(f"{BASE}/requests/{req['id']}/offers?sort=eta", headers=S["cust_h"]).json()]
        assert eta == sorted(eta)

    def test_bad_area(self):
        body = {"category_id": "plumbing", "description": "abcd", "area": "القاهرة", "address": "abcd", "scheduled_at": "2027-02-01"}
        assert requests.post(f"{BASE}/requests", json=body, headers=S["cust_h"]).status_code == 422

    def test_seed_tech_sees_and_offers(self):
        h, u = login("01000000003", "technician")
        S["tech_h"], S["tech"] = h, u
        d = requests.get(f"{BASE}/tech/dashboard", headers=h).json()
        assert any(r["id"] == S["rid"] for r in d["open_requests"])
        det = requests.get(f"{BASE}/requests/{S['rid']}", headers=h).json()
        assert det.get("address") is None and det.get("customer_phone") is None
        r = requests.post(f"{BASE}/requests/{S['rid']}/offers", json={"price": 200, "eta_minutes": 30, "note": "TEST"}, headers=h)
        assert r.status_code == 200, r.text
        S["tech_offer"] = r.json()["id"]
        r2 = requests.post(f"{BASE}/requests/{S['rid']}/offers", json={"price": 200, "eta_minutes": 30}, headers=h)
        assert r2.status_code == 400

    def test_unapproved_tech_blocked(self):
        h, u = login(rand_phone("0122"), "technician", "TEST_فني")
        CREATED["users"].append(u["id"])
        S["newtech_h"], S["newtech"] = h, u
        requests.put(f"{BASE}/tech/profile", json={"categories": ["plumbing"]}, headers=h)
        r = requests.post(f"{BASE}/requests/{S['rid']}/offers", json={"price": 200, "eta_minutes": 30}, headers=h)
        assert r.status_code == 403, r.text

    def test_status_before_booking_forbidden(self):
        r = requests.post(f"{BASE}/requests/{S['rid']}/status", json={"status": "on_the_way"}, headers=S["tech_h"])
        assert r.status_code == 403

    def test_chat_before_booking_forbidden(self):
        assert requests.get(f"{BASE}/requests/{S['rid']}/messages", headers=S["cust_h"]).status_code == 403

    def test_accept_offer(self):
        r = requests.post(f"{BASE}/offers/{S['tech_offer']}/accept", headers=S["cust_h"])
        assert r.status_code == 200, r.text
        assert r.json()["status"] == "booked" and r.json()["technician_id"] == S["tech"]["id"]
        assert requests.post(f"{BASE}/offers/{S['tech_offer']}/accept", headers=S["cust_h"]).status_code == 400
        det = requests.get(f"{BASE}/requests/{S['rid']}", headers=S["tech_h"]).json()
        assert det["address"] == "TEST_شارع 1"

    def test_chat(self):
        cid = str(uuid.uuid4())
        r = requests.post(f"{BASE}/requests/{S['rid']}/messages", json={"text": "TEST_مرحبا", "client_id": cid}, headers=S["cust_h"])
        assert r.status_code == 200
        r2 = requests.post(f"{BASE}/requests/{S['rid']}/messages", json={"text": "TEST_مرحبا", "client_id": cid}, headers=S["cust_h"])
        assert r2.json()["id"] == r.json()["id"]
        requests.post(f"{BASE}/requests/{S['rid']}/messages", json={"text": "TEST_أهلا"}, headers=S["tech_h"])
        msgs = requests.get(f"{BASE}/requests/{S['rid']}/messages", headers=S["tech_h"]).json()
        assert len(msgs) == 2
        assert requests.get(f"{BASE}/requests/{S['rid']}/messages", headers=S["newtech_h"]).status_code == 403
        chats = requests.get(f"{BASE}/chats", headers=S["cust_h"]).json()
        assert any(c["request_id"] == S["rid"] and c["last_message"] == "TEST_أهلا" for c in chats)

    def test_review_before_completion(self):
        assert requests.post(f"{BASE}/requests/{S['rid']}/review", json={"rating": 5}, headers=S["cust_h"]).status_code == 400

    def test_status_progression(self):
        h = S["tech_h"]
        assert requests.post(f"{BASE}/requests/{S['rid']}/status", json={"status": "arrived"}, headers=h).status_code == 400
        for st in ["on_the_way", "arrived", "in_progress", "completed"]:
            r = requests.post(f"{BASE}/requests/{S['rid']}/status", json={"status": st}, headers=h)
            assert r.status_code == 200, r.text
            assert r.json()["status"] == st
        assert requests.post(f"{BASE}/requests/{S['rid']}/status", json={"status": "completed"}, headers=h).status_code == 400
        det = requests.get(f"{BASE}/requests/{S['rid']}", headers=S["cust_h"]).json()
        assert det["payment"]["method"] == "cash" and det["payment"]["status"] == "collected" and det["payment"]["amount"] == 200

    def test_review_once(self):
        before = requests.get(f"{BASE}/tech/dashboard", headers=S["tech_h"]).json()["profile"]
        r = requests.post(f"{BASE}/requests/{S['rid']}/review", json={"rating": 5, "comment": "TEST"}, headers=S["cust_h"])
        assert r.status_code == 200
        after = requests.get(f"{BASE}/tech/dashboard", headers=S["tech_h"]).json()["profile"]
        assert after["reviews_count"] == before["reviews_count"] + 1
        assert requests.post(f"{BASE}/requests/{S['rid']}/review", json={"rating": 4}, headers=S["cust_h"]).status_code == 400
        S["restore_rating"] = (before["rating"], before["reviews_count"], before["jobs_done"], before.get("earnings"))

    def test_notifications(self):
        h = S["cust_h"]
        n = requests.get(f"{BASE}/notifications", headers=h)
        assert n.status_code == 200
        d = n.json()
        items = d["items"] if isinstance(d, dict) else d
        assert len(items) > 0
        assert requests.post(f"{BASE}/notifications/read", headers=h).status_code == 200
        d2 = requests.get(f"{BASE}/notifications", headers=h).json()
        items2 = d2["items"] if isinstance(d2, dict) else d2
        assert all(i.get("read") for i in items2)


class TestOnboarding:
    def test_identity_and_subscription(self):
        h = S["newtech_h"]
        assert requests.post(f"{BASE}/tech/identity", json={"full_name": "TEST_فني جديد", "national_id": "12345678901234"}, headers=h).status_code == 422
        r = requests.post(f"{BASE}/tech/identity", json={"full_name": "TEST_فني جديد", "national_id": "29001011234567"}, headers=h)
        assert r.status_code == 200 and r.json()["identity_status"] == "pending"
        ah, _ = login("01000000001")
        S["admin_h"] = ah
        r = requests.post(f"{BASE}/admin/technicians/{S['newtech']['id']}/identity", json={"decision": "approve"}, headers=ah)
        assert r.status_code == 200 and r.json()["identity_status"] == "approved"
        r = requests.post(f"{BASE}/tech/subscribe", json={"plan": "monthly"}, headers=h)
        assert r.status_code == 200
        inv = r.json()
        CREATED["invoices"].append(inv["id"])
        assert inv["status"] == "unpaid" and inv["currency"] == "EGP"
        assert requests.post(f"{BASE}/tech/subscribe", json={"plan": "monthly"}, headers=h).status_code == 400
        r = requests.post(f"{BASE}/admin/invoices/{inv['id']}/mark-paid", headers=ah)
        assert r.status_code == 200
        d = requests.get(f"{BASE}/tech/dashboard", headers=h).json()
        assert d["subscription_active"] is True

    def test_admin_protection_and_stats(self):
        assert requests.get(f"{BASE}/admin/stats", headers=S["cust_h"]).status_code == 403
        r = requests.get(f"{BASE}/admin/stats", headers=S["admin_h"])
        assert r.status_code == 200 and "gmv" in r.json()

    def test_company(self):
        h, _ = login("01000000002")
        r = requests.get(f"{BASE}/company/overview", headers=h)
        assert r.status_code == 200 and "technicians" in r.json()
        r = requests.post(f"{BASE}/company/technicians", json={"phone": rand_phone("0111"), "name": "TEST_فني شركة", "categories": ["ac"]}, headers=h)
        assert r.status_code == 200, r.text
        CREATED["users"].append(r.json()["user_id"])
        ov = requests.get(f"{BASE}/company/overview", headers=h).json()
        assert any(t["user_id"] == r.json()["user_id"] for t in ov["technicians"])


class TestPayments:
    def test_config_and_checkout(self):
        assert requests.get(f"{BASE}/payments/config").json()["online_enabled"] is False
        r = requests.post(f"{BASE}/payments/checkout", json={"kind": "booking", "ref_id": "x"}, headers=S["cust_h"])
        assert r.status_code == 503

class TestUploads:
    def test_upload_image_and_fetch(self):
        png_1x1 = (
            b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
            b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
            b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
        )
        r = requests.post(
            f"{BASE}/uploads",
            files={"file": ("id_front.png", png_1x1, "image/png")},
            headers=S["cust_h"],
            timeout=20,
        )
        assert r.status_code == 200, r.text
        data = r.json()
        assert data["url"].startswith("/api/uploads/")
        fetch_r = requests.get(BASE.replace("/api", "") + data["url"], timeout=20)
        assert fetch_r.status_code == 200

    def test_reject_invalid_extension(self):
        r = requests.post(
            f"{BASE}/uploads",
            files={"file": ("script.exe", b"MZ", "application/octet-stream")},
            headers=S["cust_h"],
            timeout=20,
        )
        assert r.status_code == 422