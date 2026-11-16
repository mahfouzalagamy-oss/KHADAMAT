import os
import socket
import threading
import time
import webbrowser
from pathlib import Path

os.environ.setdefault("DEMO_OTP", "123456")
os.environ.setdefault("DEMO_AUTO_OFFERS", "true")
os.environ.setdefault("JWT_SECRET", "khadamat-local-browser-secret-2026")
os.environ["PAYMENT_GATEWAY_API_KEY"] = "sandbox-paymob-2026"
os.environ["PAYMENT_GATEWAY_PROVIDER"] = "paymob"

mongo_running = False
try:
    with socket.create_connection(("127.0.0.1", 27017), timeout=0.4):
        mongo_running = True
except OSError:
    mongo_running = False

if not mongo_running:
    import motor.motor_asyncio
    from mongomock_motor import AsyncMongoMockClient
    motor.motor_asyncio.AsyncIOMotorClient = AsyncMongoMockClient
    print("⚡ تم تفعيل قاعدة البيانات المدمجة الفورية + بوابة الدفع التجريبية (Paymob/Fawry Sandbox)")

import uvicorn
from fastapi import HTTPException, Response
from fastapi.responses import FileResponse, HTMLResponse
import server

WEB_DIST = Path(__file__).resolve().parent.parent / "frontend" / "dist"

for route in server.app.router.routes:
    if getattr(route, "path", "") == "/api/payments/checkout":
        orig_endpoint = route.endpoint
        async def wrapped_checkout(*args, **kwargs):
            res = await orig_endpoint(*args, **kwargs)
            if isinstance(res, dict) and "merchant_order_id" in res:
                res["checkout_url"] = f"http://127.0.0.1:8000/sandbox/checkout/{res['merchant_order_id']}"
            return res
        route.endpoint = wrapped_checkout

@server.app.get("/sandbox/checkout/{merchant_order_id}", response_class=HTMLResponse, include_in_schema=False)
async def sandbox_checkout_page(merchant_order_id: str):
    intent = await server.db.payment_intents.find_one({"merchant_order_id": merchant_order_id}, {"_id": 0})
    if not intent:
        raise HTTPException(404, "عملية الدفع غير موجودة")
    html = f"""<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8"/>
<title>بوابة الدفع التجريبية | KHADAMAT Sandbox</title>
<style>
  body {{ font-family: system-ui, sans-serif; background: #f4f6f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }}
  .card {{ background: #fff; border-radius: 20px; padding: 28px; width: 400px; box-shadow: 0 12px 32px rgba(0,0,0,0.08); border: 2px solid #059669; }}
  .badge {{ background: #d1fae5; color: #065f46; padding: 4px 12px; border-radius: 99px; font-size: 13px; font-weight: 700; display: inline-block; }}
  .amount {{ font-size: 32px; font-weight: 800; color: #059669; margin: 14px 0; }}
  .row {{ display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; font-size: 14px; }}
  button {{ width: 100%; padding: 14px; border: none; border-radius: 12px; font-size: 16px; font-weight: 700; cursor: pointer; margin-top: 12px; }}
  .btn-pay {{ background: #059669; color: #fff; }}
  .btn-fail {{ background: #fee2e2; color: #991b1b; }}
  #msg {{ margin-top: 14px; font-weight: 700; text-align: center; }}
</style>
</head>
<body>
  <div class="card">
    <span class="badge">بيئة اختبار آمنة • {intent['provider'].upper()} SANDBOX</span>
    <h2 style="margin: 12px 0 4px;">بوابة الدفع الإلكتروني - خدمات</h2>
    <div class="amount">{intent['amount']} ج.م</div>
    <div class="row"><span>رقم الطلب المرجعي:</span><b>{intent['merchant_order_id']}</b></div>
    <div class="row"><span>نوع المعاملة:</span><b>{"اشتراك فني" if intent["kind"] == "invoice" else "حجز صيانة"}</b></div>
    <div class="row"><span>بطاقة الاختبار:</span><b dir="ltr">4242 •••• •••• 4242</b></div>
    <button class="btn-pay" onclick="sendWebhook('PAID')">✓ تأكيد الدفع التجريبي (HMAC Webhook)</button>
    <button class="btn-fail" onclick="sendWebhook('FAILED')">✕ محاكاة فشل العملية</button>
    <div id="msg"></div>
  </div>
<script>
async function sendWebhook(status) {{
  const msg = document.getElementById('msg');
  msg.style.color = '#059669';
  msg.innerText = 'جاري إرسال إشعار Webhook الموقّع بـ HMAC-SHA512...';
  const res = await fetch('/api/payments/webhook', {{
    method: 'POST',
    headers: {{ 'Content-Type': 'application/json' }},
    body: JSON.stringify({{
      merchant_order_id: '{intent["merchant_order_id"]}',
      status: status,
      transaction_id: 'SANDBOX-TXN-' + Date.now(),
      hmac: '{intent["hmac"]}'
    }})
  }});
  if (res.ok) {{
    msg.innerText = status === 'PAID' ? '🎉 تم تأكيد الدفع وتفعيل الخدمة بنجاح! جاري العودة...' : 'تم تسجيل فشل الدفع.';
    setTimeout(() => window.location.href = '/', 1200);
  }} else {{
    msg.style.color = '#dc2626';
    msg.innerText = 'فشل التحقق من التوقيع الرقمي';
  }}
}}
</script>
</body>
</html>"""
    return HTMLResponse(html)

server.app.router.routes = [
    r for r in server.app.router.routes
    if getattr(r, "path", "") not in ("/", "/{full_path:path}")
]

@server.app.api_route("/", methods=["GET", "HEAD"], include_in_schema=False)
async def serve_root_index():
    index_file = WEB_DIST / "index.html"
    if index_file.is_file():
        return FileResponse(index_file, headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"})
    return Response(status_code=200)

@server.app.api_route("/{full_path:path}", methods=["GET", "HEAD"], include_in_schema=False)
async def serve_spa_assets(full_path: str):
    if full_path.startswith("api/") or full_path.startswith("sandbox/") or full_path == "health":
        raise HTTPException(404, "Not found")
    candidate = WEB_DIST / full_path
    if full_path and candidate.is_file():
        return FileResponse(candidate, headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"})
    index_file = WEB_DIST / "index.html"
    if index_file.is_file():
        return FileResponse(index_file, headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"})
    raise HTTPException(404, "File not found")

def open_browser_when_ready():
    import urllib.request
    for _ in range(30):
        time.sleep(0.5)
        try:
            with urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=1) as resp:
                if resp.status == 200:
                    webbrowser.open(f"http://127.0.0.1:8000/?v={int(time.time())}")
                    return
        except Exception:
            pass

if __name__ == "__main__":
    threading.Thread(target=open_browser_when_ready, daemon=True).start()
    uvicorn.run(server.app, host="127.0.0.1", port=8000, log_level="info")