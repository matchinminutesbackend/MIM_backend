"""Admin API surface.

Every route depends on :func:`get_current_admin`. `/admin/login` is the
one exception — it issues a JWT after verifying the admin credentials.

Endpoint naming mirrors the frontend dashboard tabs:
  • /admin/login                    — POST, token issuance
  • /admin/me                       — GET, who am I + session check
  • /admin/stats                    — GET, overview cards
  • /admin/stats/signups            — GET, daily trend
  • /admin/users                    — GET, list + filter
  • /admin/users/{id}/active        — PATCH, enable/disable
  • /admin/users/{id}/admin         — PATCH, grant/revoke admin
  • /admin/users/{id}/credits       — POST, manual credit adjustment
  • /admin/verifications            — GET, queue
  • /admin/verifications/{id}/approve  — POST
  • /admin/verifications/{id}/reject   — POST
  • /admin/gifts                    — GET, PATCH
  • /admin/plans                    — GET, PATCH
  • /admin/withdrawals              — GET, PATCH status
  • /admin/settings                 — GET, PATCH
  • /admin/audit                    — GET, recent admin actions
"""
from typing import Any, Optional
from fastapi import APIRouter, Depends, HTTPException, File, Form, UploadFile
from pydantic import BaseModel, EmailStr

from app.supabase_client import supabase_admin
from app.auth.utils import verify_password, create_token
from app.admin.dependencies import get_current_admin
from app.admin import service as admin_service


router = APIRouter()


# ── Login ────────────────────────────────────────────────────────
class AdminLoginRequest(BaseModel):
    email:    EmailStr
    password: str


@router.post("/login")
async def admin_login(body: AdminLoginRequest):
    """Separate endpoint from /auth/login so the admin SPA has its own
    surface — same JWT format, but we refuse to mint one for non-admin
    accounts so the dashboard can't even half-render on a regular login.
    """
    res = supabase_admin.table("users").select("*").eq("email", body.email.lower()).execute()
    if not res.data:
        raise HTTPException(401, "Invalid email or password")
    user = res.data[0]

    if not user.get("is_active", True):
        raise HTTPException(403, "Account is disabled")
    if not user.get("password_hash"):
        # Google-only accounts can't log in as admin — force a real password.
        raise HTTPException(401, "Invalid email or password")
    if not verify_password(body.password, user["password_hash"]):
        raise HTTPException(401, "Invalid email or password")
    if not user.get("is_admin"):
        raise HTTPException(403, "This account doesn't have admin access")

    token = create_token(user["id"], user["email"])
    return {
        "access_token":  token,
        "refresh_token": token,
        "user_id":       user["id"],
        "email":         user["email"],
        "name":          user.get("name") or "",
        "is_admin":      True,
    }


@router.get("/me")
async def admin_me(admin: dict = Depends(get_current_admin)):
    return admin


# ── Stats ────────────────────────────────────────────────────────
@router.get("/stats")
async def admin_stats(_: dict = Depends(get_current_admin)):
    return admin_service.get_overview_stats()


@router.get("/stats/signups")
async def admin_signup_trend(days: int = 14, _: dict = Depends(get_current_admin)):
    return admin_service.get_signup_series(days=days)


# ── Users ────────────────────────────────────────────────────────
@router.get("/users")
async def admin_list_users(
    limit: int = 50,
    offset: int = 0,
    scope: str = "all",
    q: Optional[str] = None,
    _: dict = Depends(get_current_admin),
):
    return admin_service.list_users(limit=limit, offset=offset, scope=scope, q=q)


class UserActiveBody(BaseModel):
    is_active: bool


@router.get("/users/{user_id}/detail")
async def admin_user_detail(
    user_id: str, _: dict = Depends(get_current_admin),
):
    """Full drill-down for one user — profile, photos, activity,
    payments, wallet, and event telemetry. Populates the user detail
    drawer on the admin dashboard.
    """
    return admin_service.get_user_detail(user_id)


