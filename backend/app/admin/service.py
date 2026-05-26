"""Admin dashboard service layer.

All admin-only reads + mutations live here. Every mutation writes an
`admin_audit_log` row so we can trace who changed what after the fact.

Conventions:
  • Read helpers never touch the audit log.
  • Mutation helpers take an ``admin_id`` as their first argument and
    always call :func:`_audit` before returning. If the mutation itself
    fails, the audit row is never written — correct.
  • Prefer small pure helpers; keep Supabase calls close to the surface
    so we don't accidentally grow a second ORM.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from fastapi import HTTPException

from app.supabase_client import supabase_admin
from app.wallet import service as wallet_service
from app.subscriptions import service as subs_service
from app.events import service as events_service


# ── Audit log ────────────────────────────────────────────────────
def _audit(
    admin_id: str,
    action: str,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    meta: Optional[dict] = None,
) -> None:
    """Best-effort audit row. A failing audit write must NOT break the
    admin action — we already committed the mutation, so swallow errors
    and let monitoring pick them up.
    """
    try:
        supabase_admin.table("admin_audit_log").insert({
            "admin_id":    admin_id,
            "action":      action,
            "target_type": target_type,
            "target_id":   str(target_id) if target_id is not None else None,
            "meta":        meta or {},
        }).execute()
    except Exception:
        pass


# ── Dashboard stats ──────────────────────────────────────────────
def _count(table: str, **filters) -> int:
    """Supabase returns total row count when using `count='exact'` + head=True."""
    try:
        q = supabase_admin.table(table).select("id", count="exact")
        for k, v in filters.items():
            q = q.eq(k, v)
        res = q.execute()
        return res.count or 0
    except Exception:
        return 0


def get_overview_stats() -> dict:
    """Numbers shown on the top of the admin dashboard.

    Everything is cheap aggregate counts — the page can poll this every
    30s without stressing the DB.
    """
    now = datetime.now(timezone.utc)
    since_today = (now - timedelta(days=1)).isoformat()
    since_week  = (now - timedelta(days=7)).isoformat()

    # Users
    total_users = _count("users")
    active_subs = _count("subscriptions", status="active")

    # Recent signups
    try:
        recent_users = (
            supabase_admin.table("users").select("id", count="exact")
            .gte("created_at", since_today).execute()
        )
        signups_today = recent_users.count or 0
    except Exception:
        signups_today = 0
    try:
        weekly = (
            supabase_admin.table("users").select("id", count="exact")
            .gte("created_at", since_week).execute()
        )
        signups_week = weekly.count or 0
    except Exception:
        signups_week = 0

    # Verification queue
    pending_verifications = _count("profiles", verification_status="pending")

    # Withdrawals awaiting action
    pending_withdrawals = _count("withdrawal_requests", status="pending")

    # Revenue — sum of inr_paise on active subs, converted to rupees.
    try:
        subs_res = (
            supabase_admin.table("subscriptions").select("inr_paise")
            .eq("status", "active").execute()
        )
        revenue_active_inr = sum((r.get("inr_paise") or 0) for r in (subs_res.data or [])) // 100
    except Exception:
        revenue_active_inr = 0

    # Gift volume (all-time delivered gifts × their cost)
    try:
        gs = (
            supabase_admin.table("gift_sends").select("cost")
            .eq("status", "delivered").execute()
        )
        gift_volume_credits = sum((r.get("cost") or 0) for r in (gs.data or []))
    except Exception:
        gift_volume_credits = 0

    return {
        "total_users":           total_users,
        "signups_today":         signups_today,
        "signups_week":          signups_week,
        "paid_users":            active_subs,
        "pending_verifications": pending_verifications,
        "pending_withdrawals":   pending_withdrawals,
        "revenue_active_inr":    revenue_active_inr,
        "gift_volume_credits":   gift_volume_credits,
    }


def get_signup_series(days: int = 14) -> list[dict]:
    """Daily signup counts for the trend sparkline."""
    if days < 1:
        days = 1
    if days > 60:
        days = 60

    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    try:
        res = (
            supabase_admin.table("users").select("created_at")
            .gte("created_at", since)
            .order("created_at")
            .execute()
        )
    except Exception:
        return []

    buckets: dict[str, int] = {}
    for row in res.data or []:
        day = (row["created_at"] or "")[:10]
        if day:
            buckets[day] = buckets.get(day, 0) + 1

    # Fill missing days with zeros so the chart is contiguous.
    series = []
    today = datetime.now(timezone.utc).date()
    for i in range(days - 1, -1, -1):
        d = (today - timedelta(days=i)).isoformat()
        series.append({"date": d, "count": buckets.get(d, 0)})
    return series


# ── Users ────────────────────────────────────────────────────────
def list_users(
    limit: int = 50,
    offset: int = 0,
    scope: str = "all",          # all | paid | free | admins
    q: Optional[str] = None,     # free-text over email/name
) -> dict:
    """Paginated user list with the bits the dashboard actually renders.

    Joins in the profile snapshot and active subscription tier so the
    table can show "Pro · 3 months" without a follow-up call.
    """
    query = (
        supabase_admin.table("users")
        .select(
            "id, name, email, phone_number, is_active, is_admin, created_at, "
            # Disambiguate: profiles has two FKs back to users (id + verification_reviewed_by).
            # We want the profile owned BY this user, which is the `profiles.id → users.id` FK.
            "profiles!profiles_id_fkey(id, gender, age, city, is_complete, is_verified, verification_status, main_image_url, is_banned, ban_reason, ban_expires_at)",
            count="exact",
        )
        .order("created_at", desc=True)
    )
    if q:
        # Supabase/PG ilike OR across email + name
        ql = q.replace(",", " ").strip()
        if ql:
            query = query.or_(f"email.ilike.%{ql}%,name.ilike.%{ql}%")
    if scope == "admins":
        query = query.eq("is_admin", True)

    res = query.range(offset, offset + limit - 1).execute()
    rows = res.data or []
    total = res.count or 0

    # Enrich with active subscription tier
    if rows:
        ids = [r["id"] for r in rows]
        try:
            subs = (
                supabase_admin.table("subscriptions").select("user_id, plan, status, expires_at")
                .in_("user_id", ids).eq("status", "active").execute()
            )
            subs_map = {s["user_id"]: s for s in (subs.data or [])}
        except Exception:
            subs_map = {}

        try:
            wallets = (
                supabase_admin.table("wallets").select("user_id, balance")
                .in_("user_id", ids).execute()
            )
            wallet_map = {w["user_id"]: w["balance"] for w in (wallets.data or [])}
        except Exception:
            wallet_map = {}

        for r in rows:
            s = subs_map.get(r["id"])
            r["active_sub"] = (
                {"plan": s["plan"], "tier": subs_service.tier_of(s["plan"]), "expires_at": s["expires_at"]}
                if s else None
            )
            r["credit_balance"] = wallet_map.get(r["id"], 0)

    # Post-filter for paid/free (cheaper than a subquery on a small page)
    if scope == "paid":
        rows = [r for r in rows if r.get("active_sub")]
    elif scope == "free":
        rows = [r for r in rows if not r.get("active_sub")]

    return {"rows": rows, "total": total, "limit": limit, "offset": offset, "scope": scope}


def set_user_active(admin_id: str, user_id: str, active: bool) -> dict:
    supabase_admin.table("users").update({"is_active": active}).eq("id", user_id).execute()
    _audit(admin_id, "user.enable" if active else "user.disable", "user", user_id)
    return {"user_id": user_id, "is_active": active}


def set_user_admin(admin_id: str, user_id: str, is_admin: bool) -> dict:
    if admin_id == user_id and not is_admin:
        raise HTTPException(400, "You can't remove your own admin access")
    supabase_admin.table("users").update({"is_admin": is_admin}).eq("id", user_id).execute()
    _audit(admin_id, "user.grant_admin" if is_admin else "user.revoke_admin", "user", user_id)
    return {"user_id": user_id, "is_admin": is_admin}


# ── Verification queue ───────────────────────────────────────────
def list_verifications(status: str = "pending", limit: int = 50) -> list[dict]:
    """Returns pending/approved/rejected verification rows with the
    profile pic + selfie URLs so the reviewer can eyeball them side by side.
    """
    if status not in ("pending", "approved", "rejected", "all"):
        raise HTTPException(400, "status must be pending | approved | rejected | all")

    query = (
        supabase_admin.table("profiles")
        .select(
            "id, name, age, gender, city, verification_status, verification_submitted_at, "
            "verification_reviewed_at, verification_note, "
            "verification_image_url, main_image_url, cover_image_url, is_verified"
        )
        .order("verification_submitted_at", desc=True, nullsfirst=False)
        .limit(limit)
    )
    if status != "all":
        query = query.eq("verification_status", status)

    res = query.execute()
    rows = res.data or []

    # Pull user email so reviewers can correlate (and contact on reject).
    if rows:
        ids = [r["id"] for r in rows]
        try:
            users = (
                supabase_admin.table("users").select("id, email, name")
                .in_("id", ids).execute()
            )
            email_map = {u["id"]: u for u in (users.data or [])}
        except Exception:
            email_map = {}
        for r in rows:
            u = email_map.get(r["id"]) or {}
            r["email"] = u.get("email")

    return rows


def _update_verification(
    admin_id: str,
    user_id: str,
    status: str,
    note: Optional[str] = None,
) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    updates = {
        "verification_status":       status,
        "verification_reviewed_at":  now,
        "verification_reviewed_by":  admin_id,
        "verification_note":         note,
        # is_verified stays true only for approved rows
        "is_verified":               status == "approved",
    }
    res = supabase_admin.table("profiles").update(updates).eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(404, "Profile not found")
    _audit(admin_id, f"verification.{status}", "profile", user_id, {"note": note})
    return res.data[0]


def approve_verification(admin_id: str, user_id: str) -> dict:
    row = _update_verification(admin_id, user_id, "approved")
    # Once approved, the user is eligible for the signup bonus (fires at
    # most once per account — guarded inside the wallet service).
    try:
        wallet_service.grant_signup_bonus_if_eligible(user_id)
    except Exception:
        # Don't block the approval if the bonus write fails.
        pass
    return row


def reject_verification(admin_id: str, user_id: str, note: str) -> dict:
    if not note or not note.strip():
        raise HTTPException(400, "Rejection requires a reason the user can act on")
    return _update_verification(admin_id, user_id, "rejected", note.strip())


# ── Gift catalog ─────────────────────────────────────────────────
def list_gifts_admin() -> list[dict]:
    """All gifts — active + retired — sorted the way they ship on mobile."""
    res = (
        supabase_admin.table("gifts").select("*")
        .order("sort_order").order("cost").execute()
    )
    return res.data or []


def update_gift(
    admin_id: str,
    gift_id: str,
    *,
    cost: Optional[int] = None,
    name: Optional[str] = None,
    icon: Optional[str] = None,
    tier: Optional[str] = None,
    is_active: Optional[bool] = None,
    sort_order: Optional[int] = None,
) -> dict:
    patch: dict[str, Any] = {}
    if cost is not None:
        if cost < 30:
            raise HTTPException(400, "Gift cost must be at least 30 credits (product rule)")
        patch["cost"] = cost
    if name is not None:
        patch["name"] = name.strip() or None
    if icon is not None:
        patch["icon"] = icon.strip() or None
    if tier is not None:
        if tier not in ("common", "rare", "epic", "legendary"):
            raise HTTPException(400, "tier must be common | rare | epic | legendary")
        patch["tier"] = tier
    if is_active is not None:
        patch["is_active"] = is_active
    if sort_order is not None:
        patch["sort_order"] = sort_order

    if not patch:
        raise HTTPException(400, "Nothing to update")

    res = supabase_admin.table("gifts").update(patch).eq("id", gift_id).execute()
    if not res.data:
        raise HTTPException(404, "Gift not found")
    _audit(admin_id, "gift.update", "gift", gift_id, patch)
    return res.data[0]


# ── Subscription plan prices ─────────────────────────────────────
def list_plans_admin() -> list[dict]:
    """Merge the code catalogue with any DB overrides so the admin sees
    the live price the user would actually be charged.
    """
    try:
        overrides = supabase_admin.table("plan_overrides").select("*").execute().data or []
    except Exception:
        overrides = []
    override_map = {o["slug"]: o for o in overrides}

    plans = []
    for p in subs_service.PLANS:
        o = override_map.get(p["slug"])
        eff_monthly = o["monthly_inr"] if o else p["monthly_inr"]
        plans.append({
            **p,
            "monthly_inr":         eff_monthly,
            "total_inr":           eff_monthly * p["months"],
            "default_monthly_inr": p["monthly_inr"],
            "is_overridden":       o is not None,
            "updated_at":          (o or {}).get("updated_at"),
        })
    return plans


def update_plan_price(admin_id: str, slug: str, monthly_inr: int) -> dict:
    """Write an override row. Pass monthly_inr ≤ 0 to clear the override
    (reverts to the code default).
    """
    if not any(p["slug"] == slug for p in subs_service.PLANS):
        raise HTTPException(404, f"Unknown plan slug: {slug}")

    if monthly_inr <= 0:
        try:
            supabase_admin.table("plan_overrides").delete().eq("slug", slug).execute()
        except Exception:
            pass
        _audit(admin_id, "plan.reset_price", "plan", slug)
        return {"slug": slug, "reset": True}

    row = {
        "slug":         slug,
        "monthly_inr":  monthly_inr,
        "updated_by":   admin_id,
        "updated_at":   datetime.now(timezone.utc).isoformat(),
    }
    try:
        supabase_admin.table("plan_overrides").upsert(row, on_conflict="slug").execute()
    except Exception as e:
        raise HTTPException(500, "Failed to update plan price. Did the 2026_admin migration run?") from e

    _audit(admin_id, "plan.update_price", "plan", slug, {"monthly_inr": monthly_inr})
    return {"slug": slug, "monthly_inr": monthly_inr}


# ── Withdrawals ──────────────────────────────────────────────────
def list_withdrawals_admin(status: Optional[str] = None, limit: int = 50) -> list[dict]:
    query = (
        supabase_admin.table("withdrawal_requests").select("*")
        .order("created_at", desc=True).limit(limit)
    )
    if status:
        query = query.eq("status", status)
    res = query.execute()
    rows = res.data or []

    if rows:
        ids = list({r["user_id"] for r in rows})
        try:
            users = (
                supabase_admin.table("users").select("id, email, name")
                .in_("id", ids).execute()
            )
            u_map = {u["id"]: u for u in (users.data or [])}
        except Exception:
            u_map = {}
        try:
            payouts = (
                supabase_admin.table("payout_details")
                .select("user_id, method, upi_id, account_name, account_number, ifsc")
                .in_("user_id", ids).execute()
            )
            p_map = {p["user_id"]: p for p in (payouts.data or [])}
        except Exception:
            p_map = {}
        for r in rows:
            u = u_map.get(r["user_id"]) or {}
            r["user"]   = {"email": u.get("email"), "name": u.get("name")}
            r["payout"] = p_map.get(r["user_id"])
    return rows


def mark_withdrawal(
    admin_id: str,
    withdrawal_id: str,
    new_status: str,           # processing | paid | rejected
    rzp_payout_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> dict:
    if new_status not in ("processing", "paid", "rejected"):
        raise HTTPException(400, "status must be processing | paid | rejected")

    res = (
        supabase_admin.table("withdrawal_requests").select("*")
        .eq("id", withdrawal_id).limit(1).execute()
    )
    if not res.data:
        raise HTTPException(404, "Withdrawal not found")
    wr = res.data[0]
    if wr["status"] in ("paid", "rejected", "cancelled"):
        raise HTTPException(400, f"Withdrawal already {wr['status']}")

    updates: dict[str, Any] = {"status": new_status}
    if new_status in ("paid", "rejected"):
        updates["processed_at"] = datetime.now(timezone.utc).isoformat()
    if rzp_payout_id:
        updates["rzp_payout_id"] = rzp_payout_id
    if new_status == "rejected":
        updates["failure_reason"] = reason or "Rejected by admin"

    supabase_admin.table("withdrawal_requests").update(updates).eq("id", withdrawal_id).execute()

    # Refund held credits if rejected.
    if new_status == "rejected":
        wallet_service._apply_delta(  # noqa: SLF001 — admin-initiated correction
            wr["user_id"], wr["credits"], "withdrawal_refund",
            ref_id=wr["id"],
            meta={"via": "admin_reject", "reason": updates["failure_reason"]},
        )

    _audit(admin_id, f"withdrawal.{new_status}", "withdrawal", withdrawal_id, {
        "rzp_payout_id": rzp_payout_id, "reason": reason,
    })
    return {**wr, **updates}


# ── App settings ─────────────────────────────────────────────────
def list_settings() -> list[dict]:
    try:
        res = supabase_admin.table("app_settings").select("*").order("key").execute()
        return res.data or []
    except Exception:
        return []


def update_setting(admin_id: str, key: str, value: Any) -> dict:
    row = {
        "key":        key,
        "value":      value,
        "updated_by": admin_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        res = supabase_admin.table("app_settings").upsert(row, on_conflict="key").execute()
    except Exception as e:
        raise HTTPException(500, "Failed to save setting. Did the 2026_admin migration run?") from e

    _audit(admin_id, "settings.update", "settings", key, {"value": value})
    return (res.data or [row])[0]


# ── Credit adjustments (manual) ──────────────────────────────────
def adjust_credits(admin_id: str, user_id: str, delta: int, reason: str) -> dict:
    if delta == 0:
        raise HTTPException(400, "Delta must be non-zero")
    if not reason or not reason.strip():
        raise HTTPException(400, "Reason is required for credit adjustments")

    # _apply_delta raises 402 if the resulting balance would go negative.
    snapshot = wallet_service._apply_delta(  # noqa: SLF001
        user_id, delta, "admin_adjust",
        ref_id=None,
        meta={"reason": reason.strip(), "admin_id": admin_id},
    )
    _audit(admin_id, "credits.adjust", "user", user_id, {"delta": delta, "reason": reason.strip()})
    return snapshot


# ── Audit log (read) ─────────────────────────────────────────────
def list_audit_log(limit: int = 100) -> list[dict]:
    try:
        res = (
            supabase_admin.table("admin_audit_log").select("*")
            .order("created_at", desc=True).limit(limit).execute()
        )
        rows = res.data or []
    except Exception:
        return []

    if rows:
        ids = list({r["admin_id"] for r in rows if r.get("admin_id")})
        try:
            users = supabase_admin.table("users").select("id, email, name").in_("id", ids).execute()
            u_map = {u["id"]: u for u in (users.data or [])}
        except Exception:
            u_map = {}
        for r in rows:
            u = u_map.get(r.get("admin_id")) or {}
            r["admin"] = {"email": u.get("email"), "name": u.get("name")}
    return rows


# ── User detail (admin drill-down) ───────────────────────────────
def _safe_count(table: str, **filters) -> int:
    try:
        q = supabase_admin.table(table).select("id", count="exact")
        for k, v in filters.items():
            q = q.eq(k, v)
        res = q.execute()
        return res.count or 0
    except Exception:
        return 0


def get_user_detail(user_id: str) -> dict:
    """Everything the admin needs to know about one user, in a single
    round-trip. Pulls from ~10 tables — each query is a cheap PK/FK
    lookup so the round-trips stay manageable.

    Sections:
      • account      — users + profile basics + verification state
      • photos       — all profile_images rows + cover + selfie
      • activity     — likes/passes sent & received, matches, messages
      • payments     — subscription history, credit purchases, failures
      • wallet       — balance, lifetime earn/spend, transactions
      • gifts        — sent, received, pending
      • events       — last 50 user_events + aggregate counts
    """
    # Account ---------------------------------------------------------
    user_res = (
        supabase_admin.table("users").select("*")
        .eq("id", user_id).limit(1).execute()
    )
    if not user_res.data:
        return {}
    user = user_res.data[0]
    user.pop("password_hash", None)

    profile_res = (
        supabase_admin.table("profiles")
        .select("*").eq("id", user_id).limit(1).execute()
    )
    profile = profile_res.data[0] if profile_res.data else None

    # Photos ----------------------------------------------------------
    try:
        imgs = (
            supabase_admin.table("profile_images").select("*")
            .eq("user_id", user_id).order("order_index").execute()
        )
        photos = imgs.data or []
    except Exception:
        photos = []

    # Activity --------------------------------------------------------
    likes_sent    = _safe_count("match_interactions", actor_id=user_id,  action="like")
    passes_sent   = _safe_count("match_interactions", actor_id=user_id,  action="pass")
    likes_recv    = _safe_count("match_interactions", target_id=user_id, action="like")
    passes_recv   = _safe_count("match_interactions", target_id=user_id, action="pass")

    try:
        matches_count = (
            supabase_admin.table("matches").select("id", count="exact")
            .or_(f"user1_id.eq.{user_id},user2_id.eq.{user_id}").execute()
        )
        matches_total = matches_count.count or 0
    except Exception:
        matches_total = 0

    messages_sent = _safe_count("messages", sender_id=user_id)

    try:
        conv_res = (
            supabase_admin.table("messages").select("match_id")
            .eq("sender_id", user_id).execute()
        )
        conversations = len({m["match_id"] for m in (conv_res.data or []) if m.get("match_id")})
    except Exception:
        conversations = 0

    # Payments --------------------------------------------------------
    try:
        subs = (
            supabase_admin.table("subscriptions").select("*")
            .eq("user_id", user_id).order("created_at", desc=True).limit(25).execute()
        )
        subscriptions = subs.data or []
    except Exception:
        subscriptions = []
    lifetime_sub_inr = sum((s.get("inr_paise") or 0) for s in subscriptions) // 100

    try:
        purchases_res = (
            supabase_admin.table("credit_transactions").select("*")
            .eq("user_id", user_id).eq("kind", "purchase")
            .order("created_at", desc=True).limit(25).execute()
        )
        credit_purchases = purchases_res.data or []
    except Exception:
        credit_purchases = []
    lifetime_credit_inr = sum(
        (p.get("meta") or {}).get("inr_paise", 0) for p in credit_purchases
    ) // 100

    # Wallet ----------------------------------------------------------
    try:
        w = supabase_admin.table("wallets").select("*").eq("user_id", user_id).limit(1).execute()
        wallet = w.data[0] if w.data else None
    except Exception:
        wallet = None

    try:
        txns = (
            supabase_admin.table("credit_transactions").select("*")
            .eq("user_id", user_id).order("created_at", desc=True).limit(30).execute()
        )
        transactions = txns.data or []
    except Exception:
        transactions = []

    # Gifts -----------------------------------------------------------
    gifts_sent_count     = _safe_count("gift_sends", sender_id=user_id)
    gifts_received_count = _safe_count("gift_sends", receiver_id=user_id)

    # Events (telemetry) ---------------------------------------------
    event_counts        = events_service.counts_for_user(user_id)
    event_counts_7d     = events_service.counts_since(user_id, days=7)
    recent_events       = events_service.recent_for_user(user_id, limit=60)

    # Withdrawals -----------------------------------------------------
    try:
        wds = (
            supabase_admin.table("withdrawal_requests").select("*")
            .eq("user_id", user_id).order("created_at", desc=True).limit(10).execute()
        )
        withdrawals = wds.data or []
    except Exception:
        withdrawals = []

    return {
        "account": {
            **user,
            "profile": profile,
        },
        "photos": photos,
        "activity": {
            "likes_sent":      likes_sent,
            "passes_sent":     passes_sent,
            "likes_received":  likes_recv,
            "passes_received": passes_recv,
            "matches":         matches_total,
            "messages_sent":   messages_sent,
            "conversations":   conversations,
            # Derived from the events log — only populated once telemetry
            # migration has been running for a while. `.get` keeps the UI
            # safe on fresh installs.
            "profile_views_by_user":   event_counts.get("profile_viewed", 0),
        },
        "payments": {
            "subscriptions":        subscriptions,
            "lifetime_sub_inr":     lifetime_sub_inr,
            "credit_purchases":     credit_purchases,
            "lifetime_credit_inr":  lifetime_credit_inr,
            "lifetime_spend_inr":   lifetime_sub_inr + lifetime_credit_inr,
            "payment_attempts":     event_counts.get("payment_started", 0),
            "payment_successes":    event_counts.get("payment_success", 0),
            "payment_failures":     event_counts.get("payment_failed", 0),
            "plans_page_visits":    event_counts.get("plans_viewed", 0),
            "credits_page_visits":  event_counts.get("credits_viewed", 0),
            "paywalls_shown":       event_counts.get("paywall_shown", 0),
        },
        "wallet": {
            "wallet":       wallet,
            "transactions": transactions,
            "gifts_sent":     gifts_sent_count,
            "gifts_received": gifts_received_count,
            "withdrawals":    withdrawals,
        },
        "events": {
            "totals":    event_counts,
            "last_7d":   event_counts_7d,
            "recent":    recent_events,
        },
    }
