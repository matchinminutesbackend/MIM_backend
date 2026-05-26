"""Premium subscription + free-tier quota service.

Two tiers, one module:

1. **Plus** — unlimited hearts + passes.
2. **Pro**  — everything Plus has, plus unlimited voice & video calls.

Each tier ships with three commitment lengths (1 / 3 / 6 months) and per-
month prices that get cheaper the longer you commit. Six SKUs total.

Legacy note: we originally shipped a single premium tier with plan slugs
``monthly`` / ``quarterly`` / ``halfyearly``. Those rows are grandfathered
as **Plus** (so existing subscribers keep unlimited swiping, but need to
upgrade if they want the new calling features). ``tier_of`` encapsulates
that mapping — keep using it everywhere instead of string-comparing slugs.

Women (profiles.gender = 'female') are unlimited & free at both layers —
we short-circuit the gender check first so we never touch quota rows for
them.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone, date
from typing import Optional

from fastapi import HTTPException

from app.supabase_client import supabase_admin
from app.wallet import razorpay_client as rzp
from app.wallet import service as wallet_service  # for billing lookup

# ── Plan catalogue ───────────────────────────────────────────────
# Monthly price is what the user sees in the UI. `months × monthly_inr`
# is what Razorpay actually charges upfront. `tier` splits the ladder:
#   - "plus" → unlimited hearts/passes
#   - "pro"  → plus calls on top
# Features list is declarative so the frontend can render bullet points
# without hard-coding them.

PLANS = [
    # ── Plus tier (unlimited hearts/passes) ──
    {
        "slug":        "plus_monthly",
        "tier":        "plus",
        "months":      1,
        "monthly_inr": 199,
        "total_inr":   199,
        "label":       "Plus · 1 Month",
        "features":    ["unlimited_hearts", "unlimited_passes"],
    },
    {
        "slug":        "plus_quarterly",
        "tier":        "plus",
        "months":      3,
        "monthly_inr": 179,
        "total_inr":   179 * 3,   # ₹537
        "label":       "Plus · 3 Months",
        "features":    ["unlimited_hearts", "unlimited_passes"],
    },
    {
        "slug":        "plus_halfyearly",
        "tier":        "plus",
        "months":      6,
        "monthly_inr": 149,
        "total_inr":   149 * 6,   # ₹894
        "label":       "Plus · 6 Months",
        "features":    ["unlimited_hearts", "unlimited_passes"],
    },
    # ── Pro tier (Plus + voice & video calls) ──
    {
        "slug":        "pro_monthly",
        "tier":        "pro",
        "months":      1,
        "monthly_inr": 399,
        "total_inr":   399,
        "label":       "Pro · 1 Month",
        "features":    ["unlimited_hearts", "unlimited_passes", "voice_calls", "video_calls"],
    },
    {
        "slug":        "pro_quarterly",
        "tier":        "pro",
        "months":      3,
        "monthly_inr": 349,
        "total_inr":   349 * 3,   # ₹1,047
        "label":       "Pro · 3 Months",
        "features":    ["unlimited_hearts", "unlimited_passes", "voice_calls", "video_calls"],
    },
    {
        "slug":        "pro_halfyearly",
        "tier":        "pro",
        "months":      6,
        "monthly_inr": 299,
        "total_inr":   299 * 6,   # ₹1,794
        "label":       "Pro · 6 Months",
        "features":    ["unlimited_hearts", "unlimited_passes", "voice_calls", "video_calls"],
    },
]

# Legacy plan slugs from the single-tier era. Map them to Plus so rows
# inserted before this migration keep their benefits.
_LEGACY_PLUS_SLUGS = {"monthly", "quarterly", "halfyearly"}


def tier_of(plan_slug: Optional[str]) -> Optional[str]:
    """Return 'plus' | 'pro' | None for a plan slug. Grandfathers legacy
    single-tier slugs as Plus so existing subscribers keep their access.
    """
    if not plan_slug:
        return None
    if plan_slug in _LEGACY_PLUS_SLUGS:
        return "plus"
    p = next((x for x in PLANS if x["slug"] == plan_slug), None)
    return p["tier"] if p else None


# Quotas: only men get gated. Change these and the frontend copy will
# update automatically via /subscriptions/me.
FREE_HEARTS_PER_DAY = 10
FREE_PASSES_PER_DAY = 30

# IST is hard-coded — the app targets Indian users and Razorpay invoices
# are IST anyway. "Daily reset" meaning "midnight local time" is the
# cleanest promise to make in the UI.
_IST = timezone(timedelta(hours=5, minutes=30))


def _load_overrides() -> dict[str, int]:
    """Pull admin-set monthly_inr overrides. Returns {} if the table is
    missing (migration not yet run) so behavior falls back to code defaults.
    """
    try:
        res = supabase_admin.table("plan_overrides").select("slug, monthly_inr").execute()
        return {r["slug"]: r["monthly_inr"] for r in (res.data or [])}
    except Exception:
        return {}


def _effective_plans() -> list[dict]:
    """PLANS with any admin overrides applied to monthly_inr + total_inr."""
    overrides = _load_overrides()
    out = []
    for p in PLANS:
        if p["slug"] in overrides:
            monthly = overrides[p["slug"]]
            out.append({**p, "monthly_inr": monthly, "total_inr": monthly * p["months"]})
        else:
            out.append(p)
    return out


def _plan(slug: str) -> dict:
    # Always resolve against the override-adjusted catalogue so the price
    # the user is charged matches what the dashboard shows.
    p = next((x for x in _effective_plans() if x["slug"] == slug), None)
    if not p:
        raise HTTPException(400, f"Unknown plan: {slug}")
    return p


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _today_ist() -> date:
    return datetime.now(_IST).date()


# ── Gender / premium checks ──────────────────────────────────────
def _get_gender(user_id: str) -> Optional[str]:
    """Returns 'male' / 'female' / None (profile missing). Cached is not
    worth it — this is a single indexed PK lookup per gated call.
    """
    res = (
        supabase_admin.table("profiles")
        .select("gender").eq("id", user_id).execute()
    )
    if res.data:
        return (res.data[0].get("gender") or "").lower() or None
    return None


def is_female(user_id: str) -> bool:
    return _get_gender(user_id) == "female"


def get_active_subscription(user_id: str) -> Optional[dict]:
    """Returns the user's live subscription row, or None. Also flips stale
    `active` rows to `expired` lazily so status stays honest without a cron.
    """
    try:
        res = (
            supabase_admin.table("subscriptions")
            .select("*").eq("user_id", user_id).eq("status", "active")
            .order("expires_at", desc=True).limit(1).execute()
        )
    except Exception:
        # Table may not exist yet — migration not run.
        return None
    if not res.data:
        return None
    sub = res.data[0]
    if sub["expires_at"] < _now_iso():
        # Expired while sitting in the table — mark it and return None.
        try:
            supabase_admin.table("subscriptions").update(
                {"status": "expired"}
            ).eq("id", sub["id"]).execute()
        except Exception:
            pass
        return None
    return sub


def get_active_tier(user_id: str) -> Optional[str]:
    """Return 'plus' | 'pro' | None based on the user's live subscription."""
    sub = get_active_subscription(user_id)
    if not sub:
        return None
    return tier_of(sub.get("plan"))