@router.patch("/users/{user_id}/active")
async def admin_set_user_active(
    user_id: str, body: UserActiveBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.set_user_active(admin["id"], user_id, body.is_active)


class UserAdminBody(BaseModel):
    is_admin: bool


@router.patch("/users/{user_id}/admin")
async def admin_set_user_admin(
    user_id: str, body: UserAdminBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.set_user_admin(admin["id"], user_id, body.is_admin)


class CreditAdjustBody(BaseModel):
    delta:  int
    reason: str


@router.post("/users/{user_id}/credits")
async def admin_adjust_credits(
    user_id: str, body: CreditAdjustBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.adjust_credits(admin["id"], user_id, body.delta, body.reason)


# ── Verifications ────────────────────────────────────────────────
@router.get("/verifications")
async def admin_list_verifications(
    status: str = "pending",
    limit:  int = 50,
    _: dict = Depends(get_current_admin),
):
    return admin_service.list_verifications(status=status, limit=limit)


@router.post("/verifications/{user_id}/approve")
async def admin_approve_verification(
    user_id: str,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.approve_verification(admin["id"], user_id)


class RejectBody(BaseModel):
    reason: str


@router.post("/verifications/{user_id}/reject")
async def admin_reject_verification(
    user_id: str, body: RejectBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.reject_verification(admin["id"], user_id, body.reason)


# ── Gifts ────────────────────────────────────────────────────────
@router.get("/gifts")
async def admin_list_gifts(_: dict = Depends(get_current_admin)):
    return admin_service.list_gifts_admin()


class GiftPatchBody(BaseModel):
    cost:       Optional[int]  = None
    name:       Optional[str]  = None
    icon:       Optional[str]  = None
    tier:       Optional[str]  = None
    is_active:  Optional[bool] = None
    sort_order: Optional[int]  = None


@router.patch("/gifts/{gift_id}")
async def admin_update_gift(
    gift_id: str, body: GiftPatchBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.update_gift(
        admin["id"], gift_id,
        cost=body.cost, name=body.name, icon=body.icon,
        tier=body.tier, is_active=body.is_active, sort_order=body.sort_order,
    )


# ── Plans ────────────────────────────────────────────────────────
@router.get("/plans")
async def admin_list_plans(_: dict = Depends(get_current_admin)):
    return admin_service.list_plans_admin()


class PlanPatchBody(BaseModel):
    monthly_inr: int  # pass 0 to reset to code default


@router.patch("/plans/{slug}")
async def admin_update_plan(
    slug: str, body: PlanPatchBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.update_plan_price(admin["id"], slug, body.monthly_inr)


# ── Withdrawals ──────────────────────────────────────────────────
@router.get("/withdrawals")
async def admin_list_withdrawals(
    status: Optional[str] = None,
    limit:  int = 50,
    _: dict = Depends(get_current_admin),
):
    return admin_service.list_withdrawals_admin(status=status, limit=limit)


class WithdrawalPatchBody(BaseModel):
    status:        str                  # processing | paid | rejected
    rzp_payout_id: Optional[str] = None
    reason:        Optional[str] = None


@router.patch("/withdrawals/{withdrawal_id}")
async def admin_mark_withdrawal(
    withdrawal_id: str, body: WithdrawalPatchBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.mark_withdrawal(
        admin["id"], withdrawal_id, body.status,
        rzp_payout_id=body.rzp_payout_id, reason=body.reason,
    )


# ── Settings ─────────────────────────────────────────────────────
@router.get("/settings")
async def admin_list_settings(_: dict = Depends(get_current_admin)):
    return admin_service.list_settings()


class SettingPatchBody(BaseModel):
    key:   str
    value: Any


@router.patch("/settings")
async def admin_update_setting(
    body: SettingPatchBody,
    admin: dict = Depends(get_current_admin),
):
    return admin_service.update_setting(admin["id"], body.key, body.value)


# ── Audit log ────────────────────────────────────────────────────
@router.get("/audit")
async def admin_list_audit(
    limit: int = 100,
    _: dict = Depends(get_current_admin),
):
    return admin_service.list_audit_log(limit=limit)


# ── Reports ───────────────────────────────────────────────────────────────────

@router.get("/reports")
async def admin_list_reports(
    status: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    _: dict = Depends(get_current_admin),
):
    query = (
        supabase_admin.table("reports")
        .select("*, reporter:reporter_id(id,name,main_image_url), reported:reported_id(id,name,main_image_url,is_banned,ban_reason,ban_expires_at)")
        .order("created_at", desc=True)
        .limit(limit)
        .offset(offset)
    )
    if status:
        query = query.eq("status", status)
    res = query.execute()
    return res.data or []


@router.patch("/reports/{report_id}")
async def admin_update_report(
    report_id: str,
    body: dict,
    _: dict = Depends(get_current_admin),
):
    allowed = {"status", "admin_note"}
    payload = {k: v for k, v in body.items() if k in allowed}
    if not payload:
        raise HTTPException(status_code=400, detail="Nothing to update")
    payload["updated_at"] = "now()"
    res = supabase_admin.table("reports").update(payload).eq("id", report_id).execute()
    return res.data[0] if res.data else {}


@router.post("/users/{user_id}/ban")
async def admin_ban_user(
    user_id: str,
    body: dict,
    _: dict = Depends(get_current_admin),
):
    from datetime import datetime, timezone, timedelta
    reason   = body.get("reason", "Violated community guidelines")
    duration = body.get("duration", "permanent")  # "1d","7d","30d","365d","permanent"

    duration_map = {
        "1d":    timedelta(days=1),
        "7d":    timedelta(days=7),
        "30d":   timedelta(days=30),
        "365d":  timedelta(days=365),
    }
    expires_at = None
    if duration in duration_map:
        expires_at = (datetime.now(timezone.utc) + duration_map[duration]).isoformat()

    supabase_admin.table("profiles").update({
        "is_banned":      True,
        "ban_reason":     reason,
        "ban_expires_at": expires_at,
    }).eq("id", user_id).execute()
    return {"message": "User banned", "user_id": user_id, "expires_at": expires_at}


@router.post("/users/{user_id}/unban")
async def admin_unban_user(
    user_id: str,
    _: dict = Depends(get_current_admin),
):
    supabase_admin.table("profiles").update({
        "is_banned":      False,
        "ban_reason":     None,
        "ban_expires_at": None,
    }).eq("id", user_id).execute()
    return {"message": "User unbanned", "user_id": user_id}


# ── Advertisement ─────────────────────────────────────────────────────────────
import uuid

@router.get("/ad")
async def admin_get_ad(_: dict = Depends(get_current_admin)):
    res = supabase_admin.table("advertisements").select("*").eq("is_active", True).order("created_at", desc=True).limit(1).execute()
    return res.data[0] if res.data else None


@router.post("/ad")
async def admin_save_ad(
    link_url: str = Form(...),
    file: Optional[UploadFile] = File(None),
    admin: dict = Depends(get_current_admin),
):
    image_url = None
    if file:
        file_ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
        file_path = f"ads/{uuid.uuid4()}.{file_ext}"
        content = await file.read()
        try:
            # We reuse the profile-images bucket for simplicity
            res = supabase_admin.storage.from_("profile-images").upload(
                file_path, content, {"content-type": file.content_type}
            )
            # Build public URL manually since supabase-py get_public_url can be finicky
            # The bucket must be public.
            base_url = supabase_admin.supabase_url
            image_url = f"{base_url}/storage/v1/object/public/profile-images/{file_path}"
        except Exception as e:
            raise HTTPException(500, f"Failed to upload poster: {str(e)}")

    if not image_url:
        existing = supabase_admin.table("advertisements").select("image_url").eq("is_active", True).order("created_at", desc=True).limit(1).execute()
        if not existing.data:
            raise HTTPException(400, "Image is required for new ads")
        image_url = existing.data[0]["image_url"]

    # Deactivate all existing ads
    # neq uuid is just a hack to update all rows
    supabase_admin.table("advertisements").update({"is_active": False}).neq("id", "00000000-0000-0000-0000-000000000000").execute()

    # Insert new
    res = supabase_admin.table("advertisements").insert({
        "image_url": image_url,
        "link_url": link_url,
        "is_active": True
    }).execute()
    return res.data[0]


@router.delete("/ad")
async def admin_delete_ad(_: dict = Depends(get_current_admin)):
    supabase_admin.table("advertisements").update({"is_active": False}).neq("id", "00000000-0000-0000-0000-000000000000").execute()
    return {"message": "Ad disabled"}


# ── Subscription grant ────────────────────────────────────────────

class GrantSubscriptionBody(BaseModel):
    plan:   str           # e.g. "pro_monthly", "pro_3m", "pro_6m", "pro_1y"
    months: int
    reason: Optional[str] = "Admin complimentary grant"


@router.post("/users/{user_id}/grant-subscription")
async def admin_grant_subscription(
    user_id: str, body: GrantSubscriptionBody,
    admin: dict = Depends(get_current_admin),
):
    """Give a user a free subscription. Cancels any existing active sub first."""
    from datetime import datetime, timezone, timedelta

    if body.months < 1 or body.months > 24:
        raise HTTPException(400, "months must be between 1 and 24")

    now = datetime.now(timezone.utc)
    expires_at = (now + timedelta(days=30 * body.months)).isoformat()

    # Cancel existing active subscriptions for this user
    supabase_admin.table("subscriptions").update({"status": "cancelled"}) \
        .eq("user_id", user_id).eq("status", "active").execute()

    res = supabase_admin.table("subscriptions").insert({
        "user_id":    user_id,
        "plan":       body.plan,
        "months":     body.months,
        "inr_paise":  0,
        "starts_at":  now.isoformat(),
        "expires_at": expires_at,
        "status":     "active",
    }).execute()

    # Audit
    try:
        supabase_admin.table("admin_audit_log").insert({
            "admin_id":        admin["id"],
            "action":          "grant_subscription",
            "target_user_id":  user_id,
            "meta": {"plan": body.plan, "months": body.months, "reason": body.reason},
        }).execute()
    except Exception:
        pass

    return res.data[0] if res.data else {"user_id": user_id, "expires_at": expires_at}


# ── Photo moderation ──────────────────────────────────────────────

@router.delete("/users/{user_id}/photos/{image_id}")
async def admin_delete_user_photo(
    user_id: str, image_id: str,
    admin: dict = Depends(get_current_admin),
):
    """Remove an inappropriate or policy-violating photo on behalf of a user."""
    res = supabase_admin.table("profile_images") \
        .select("*").eq("id", image_id).eq("user_id", user_id).execute()
    if not res.data:
        raise HTTPException(404, "Image not found")

    img = res.data[0]
    image_url = img.get("image_url", "") or img.get("url", "")
    is_main   = img.get("is_main", False)

    # Remove from DB
    supabase_admin.table("profile_images").delete().eq("id", image_id).execute()

    # Promote next image to main if needed
    if is_main:
        next_res = supabase_admin.table("profile_images") \
            .select("image_url").eq("user_id", user_id) \
            .order("order_index").limit(1).execute()
        new_main = next_res.data[0]["image_url"] if next_res.data else None
        supabase_admin.table("profiles").update({"main_image_url": new_main}) \
            .eq("id", user_id).execute()

    # Best-effort storage delete
    try:
        if "/profile-images/" in image_url:
            storage_path = image_url.split("/profile-images/")[-1].split("?")[0]
            supabase_admin.storage.from_("profile-images").remove([storage_path])
    except Exception:
        pass

    # Audit
    try:
        supabase_admin.table("admin_audit_log").insert({
            "admin_id":       admin["id"],
            "action":         "delete_user_photo",
            "target_user_id": user_id,
            "meta": {"image_id": image_id, "image_url": image_url},
        }).execute()
    except Exception:
        pass

    return {"message": "Photo deleted", "image_id": image_id}

