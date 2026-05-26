"""Instant Match endpoints.

  POST   /instant-match/join     — join queue (or get paired → confirming)
  GET    /instant-match/status   — poll while waiting or confirming
  POST   /instant-match/skip     — skip the current match, return to searching
  POST   /instant-match/confirm  — accept match, go to chat (consumes quota)
  DELETE /instant-match/leave    — cancel while still in 'waiting' state
  GET    /instant-match/info     — feature flag + quota for the button UI
"""
from fastapi import APIRouter, Depends
from app.auth.dependencies import get_current_user
from app.instant_match import service

router = APIRouter()


@router.post("/join")
async def join_instant_match(user: dict = Depends(get_current_user)):
    return service.join_queue(user["id"])


@router.get("/status")
async def instant_match_status(user: dict = Depends(get_current_user)):
    return service.poll_status(user["id"])


@router.post("/skip")
async def skip_instant_match(user: dict = Depends(get_current_user)):
    """Skip the current match during the confirmation window.
    Frontend should immediately re-call /join to search for a new partner.
    """
    return service.skip_match(user["id"])


@router.post("/confirm")
async def confirm_instant_match(user: dict = Depends(get_current_user)):
    """Confirm the match (Start Chat / timer expired). Consumes quota."""
    return service.confirm_match(user["id"])


@router.delete("/leave")
async def leave_instant_match(user: dict = Depends(get_current_user)):
    return service.leave_queue(user["id"])


@router.get("/info")
async def instant_match_info(user: dict = Depends(get_current_user)):
    return service.get_quota_info(user["id"])


# ── Instant Match Chat endpoints ──────────────────────────────────────────────

@router.get("/chat/{match_id}/status")
async def im_chat_status(match_id: str, user: dict = Depends(get_current_user)):
    """Poll whether the IM chat is still live and check invite state."""
    return service.get_chat_status(user["id"], match_id)


@router.delete("/chat/{match_id}/leave")
async def im_chat_leave(match_id: str, user: dict = Depends(get_current_user)):
    """Leave the instant match chat (marks it ended for both users)."""
    return service.leave_instant_chat(user["id"], match_id)


@router.post("/chat/{match_id}/invite")
async def im_chat_send_invite(match_id: str, user: dict = Depends(get_current_user)):
    """Send a friend invite within the instant match chat."""
    return service.send_friend_invite(user["id"], match_id)


@router.post("/chat/{match_id}/invite/accept")
async def im_chat_accept_invite(match_id: str, user: dict = Depends(get_current_user)):
    """Accept the pending friend invite — chat becomes permanent."""
    return service.accept_friend_invite(user["id"], match_id)


@router.post("/chat/{match_id}/invite/decline")
async def im_chat_decline_invite(match_id: str, user: dict = Depends(get_current_user)):
    """Decline or cancel the pending friend invite."""
    return service.decline_friend_invite(user["id"], match_id)
