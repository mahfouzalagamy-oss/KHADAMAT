import os
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".pdf"}
MAX_SIZE_BYTES = 8 * 1024 * 1024  # 8 MB

uploads_router = APIRouter(prefix="/api/uploads", tags=["uploads"])


def build_uploads_router(current_user_dep):
    @uploads_router.post("")
    async def upload_file(
        file: UploadFile = File(...),
        user: dict = Depends(current_user_dep),
    ):
        ext = Path(file.filename or "").suffix.lower()
        if ext not in ALLOWED_EXT:
            raise HTTPException(422, "صيغة الملف غير مدعومة (المسموح: jpg, png, webp, pdf)")
        raw = await file.read()
        if not raw or len(raw) > MAX_SIZE_BYTES:
            raise HTTPException(422, "حجم الملف غير صالح أو يتجاوز 8 ميجابايت")
        safe_name = f"{user['id'][:8]}_{uuid.uuid4().hex[:12]}{ext}"
        target = UPLOAD_DIR / safe_name
        target.write_bytes(raw)
        return {
            "filename": safe_name,
            "original_name": file.filename,
            "size": len(raw),
            "url": f"/api/uploads/{safe_name}",
        }

    @uploads_router.get("/{filename}")
    async def get_uploaded_file(filename: str):
        safe = os.path.basename(filename)
        target = UPLOAD_DIR / safe
        if not target.is_file():
            raise HTTPException(404, "الملف غير موجود")
        return FileResponse(target)

    return uploads_router