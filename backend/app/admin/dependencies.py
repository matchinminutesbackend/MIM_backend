"""Admin-only dependency.

Reuses the regular JWT pipeline but additionally requires `users.is_admin = TRUE`.
Every admin endpoint depends on :func:`get_current_admin`, so regular JWTs that
happen to leak won't unlock the dashboard — only flipping the flag in the DB does.
"""
from fastapi import Depends, HTTPException

from app.auth.dependencies import get_current_user
from app.supabase_client import supabase_admin


async def get_current_admin(user: dict = Depends(get_current_user)) -> dict:
    """Verify the bearer token AND that the user is flagged as admin."""
    try:
        res = (
            supabase_admin.table("users")
            .select("id, email, name, is_admin, is_active")
            .eq("id", user["id"])
            .limit(1)
            .execute()
        )
    except Exception:
        raise HTTPException(500, "Admin check failed — is the is_admin column present?")

    if not res.data:
        raise HTTPException(401, "Account not found")
    row = res.data[0]
    if not row.get("is_active", True):
        raise HTTPException(403, "Account disabled")
    if not row.get("is_admin"):
        raise HTTPException(403, "Admin access required")

    return {
        "id":    row["id"],
        "email": row["email"],
        "name":  row.get("name") or "",
    }
