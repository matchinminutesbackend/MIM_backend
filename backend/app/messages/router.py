from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from app.auth.dependencies import get_current_user
from app.messages import service, ws

router = APIRouter()


class SendMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)


class CallSummaryRequest(BaseModel):
    # Media type the call carried. 'video' unlocks the 🎥 icon; everything
    # else is treated as voice so we don't trust arbitrary strings from
    # clients.
    media: str = Field(..., pattern="^(audio|video)$")
    duration_seconds: int = Field(0, ge=0, le=60 * 60 * 24)
    missed: bool = False


@router.get("/conversations")
async def get_conversations(user=Depends(get_current_user)):
    """List all matched conversations with last message + unread count."""
    return service.get_conversations(user["id"])


@router.get("/{match_id}")
async def get_messages(match_id: str, user=Depends(get_current_user)):
    """Get full message history for a match."""
    return service.get_messages(user["id"], match_id)


@router.post("/{match_id}", status_code=201)
async def send_message(match_id: str, body: SendMessageRequest, user=Depends(get_current_user)):
    """Send a message in a match conversation. Broadcasts over WebSocket to both parties."""
    message = service.send_message(user["id"], match_id, body.content)
    await ws.broadcast_new_message(match_id, message)
    return message


@router.post("/{match_id}/call-summary", status_code=201)
async def log_call_summary(
    match_id: str,
    body: CallSummaryRequest,
    user=Depends(get_current_user),
):
    """Log a just-ended call as a system message in the chat thread.

    Called by the caller-side client after hangup (or by the callee on a
    decline / timeout so missed calls show up on both sides).
    """
    message = service.send_call_summary(
        user["id"], match_id,
        media=body.media,
        duration_seconds=body.duration_seconds,
        missed=body.missed,
    )
    await ws.broadcast_new_message(match_id, message)
    return message


@router.patch("/{match_id}/read")
async def mark_read(match_id: str, user=Depends(get_current_user)):
    """Mark all unread messages in a conversation as read. Notifies the sender over WS."""
    result = service.mark_read(user["id"], match_id)
    await ws.broadcast_messages_read(match_id, user["id"])
    return result
