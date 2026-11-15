$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " تشغيل منصة خدمات | KHADAMAT محلياً (FastAPI + Expo)" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$Root\backend'; python -m uvicorn server:app --reload --host 0.0.0.0 --port 8000"
Start-Sleep -Seconds 2
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$Root\frontend'; yarn start"

Write-Host "✅ تم فتح نافذتي الخادم (Port 8000) والواجهة (Expo)." -ForegroundColor Green
Write-Host "🔑 حسابات الدخول التجريبية (رمز OTP: 123456):" -ForegroundColor Yellow
Write-Host "   • عميل:  01000000004"
Write-Host "   • فني:   01000000003"
Write-Host "   • شركة:  01000000002"
Write-Host "   • إدارة: 01000000001"