def has_plus(user_id: str) -> bool:
    """True if any paid tier is active (Plus OR Pro). Both tiers include
    unlimited hearts/passes — use this wherever you used to call
    ``is_premium``.
    """
    return get_active_tier(user_id) in ("plus", "pro")


def has_pro(user_id: str) -> bool:
    """True only for the Pro tier. Calls are gated on this."""
    return get_active_tier(user_id) == "pro"


# Back-compat alias — older call sites use is_premium. Prefer has_plus /
# has_pro in new code so the intent is unambiguous.
def is_premium(user_id: str) -> bool:
    return has_plus(user_id)


# ── Daily quota ──────────────────────────────────────────────────
def _get_or_create_quota_row(user_id: str) -> dict:
    today = _today_ist().isoformat()
    try:
        res = (
            supabase_admin.table("daily_quota").select("*")
            .eq("user_id", user_id).eq("quota_date", today).execute()
        )
    except Exception:
        # Table missing — behave as if quota is unlimited so the app
        # doesn't break before migration is run.
        return {"user_id": user_id, "quota_date": today,
                "hearts_used": 0, "passes_used": 0}
    if res.data:
        return res.data[0]
    row = {"user_id": user_id, "quota_date": today,
           "hearts_used": 0, "passes_used": 0}
    try:
        supabase_admin.table("daily_quota").insert(row).execute()
    except Exception:
        pass
    return row


