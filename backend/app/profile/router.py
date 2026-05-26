import asyncio

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from app.auth.dependencies import get_current_user
from app.profile.schemas import ProfileCreateRequest, ProfileUpdateRequest, ProfileResponse
from app.profile import service

router = APIRouter()


class FcmTokenBody(BaseModel):
    token: str


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(user=Depends(get_current_user)):
    return service.get_profile(user["id"])


@router.post("/complete", response_model=ProfileResponse)
async def complete_profile(body: ProfileCreateRequest, user=Depends(get_current_user)):
    return service.create_or_update_profile(user["id"], body)


@router.patch("/me", response_model=ProfileResponse)
async def update_my_profile(body: ProfileUpdateRequest, user=Depends(get_current_user)):
    return service.update_profile(user["id"], body)


# ─── FCM token registration ───────────────────────────────────────────────────
# Must be defined BEFORE /{user_id} so the wildcard doesn't swallow it.
@router.post("/fcm-token")
async def register_fcm_token(body: FcmTokenBody, user=Depends(get_current_user)):
    """Store (or update) the device FCM push token for the authenticated user."""
    service.save_fcm_token(user["id"], body.token)
    return {"ok": True}


# Must be defined BEFORE /{user_id} so the wildcard doesn't swallow it
@router.get("/preferences")
async def get_partner_preferences(user=Depends(get_current_user)):
    return service.get_partner_preferences(user["id"])


@router.put("/preferences")
async def update_partner_preferences_put(request: Request, user=Depends(get_current_user)):
    body = await request.json()
    return service.update_partner_preferences_raw(user["id"], body)


@router.patch("/preferences")
async def update_partner_preferences_patch(request: Request, user=Depends(get_current_user)):
    body = await request.json()
    return service.update_partner_preferences_raw(user["id"], body)


async def _fire_profile_view(viewer_id: str, target_id: str) -> None:
    """Best-effort profile-view notification — fire-and-forget from the route handler."""
    try:
        from app.notifications import service as notif_service
        from app.messages import ws as chat_ws
        notif = notif_service.create_profile_view(viewer_id, target_id)
        if notif:
            await chat_ws.broadcast_notification(target_id, notif)
    except Exception:
        pass


@router.get("/{user_id}", response_model=ProfileResponse)
async def get_user_profile(user_id: str, user=Depends(get_current_user)):
    """View another user's full profile. Only completed profiles are returned."""
    result = service.get_public_profile(viewer_id=user["id"], target_id=user_id)
    if user["id"] != user_id:
        asyncio.create_task(_fire_profile_view(user["id"], user_id))
    return result
