from fastapi import APIRouter, Depends, Request
from app.auth.dependencies import get_current_user

router = APIRouter()


@router.post("")
async def submit_report(request: Request, user=Depends(get_current_user)):
    body = await request.json()
    from app.supabase_client import supabase_admin
    from fastapi import HTTPException

    reason = body.get("reason", "").strip()
    if not reason:
        raise HTTPException(status_code=400, detail="Reason is required")

    reported_id_raw = body.get("reported_id", "")
    payload = {
        "reporter_id":  user["id"],
        "reported_id":  reported_id_raw if reported_id_raw else None,
        "reason":       reason,
        "description":  body.get("description", "").strip() or None,
    }
    res = supabase_admin.table("reports").insert(payload).execute()
    return {"message": "Report submitted successfully", "id": res.data[0]["id"]}
