"""Gift routes.

Endpoints:
  GET  /gifts                     — active catalog (cost ascending)
  POST /gifts/send                — send a gift (chat or invite context)
  GET  /gifts/received            — gifts received by me (for overlay / inbox)
  GET  /gifts/match/{match_id}    — gift history inside a specific chat

Invite-context lifecycle is driven by the existing invite accept/decline
routes in matches/router.py — they call into gifts.service.settle_*.
"""
import logging
from typing import Optional, Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.gifts import service
from app.messages import service as messages_service
from app.messages import ws as chat_ws
from app.supabase_client import supabase_admin

log = logging.getLogger(__name__)
router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────
class SendGiftRequest(BaseModel):
    receiver_id: str
    gift_slug: str = Field(..., min_length=1)
    context: Literal["invite", "chat"]
    match_id: Optional[str] = None


# ── Routes ───────────────────────────────────────────────────────
@router.get("")
@router.get("/")
async def list_catalog():
    try:
        return service.list_gifts()
    except Exception as e:
        log.warning("gifts.catalog fallback (tables missing?): %s", e)
        return []


@router.post("/send", status_code=201)
async def send_gift(body: SendGiftRequest, user=Depends(get_current_user)):
    """Send a gift. For `chat` context we also write a companion message
    row carrying `gift_send_id` so the chat history renders a gift card
    inline, and broadcast it over WS to the partner for a live overlay.
    """
    if body.context == "chat":
        if not body.match_id:
            raise HTTPException(400, "match_id required for chat gifts")
        # Ensure caller is in the match — reuses the existing guard.
        match = messages_service._assert_participant(user["id"], body.match_id)
        # Validate declared receiver matches the other participant.
        other = match["user2_id"] if match["user1_id"] == user["id"] else match["user1_id"]
        if body.receiver_id != other:
            raise HTTPException(400, "receiver_id doesn't match this conversation")

    result = service.send_gift(
        sender_id=user["id"],
        receiver_id=body.receiver_id,
        gift_slug=body.gift_slug,
        context=body.context,
        match_id=body.match_id,
    )

    # Chat context: companion message row + WS broadcast so the partner
    # sees the gift overlay + history card in real-time.
    if body.context == "chat":
        gs = result["gift_send"]
        gift = result["gift"]
        msg_content = f"🎁 Sent a {gift['name']}"
        msg = supabase_admin.table("messages").insert({
            "match_id":     body.match_id,
            "sender_id":    user["id"],
            "content":      msg_content,
            "is_read":      False,
            "gift_send_id": gs["id"],
        }).execute()
        if msg.data:
            # Back-link so UI rendering is one-pass.
            supabase_admin.table("gift_sends").update(
                {"message_id": msg.data[0]["id"]}
            ).eq("id", gs["id"]).execute()
            # Enrich the broadcast payload so the receiver can render the
            # overlay without a second fetch.
            msg_row = {**msg.data[0], "gift": gift, "gift_send": gs}
            try:
                await chat_ws.broadcast_new_message(body.match_id, msg_row)
            except Exception:
                pass
            result["message"] = msg_row

    return result


@router.get("/received")
async def received(limit: int = 20, user=Depends(get_current_user)):
    """Gifts I received (newest first) — powers a 'gift inbox' if we want one."""
    try:
        res = (
            supabase_admin.table("gift_sends")
            .select("*, gift:gifts!gift_id(slug,name,icon,tier)")
            .eq("receiver_id", user["id"])
            .order("created_at", desc=True)
            .limit(limit).execute()
        )
        return res.data or []
    except Exception as e:
        log.warning("gifts.received fallback: %s", e)
        return []


@router.get("/match/{match_id}")
async def history_for_match(match_id: str, user=Depends(get_current_user)):
    """Gift history inside a specific chat — both directions."""
    # Same participant guard as messages.
    messages_service._assert_participant(user["id"], match_id)
    try:
        return service.gifts_for_match(match_id)
    except Exception as e:
        log.warning("gifts.match fallback: %s", e)
        return []
