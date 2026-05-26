"""User event telemetry.

Append-only log. The write path is intentionally permissive — if the
table is missing or a write fails, we swallow the exception because
telemetry must never block a user action.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from app.supabase_client import supabase_admin


# Allowed event names. Keeping this as an allow-list stops a buggy
# client from spraying arbitrary strings into the table.
ALLOWED_EVENTS = {
    "page_view",
    "paywall_shown",
    "plans_viewed",
    "credits_viewed",
    "payment_started",
    "payment_success",
    "payment_failed",
    "profile_viewed",
    "profile_liked",
    "profile_passed",
    "message_sent",
    "call_started",
    "call_blocked",
    "gift_sent",
}


def log(
    user_id: Optional[str],
    event: str,
    target_id: Optional[str] = None,
    meta: Optional[dict] = None,
) -> None:
    """Best-effort insert. Silently drops unknown event names."""
    if event not in ALLOWED_EVENTS:
        return
    try:
        supabase_admin.table("user_events").insert({
            "user_id":   user_id,
            "event":     event,
            "target_id": str(target_id) if target_id is not None else None,
            "meta":      meta or {},
        }).execute()
    except Exception:
        # Table might not exist yet — ignore, never break the caller.
        pass


def recent_for_user(user_id: str, limit: int = 100) -> list[dict]:
    try:
        res = (
            supabase_admin.table("user_events").select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data or []
    except Exception:
        return []


def counts_for_user(user_id: str) -> dict[str, int]:
    """Returns a {event_name → count} dict for this user. Single table
    scan filtered by the user_id index — cheap per user, so we don't
    bother with a materialised summary.
    """
    try:
        res = (
            supabase_admin.table("user_events").select("event")
            .eq("user_id", user_id).execute()
        )
    except Exception:
        return {}
    counts: dict[str, int] = {}
    for row in res.data or []:
        e = row.get("event")
        if not e:
            continue
        counts[e] = counts.get(e, 0) + 1
    return counts


def counts_since(user_id: str, days: int) -> dict[str, int]:
    """Same as counts_for_user but windowed. Useful for `last 7 days`
    breakdowns on the admin detail page.
    """
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    try:
        res = (
            supabase_admin.table("user_events").select("event")
            .eq("user_id", user_id)
            .gte("created_at", since)
            .execute()
        )
    except Exception:
        return {}
    counts: dict[str, int] = {}
    for row in res.data or []:
        e = row.get("event")
        if not e:
            continue
        counts[e] = counts.get(e, 0) + 1
    return counts
