from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.auth.utils import decode_token

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verify our own JWT and reject banned users."""
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        email = payload.get("email")
        if not user_id:
            raise HTTPException(401, "Invalid token payload")
    except ValueError:
        raise HTTPException(401, "Invalid or expired token")

    from app.supabase_client import supabase_admin
    from datetime import datetime, timezone
    res = supabase_admin.table("profiles").select("is_banned,ban_reason,ban_expires_at").eq("id", user_id).maybe_single().execute()
    if res and res.data and res.data.get("is_banned"):
        expires_at = res.data.get("ban_expires_at")
        # Auto-lift expired temporary bans
        if expires_at:
            try:
                exp_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
                if datetime.now(timezone.utc) >= exp_dt:
                    supabase_admin.table("profiles").update(
                        {"is_banned": False, "ban_reason": None, "ban_expires_at": None}
                    ).eq("id", user_id).execute()
                    return {"id": user_id, "email": email}
            except Exception:
                pass
        reason = res.data.get("ban_reason") or "Your account has been suspended."
        raise HTTPException(403, detail={
            "code": "account_banned",
            "message": reason,
            "ban_expires_at": expires_at,
        })

    return {"id": user_id, "email": email}