def get_quota_status(user_id: str) -> dict:
    """Return the snapshot the frontend needs to render the quota chip.
    Premium / female users get an unlimited marker so the chip can hide.
    """
    if is_female(user_id):
        return {"gated": False, "reason": "female",
                "hearts_used": 0, "passes_used": 0,
                "hearts_limit": None, "passes_limit": None}
    if has_plus(user_id):
        return {"gated": False, "reason": "premium",
                "hearts_used": 0, "passes_used": 0,
                "hearts_limit": None, "passes_limit": None}
    row = _get_or_create_quota_row(user_id)
    return {
        "gated":        True,
        "reason":       "free",
        "hearts_used":  row["hearts_used"],
        "passes_used":  row["passes_used"],
        "hearts_limit": FREE_HEARTS_PER_DAY,
        "passes_limit": FREE_PASSES_PER_DAY,
    }


def _raise_quota_exceeded(kind: str) -> None:
    """Throws a structured 402 the frontend recognises and uses to open
    the paywall. We stuff plans into detail so one round-trip is enough.
    We surface only the Plus plans on hearts/passes paywall — Pro is
    overkill for someone hitting the swipe limit; they can upsell later.
    """
    plus_plans = [p for p in _effective_plans() if p["tier"] == "plus"]
    raise HTTPException(
        status_code=402,
        detail={
            "code":   "quota_exceeded",
            "kind":   kind,  # 'heart' | 'pass'
            "message": (
                "You've used today's free hearts. Upgrade to Plus for unlimited likes."
                if kind == "heart" else
                "You've used today's free passes. Upgrade to Plus for unlimited swipes."
            ),
            "plans":       plus_plans,
            "suggest_tier": "plus",
        },
    )


def _raise_calls_locked() -> None:
    """Throws a 402 when a non-Pro user tries to start a call. We surface
    the Pro plans only — the upgrade ladder from Plus → Pro is the whole
    point of this gate.
    """
    pro_plans = [p for p in _effective_plans() if p["tier"] == "pro"]
    raise HTTPException(
        status_code=402,
        detail={
            "code":         "calls_locked",
            "message":      "Voice & video calls are a Pro feature. Upgrade to Pro to start calling your matches.",
            "plans":        pro_plans,
            "suggest_tier": "pro",
        },
    )


def check_can_call(user_id: str) -> None:
    """Gate for starting a voice/video call. Women and Pro subscribers
    pass through — everyone else hits a 402 paywall that surfaces the
    Pro plans. Free + Plus users must upgrade.
    """
    if is_female(user_id):
        return
    if has_pro(user_id):
        return
    _raise_calls_locked()


def _bump(user_id: str, field: str) -> None:
    today = _today_ist().isoformat()
    # Read-modify-write is fine here — the row is tiny and this path
    # already had a read immediately above to check the limit.
    row = _get_or_create_quota_row(user_id)
    try:
        supabase_admin.table("daily_quota").update({
            field: row[field] + 1,
            "updated_at": _now_iso(),
        }).eq("user_id", user_id).eq("quota_date", today).execute()
    except Exception:
        # Don't block the action if the counter write fails — the user's
        # action (like / pass) already succeeded. Log-and-swallow.
        pass


def check_and_consume_heart(user_id: str) -> None:
    if is_female(user_id) or has_plus(user_id):
        return
    row = _get_or_create_quota_row(user_id)
    if row["hearts_used"] >= FREE_HEARTS_PER_DAY:
        _raise_quota_exceeded("heart")
    _bump(user_id, "hearts_used")


