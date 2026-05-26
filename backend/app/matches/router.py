from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
from app.auth.dependencies import get_current_user
from app.matches import service
from app.messages import ws as chat_ws
from app.notifications import service as notif_service


class ReinviteBody(BaseModel):
    gift_slug: Optional[str] = None


class GiftLikeBody(BaseModel):
    message: Optional[str] = None

router = APIRouter()


async def _push_notification(user_id: str, notification: dict | None) -> None:
    """Best-effort WS push. Safe to call with a None (write-failed) notification."""
    if not notification:
        return
    try:
        await chat_ws.broadcast_notification(user_id, notification)
    except Exception:
        pass


@router.get("/discover")
async def discover(
    page: int = Query(1, ge=1),
    limit: int = Query(12, ge=1, le=50),
    min_age: Optional[int] = Query(None, ge=18, le=100),
    max_age: Optional[int] = Query(None, ge=18, le=100),
    city: Optional[str] = Query(None),
    country: Optional[str] = Query(None),
    relationship_goal: Optional[str] = Query(None),
    education_level: Optional[str] = Query(None),
    search: Optional[str] = Query(None, description="Match on name"),
    user=Depends(get_current_user),
):
    filters = {
        "min_age": min_age,
        "max_age": max_age,
        "city": city,
        "country": country,
        "relationship_goal": relationship_goal,
        "education_level": education_level,
        "search": search,
    }
    return service.get_potential_matches(user["id"], page, limit, filters)


@router.post("/{target_id}/like")
async def like(target_id: str, user=Depends(get_current_user)):
    if service.is_blocked(user["id"], target_id):
        raise HTTPException(status_code=403, detail="blocked")
    result = service.like_user(user["id"], target_id)
    if result.get("matched") and result.get("match_id"):
        await chat_ws.broadcast_match_created(result["match_id"], user["id"], target_id)
        # Live-refresh the notification bells for both users
        for recipient in (user["id"], target_id):
            latest = notif_service.list_for_user(recipient, limit=1)
            if latest:
                await _push_notification(recipient, latest[0])
    else:
        # "someone liked you" bell for the target
        latest = notif_service.list_for_user(target_id, limit=1)
        if latest and latest[0].get("type") == "like_received":
            await _push_notification(target_id, latest[0])
    return result


@router.post("/{target_id}/gift-like")
async def gift_like(
    target_id: str,
    body: GiftLikeBody | None = None,
    user=Depends(get_current_user),
):
    if service.is_blocked(user["id"], target_id):
        raise HTTPException(status_code=403, detail="blocked")
    result = service.gift_like_user(
        user["id"], target_id,
        message=(body.message if body else None),
    )
    if result.get("matched") and result.get("match_id"):
        await chat_ws.broadcast_match_created(result["match_id"], user["id"], target_id)
        for recipient in (user["id"], target_id):
            latest = notif_service.list_for_user(recipient, limit=1)
            if latest:
                await _push_notification(recipient, latest[0])
    else:
        latest = notif_service.list_for_user(target_id, limit=1)
        if latest and latest[0].get("type") == "gift_like":
            await _push_notification(target_id, latest[0])
    return result


@router.post("/{target_id}/pass")
async def pass_profile(target_id: str, user=Depends(get_current_user)):
    return service.pass_user(user["id"], target_id)


@router.get("/my-matches")
async def my_matches(user=Depends(get_current_user)):
    return service.get_my_matches(user["id"])


@router.get("/liked-me")
async def liked_me(user=Depends(get_current_user)):
    return service.get_who_liked_me(user["id"])


@router.get("/likes-sent")
async def likes_sent(user=Depends(get_current_user)):
    return service.get_likes_sent(user["id"])


@router.post("/{liker_id}/reject")
async def reject(liker_id: str, user=Depends(get_current_user)):
    return service.reject_liker(user["id"], liker_id)


@router.delete("/{target_id}/like")
async def unsend_like(target_id: str, user=Depends(get_current_user)):
    return service.unsend_like(user["id"], target_id)


@router.get("/disliked-by-me")
async def disliked_by_me(user=Depends(get_current_user)):
    return service.get_disliked_by_me(user["id"])


@router.delete("/{partner_id}/unmatch")
async def unmatch(partner_id: str, user=Depends(get_current_user)):
    result = service.unmatch_user(user["id"], partner_id)
    if result.get("match_id"):
        await chat_ws.broadcast_match_removed(
            result["match_id"], user["id"], partner_id
        )
    return result


@router.post("/{partner_id}/reinvite")
async def reinvite(
    partner_id: str,
    body: ReinviteBody | None = None,
    user=Depends(get_current_user),
):
    if service.is_blocked(user["id"], partner_id):
        raise HTTPException(status_code=403, detail="blocked")
    result = service.reinvite(
        user["id"], partner_id,
        gift_slug=(body.gift_slug if body else None),
    )
    note = result.get("notification")
    # Restoring immediately needs a match_restored ping for the partner;
    # inviting just pushes the invitation to them.
    recipient = partner_id
    await _push_notification(recipient, note)
    # If we restored unilaterally, also tell the UIs to un-remove the chat
    if result.get("restored") and result.get("match_id"):
        await chat_ws.broadcast_match_created(result["match_id"], user["id"], partner_id)
    return result


@router.post("/invitations/{notification_id}/accept")
async def accept_invitation(notification_id: str, user=Depends(get_current_user)):
    result = service.accept_invitation(user["id"], notification_id)
    if result.get("match_id") and result.get("partner_id"):
        # Re-open the chat on both sides
        await chat_ws.broadcast_match_created(
            result["match_id"], user["id"], result["partner_id"]
        )
        await _push_notification(result["partner_id"], result.get("notification"))
    return result


@router.post("/invitations/{notification_id}/decline")
async def decline_invitation(notification_id: str, user=Depends(get_current_user)):
    return service.decline_invitation(user["id"], notification_id)


@router.post("/{partner_id}/block")
async def block(partner_id: str, user=Depends(get_current_user)):
    """Block a user. Removes any active match and prevents future likes/gifts."""
    result = service.block_user(user["id"], partner_id)
    if result.get("match_id"):
        await chat_ws.broadcast_match_removed(
            result["match_id"], user["id"], partner_id
        )
    return result
