import uuid
import io
from datetime import datetime, timezone
from fastapi import UploadFile, HTTPException
from PIL import Image
from app.supabase_client import supabase_admin
from app.config import settings

BUCKET = "profile-images"
MAX_IMAGES = 6
ALLOWED_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
MAX_SIZE_MB = 5


def _resize_image(file_bytes: bytes, max_px: int = 1200) -> bytes:
    img = Image.open(io.BytesIO(file_bytes))
    img = img.convert("RGB")
    if max(img.size) > max_px:
        img.thumbnail((max_px, max_px), Image.LANCZOS)
    output = io.BytesIO()
    img.save(output, format="JPEG", quality=85, optimize=True)
    return output.getvalue()


async def upload_image(user_id: str, file: UploadFile, is_main: bool = False) -> dict:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, or WebP images allowed")

    file_bytes = await file.read()
    if len(file_bytes) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"Image must be under {MAX_SIZE_MB}MB")

    existing = supabase_admin.table("profile_images").select("id").eq("user_id", user_id).execute()
    if len(existing.data) >= MAX_IMAGES:
        raise HTTPException(status_code=400, detail=f"Maximum {MAX_IMAGES} images allowed")

    order_index = len(existing.data)
    if is_main and order_index != 0 and not existing.data:
        order_index = 0

    processed = _resize_image(file_bytes)
    filename = f"{user_id}/{uuid.uuid4()}.jpg"

    supabase_admin.storage.from_(BUCKET).upload(
        filename,
        processed,
        file_options={"content-type": "image/jpeg"},
    )

    public_url = f"{settings.supabase_url}/storage/v1/object/public/{BUCKET}/{filename}"

    if is_main or order_index == 0:
        supabase_admin.table("profile_images").update({"is_main": False}).eq("user_id", user_id).execute()

    record = supabase_admin.table("profile_images").insert({
        "user_id": user_id,
        "image_url": public_url,
        "is_main": is_main or order_index == 0,
        "order_index": order_index,
    }).execute()

    if is_main or order_index == 0:
        supabase_admin.table("profiles").update({"main_image_url": public_url}).eq("id", user_id).execute()

    return record.data[0]


def get_user_images(user_id: str) -> list:
    res = supabase_admin.table("profile_images").select("*").eq("user_id", user_id).order("order_index").execute()
    return res.data


def set_main_image(user_id: str, image_id: str) -> dict:
    img = supabase_admin.table("profile_images").select("*").eq("id", image_id).eq("user_id", user_id).single().execute()
    if not img.data:
        raise HTTPException(status_code=404, detail="Image not found")

    supabase_admin.table("profile_images").update({"is_main": False}).eq("user_id", user_id).execute()
    supabase_admin.table("profile_images").update({"is_main": True}).eq("id", image_id).execute()
    supabase_admin.table("profiles").update({"main_image_url": img.data["image_url"]}).eq("id", user_id).execute()
    return img.data


async def upload_cover_image(user_id: str, file: UploadFile) -> dict:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, or WebP images allowed")

    file_bytes = await file.read()
    if len(file_bytes) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"Image must be under {MAX_SIZE_MB}MB")

    # Wider aspect is expected for banners; cap longer side at 1800
    processed = _resize_image(file_bytes, max_px=1800)
    filename = f"{user_id}/cover-{uuid.uuid4()}.jpg"

    supabase_admin.storage.from_(BUCKET).upload(
        filename,
        processed,
        file_options={"content-type": "image/jpeg"},
    )

    public_url = f"{settings.supabase_url}/storage/v1/object/public/{BUCKET}/{filename}"

    # Try to remove old cover file to keep storage tidy
    try:
        prev = supabase_admin.table("profiles").select("cover_image_url").eq("id", user_id).single().execute()
        old_url = (prev.data or {}).get("cover_image_url")
        if old_url:
            old_path = old_url.split(f"{BUCKET}/")[-1]
            supabase_admin.storage.from_(BUCKET).remove([old_path])
    except Exception:
        pass

    try:
        supabase_admin.table("profiles").update({"cover_image_url": public_url}).eq("id", user_id).execute()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail="Could not save cover. Make sure the profiles table has a `cover_image_url text` column.",
        ) from e

    return {"cover_image_url": public_url}


