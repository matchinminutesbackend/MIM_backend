"""
Notifications service.

Notifications are lightweight per-user records of things that happened that
the UI should surface in a top-bar bell. Types we emit today:

- `match_invitation`  — someone wants to reconnect after an unfriend
- `match_restored`    — the invitation you sent was accepted
- `match_created`     — you mutually matched (net-new)
- `new_message`       — a new chat message while the window wasn't focused
- `invitation_declined` — optional, for a small "X passed" ping

Required SQL migration:

    create table if not exists notifications (
        id          uuid primary key default gen_random_uuid(),
        user_id     uuid not null,
        type        text not null,
        actor_id    uuid,
        match_id    uuid,
        payload     jsonb default '{}'::jsonb,
        is_read     boolean default false,
        is_handled  boolean default false,
        created_at  timestamptz default now()
    );
    create index if not exists idx_notifications_user
        on notifications (user_id, created_at desc);
    create index if not exists idx_notifications_unread
        on notifications (user_id, is_read)
        where is_read = false;
"""

from __future__ import annotations

from typing import Optional

from app.supabase_client import supabase_admin


def create(
    user_id: str,
    type_: str,
    *,
    actor_id: Optional[str] = None,
    match_id: Optional[str] = None,
    payload: Optional[dict] = None,
) -> dict | None:
    """Insert a notification for `user_id`. Returns the created row or None on failure.

    Never raises — notifications are best-effort; the calling feature must still
    succeed if the notification write fails (e.g. table missing).
    """
    try:
        res = supabase_admin.table("notifications").insert({
            "user_id": user_id,
            "type": type_,
            "actor_id": actor_id,
            "match_id": match_id,
            "payload": payload or {},
        }).execute()
        return res.data[0] if res.data else None
    except Exception:
        return None


def list_for_user(user_id: str, limit: int = 50) -> list:
    """Recent notifications with actor profile joined so the UI can render avatars/names."""
    try:
        res = (
            supabase_admin.table("notifications")
            .select("*, actor:profiles!actor_id(id, name, main_image_url)")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data or []
    except Exception:
        return []


def unread_count(user_id: str) -> int:
    try:
        res = (
            supabase_admin.table("notifications")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("is_read", False)
            .execute()
        )
        return res.count or 0
    except Exception:
        return 0


def mark_read(user_id: str, notification_id: str) -> bool:
    try:
        supabase_admin.table("notifications").update({"is_read": True}).eq(
            "id", notification_id
        ).eq("user_id", user_id).execute()
        return True
    except Exception:
        return False


def mark_all_read(user_id: str) -> bool:
    try:
        supabase_admin.table("notifications").update({"is_read": True}).eq(
            "user_id", user_id
        ).eq("is_read", False).execute()
        return True
    except Exception:
        return False


def mark_handled(user_id: str, notification_id: str) -> bool:
    """Flag an actionable notification (e.g. an invitation) as resolved so the
    UI can stop showing Accept/Decline buttons without removing the row."""
    try:
        supabase_admin.table("notifications").update({
            "is_read": True,
            "is_handled": True,
        }).eq("id", notification_id).eq("user_id", user_id).execute()
        return True
    except Exception:
        return False


def create_profile_view(viewer_id: str, target_id: str) -> Optional[dict]:
    """Insert a profile_view notification, deduplicated per viewer per 24 hours."""
    from datetime import datetime, timezone, timedelta
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
        existing = (
            supabase_admin.table("notifications")
            .select("id")
            .eq("user_id", target_id)
            .eq("type", "profile_view")
            .eq("actor_id", viewer_id)
            .gte("created_at", cutoff)
            .limit(1)
            .execute()
        )
        if existing.data:
            return None
        return create(target_id, "profile_view", actor_id=viewer_id)
    except Exception:
        return None


def get(user_id: str, notification_id: str) -> Optional[dict]:
    try:
        res = (
            supabase_admin.table("notifications")
            .select("*")
            .eq("id", notification_id)
            .eq("user_id", user_id)
            .execute()
        )
        return res.data[0] if res.data else None
    except Exception:
        return None