def check_and_consume_pass(user_id: str) -> None:
    if is_female(user_id) or has_plus(user_id):
        return
    row = _get_or_create_quota_row(user_id)
    if row["passes_used"] >= FREE_PASSES_PER_DAY:
        _raise_quota_exceeded("pass")
    _bump(user_id, "passes_used")


# ── Purchase flow ────────────────────────────────────────────────
def create_subscription_order(user_id: str, plan_slug: str) -> dict:
    """Kick off a Razorpay order for a subscription plan. Reuses the
    billing details collected for wallet purchases — same modal, same row.
    Women shouldn't hit this endpoint; we still guard in case they do.
    """
    if is_female(user_id):
        raise HTTPException(400, "Women have unlimited access for free.")

    plan = _plan(plan_slug)

    billing = wallet_service.get_billing_details(user_id)
    if not rzp.is_mock() and not billing:
        raise HTTPException(
            400,
            "Please save your billing details (name, phone, email, address) before purchasing.",
        )

    inr_paise = plan["total_inr"] * 100
    receipt = f"sub_{user_id[:8]}_{int(datetime.now().timestamp())}"

    notes = {
        "user_id": user_id,
        "plan":    plan_slug,
        "tier":    plan["tier"],
        "months":  str(plan["months"]),
    }
    if billing:
        notes.update({
            "billing_name":  billing.get("name", ""),
            "billing_email": billing.get("email", ""),
            "billing_phone": billing.get("phone", ""),
        })

    order = rzp.create_order(amount_paise=inr_paise, receipt=receipt, notes=notes)

    from app.config import settings
    return {
        "order_id":     order["id"],
        "amount_paise": order["amount"],
        "currency":     order["currency"],
        "plan":         plan_slug,
        "tier":         plan["tier"],
        "months":       plan["months"],
        "key_id":       settings.razorpay_key_id if settings.razorpay_key_id else "mock",
        "is_mock":      rzp.is_mock(),
        "prefill": (
            {"name": billing["name"], "email": billing["email"],
             "contact": billing["phone"]} if billing else None
        ),
    }


def verify_and_activate(
    user_id: str,
    order_id: str,
    payment_id: str,
    signature: str,
    plan_slug: str,
) -> dict:
    """Verify signature, insert the subscription row, return the active sub.

    Idempotency: `razorpay_order_id` is UNIQUE in the table so a retry just
    returns the already-activated row.

    Stacking rule: buying on top of a live sub extends from its expiry
    instead of now — so a Plus user who upgrades to Pro mid-cycle still
    gets the remaining Plus days credited forward (they're paying more,
    so anything else would feel punitive).
    """
    if is_female(user_id):
        raise HTTPException(400, "Women have unlimited access for free.")

    if not rzp.verify_payment_signature(order_id, payment_id, signature):
        raise HTTPException(400, "Payment signature verification failed")

    # Idempotent re-entry check.
    existing = (
        supabase_admin.table("subscriptions")
        .select("*").eq("razorpay_order_id", order_id).limit(1).execute()
    )
    if existing.data:
        return existing.data[0]

    plan = _plan(plan_slug)

    # If the user already has an active sub, extend from its expiry
    # instead of now — so buying a 1-month on top of a live sub actually
    # gives you 30 more days, not wipes your remaining time.
    live = get_active_subscription(user_id)
    start = (
        datetime.fromisoformat(live["expires_at"].replace("Z", "+00:00"))
        if live else datetime.now(timezone.utc)
    )
    # Mark the old row so we only ever have one `active` row per user.
    if live:
        supabase_admin.table("subscriptions").update(
            {"status": "expired"}  # stacked — treat as "consumed", new one carries forward
        ).eq("id", live["id"]).execute()

    expires = start + timedelta(days=30 * plan["months"])

    row = {
        "user_id":              user_id,
        "plan":                 plan_slug,
        "months":               plan["months"],
        "inr_paise":            plan["total_inr"] * 100,
        "starts_at":            start.isoformat(),
        "expires_at":           expires.isoformat(),
        "status":               "active",
        "razorpay_order_id":    order_id,
        "razorpay_payment_id":  payment_id,
    }
    res = supabase_admin.table("subscriptions").insert(row).execute()
    return res.data[0] if res.data else row