async def upload_verification_selfie(user_id: str, file: UploadFile) -> dict:
    """Saves a face-verification selfie for admin review.

    Stored privately per-user and referenced from profiles.verification_image_url.
    The selfie lands in the admin queue as `verification_status='pending'`;
    an admin approves/rejects it from the dashboard. is_verified only flips
    to TRUE on admin approval — no auto-approval.
    """
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, or WebP images allowed")

    file_bytes = await file.read()
    if len(file_bytes) > MAX_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"Selfie must be under {MAX_SIZE_MB}MB")

    processed = _resize_image(file_bytes, max_px=900)
    filename = f"{user_id}/verification-{uuid.uuid4()}.jpg"

    supabase_admin.storage.from_(BUCKET).upload(
        filename,
        processed,
        file_options={"content-type": "image/jpeg"},
    )
    public_url = f"{settings.supabase_url}/storage/v1/object/public/{BUCKET}/{filename}"

    # Remove previous verification selfie if present
    try:
        prev = supabase_admin.table("profiles").select("verification_image_url").eq("id", user_id).single().execute()
        old_url = (prev.data or {}).get("verification_image_url")
        if old_url:
            old_path = old_url.split(f"{BUCKET}/")[-1]
            supabase_admin.storage.from_(BUCKET).remove([old_path])
    except Exception:
        pass

    try:
        supabase_admin.table("profiles").update({
            "verification_image_url":       public_url,
            "is_verified":                  False,
            "verification_status":          "pending",
            "verification_submitted_at":    datetime.now(timezone.utc).isoformat(),
            "verification_reviewed_at":     None,
            "verification_reviewed_by":     None,
            "verification_note":            None,
        }).eq("id", user_id).execute()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=(
                "Could not save verification. Ensure the 2026_admin migration ran "
                "(adds verification_status + related columns)."
            ),
        ) from e

    return {
        "verification_image_url": public_url,
        "is_verified":            False,
        "verification_status":    "pending",
        "message":                "Selfie submitted. We'll review and verify within 24 hours.",
    }


def delete_cover_image(user_id: str):
    try:
        prev = supabase_admin.table("profiles").select("cover_image_url").eq("id", user_id).single().execute()
        old_url = (prev.data or {}).get("cover_image_url")
    except Exception:
        old_url = None

    if old_url:
        try:
            old_path = old_url.split(f"{BUCKET}/")[-1]
            supabase_admin.storage.from_(BUCKET).remove([old_path])
        except Exception:
            pass
    supabase_admin.table("profiles").update({"cover_image_url": None}).eq("id", user_id).execute()


def delete_image(user_id: str, image_id: str):
    img = supabase_admin.table("profile_images").select("*").eq("id", image_id).eq("user_id", user_id).single().execute()
    if not img.data:
        raise HTTPException(status_code=404, detail="Image not found")

    path = img.data["image_url"].split(f"{BUCKET}/")[-1]
    supabase_admin.storage.from_(BUCKET).remove([path])
    supabase_admin.table("profile_images").delete().eq("id", image_id).execute()

    if img.data["is_main"]:
        first = supabase_admin.table("profile_images").select("*").eq("user_id", user_id).order("order_index").limit(1).execute()
        if first.data:
            supabase_admin.table("profile_images").update({"is_main": True}).eq("id", first.data[0]["id"]).execute()
            supabase_admin.table("profiles").update({"main_image_url": first.data[0]["image_url"]}).eq("id", user_id).execute()
        else:
            supabase_admin.table("profiles").update({"main_image_url": None}).eq("id", user_id).execute()
