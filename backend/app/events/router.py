"""Event ingestion endpoint.

One route — POST /events — authenticated, fires-and-forgets into the
`user_events` table. The client is expected to call this in a
non-blocking way (fetch without await-chaining into the UI).
"""
from typing import Optional, Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.events import service

router = APIRouter()


class EventBody(BaseModel):
    event:     str
    target_id: Optional[str] = None
    meta:      Optional[dict[str, Any]] = None


@router.post("", status_code=204)
async def log_event(body: EventBody, user: dict = Depends(get_current_user)):
    """Append a single event row. Always returns 204 — the caller
    should not care whether the write succeeded."""
    service.log(user["id"], body.event, body.target_id, body.meta)
    return None
