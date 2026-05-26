from fastapi import APIRouter, Depends
from app.auth.dependencies import get_current_user
from app.notifications import service

router = APIRouter()


@router.get("")
async def list_notifications(user=Depends(get_current_user)):
    return service.list_for_user(user["id"])


@router.get("/unread-count")
async def unread_count(user=Depends(get_current_user)):
    return {"count": service.unread_count(user["id"])}


@router.post("/{notification_id}/read")
async def read_one(notification_id: str, user=Depends(get_current_user)):
    service.mark_read(user["id"], notification_id)
    return {"ok": True}


@router.post("/read-all")
async def read_all(user=Depends(get_current_user)):
    service.mark_all_read(user["id"])
    return {"ok": True}
