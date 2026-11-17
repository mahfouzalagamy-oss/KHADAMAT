import os
import sys
from pathlib import Path
from urllib.parse import urlsplit

import pytest
import requests

# إعداد متغيرات البيئة القياسية للاختبارات
os.environ["APP_ENV"] = "development"
os.environ["ALLOW_DEMO_OTP"] = "true"
os.environ["DEMO_OTP"] = "123456"
os.environ["DEMO_AUTO_OFFERS"] = "true"
os.environ["SEED_DEFAULT_ADMIN"] = "true"
os.environ["JWT_SECRET"] = "khadamat-test-suite-secret-key-2026-secure"
os.environ.pop("PAYMENT_GATEWAY_API_KEY", None)

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# استبدال MongoDB و PyMongo بمحاكي الذاكرة الفوري عند عدم وجود خادم MongoDB على المنفذ 27017
import socket
_mongo_up = False
try:
    with socket.create_connection(("127.0.0.1", 27017), timeout=0.3):
        _mongo_up = True
except OSError:
    _mongo_up = False

if not _mongo_up:
    import mongomock
    import pymongo
    import motor.motor_asyncio
    from mongomock_motor import AsyncMongoMockClient

    pymongo.MongoClient = mongomock.MongoClient
    motor.motor_asyncio.AsyncIOMotorClient = AsyncMongoMockClient

from fastapi.testclient import TestClient
import server

@pytest.fixture(scope="session", autouse=True)
def _route_requests_to_local_fastapi():
    with TestClient(server.app) as client:
        orig_request = requests.Session.request

        def _local_request(self, method, url, **kwargs):
            parsed = urlsplit(url)
            path = parsed.path or "/"
            if parsed.query:
                path = f"{path}?{parsed.query}"
            kwargs.pop("timeout", None)
            return client.request(method, path, **kwargs)

        requests.Session.request = _local_request
        try:
            yield
        finally:
            requests.Session.request = orig_request