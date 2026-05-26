"""Instant Match service.

Flow
----
1. User calls /join  → tries to pair immediately; if no partner found, enters
   'waiting' state in queue.
2. When two compatible users are both in the queue, one of them lands the
   match.  Both entries are set to 'confirming' with a 5-second window
   (confirmation_expires_at = now + 6 s).
3. During the confirmation window the frontend polls /status every ~1 s:
   - 'confirming'      → still waiting, render countdown
   - 'partner_skipped' → partner pressed Skip; this user also goes back to
                         queue (handled by the frontend calling /join again)
4. User presses "Skip"   → POST /skip    → sets partner's entry to
   'partner_skipped'; deletes own entry.  Frontend re-calls /join to search
   again.
5. User presses "Start Chat" OR 5-second timer fires on frontend →
   POST /confirm → deletes own entry; returns match_id + partner info so
   the frontend can navigate to the chat.  Quota is consumed here.
6. If the partner confirms independently their own entry is also deleted.

Quota rules
-----------
- Women (gender = 'female')  → free, unlimited
- Men with Pro subscription  → unlimited
- Free men                   → 2 uses per calendar day (IST)

Quota is consumed when a user confirms (not when they join the queue), so
skipping a match does NOT use up a free slot.
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta

from fastapi import HTTPException

from app.supabase_client import supabase_admin

FREE_LIMIT        = 2   # free confirmations per day for male non-pro users
CONFIRM_WINDOW_S  = 6   # seconds of confirmation window (1 s buffer over UI's 5 s)
STALE_MINUTES     = 10  # queue entries older than this are purged on join


# ── Feature flag ─────────────────────────────────────────────────────────────

def is_feature_enabled() -> bool:
    try:
        res = (
            supabase_admin.table("app_settings")
            .select("value")
            .eq("key", "instant_match_enabled")
            .maybe_single()
            .execute()
        )
        if res and res.data:
            return bool(res.data["value"])
    except Exception:
        pass
    return True


# ── Profile helpers ───────────────────────────────────────────────────────────

def _get_profile(user_id: str) -> dict:
    res = (
        supabase_admin.table("profiles")
        .select("id,name,gender,preferred_gender,age,city,main_image_url,is_verified,verification_status")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    if not res or not res.data:
        raise HTTPException(404, "Profile not found")
    return res.data


def _partner_summary(p: dict) -> dict:
    return {
        "id":             p["id"],
        "name":           p.get("name") or "",
        "age":            p.get("age"),
        "city":           p.get("city"),
        "main_image_url": p.get("main_image_url"),
    }


# ── Quota ─────────────────────────────────────────────────────────────────────

def _today_ist() -> str:
    ist = datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)
    return ist.date().isoformat()


def _quota_row(user_id: str) -> dict:
    today = _today_ist()
    try:
        res = (
            supabase_admin.table("daily_quota")
            .select("id,instant_match_used")
            .eq("user_id", user_id)
            .eq("quota_date", today)
            .execute()
        )
    except Exception:
        return {"id": None, "instant_match_used": 0}
    if res.data:
        return res.data[0]
    row = {"user_id": user_id, "quota_date": today,
           "hearts_used": 0, "passes_used": 0, "instant_match_used": 0}
    try:
        created = supabase_admin.table("daily_quota").insert(row).execute()
        if created.data:
            return created.data[0]
    except Exception:
        pass
    return {"id": None, "instant_match_used": 0}


def _check_quota(user_id: str) -> None:
    from app.subscriptions import service as subs
    if subs.is_female(user_id) or subs.has_pro(user_id):
        return
    row = _quota_row(user_id)
    if (row.get("instant_match_used") or 0) >= FREE_LIMIT:
        raise HTTPException(
            402,
            detail={"code": "quota_exceeded", "kind": "instant_match", "limit": FREE_LIMIT},
        )


def _consume_quota(user_id: str) -> None:
    from app.subscriptions import service as subs
    if subs.is_female(user_id) or subs.has_pro(user_id):
        return
    row   = _quota_row(user_id)
    used  = (row.get("instant_match_used") or 0) + 1
    today = _today_ist()
    if row.get("id"):
        supabase_admin.table("daily_quota").update(
            {"instant_match_used": used}
        ).eq("id", row["id"]).execute()
    else:
        try:
            supabase_admin.table("daily_quota").insert({
                "user_id": user_id, "quota_date": today,
                "hearts_used": 0, "passes_used": 0, "instant_match_used": used,
            }).execute()
        except Exception:
            pass


def get_quota_info(user_id: str) -> dict:
    from app.subscriptions import service as subs
    enabled = is_feature_enabled()
    if subs.is_female(user_id):
        return {"enabled": enabled, "unlimited": True, "reason": "female",
                "used": 0, "limit": None, "remaining": None}
    if subs.has_pro(user_id):
        return {"enabled": enabled, "unlimited": True, "reason": "pro",
                "used": 0, "limit": None, "remaining": None}
    row       = _quota_row(user_id)
    used      = row.get("instant_match_used") or 0
    remaining = max(0, FREE_LIMIT - used)
    return {"enabled": enabled, "unlimited": False, "reason": "free",
            "used": used, "limit": FREE_LIMIT, "remaining": remaining}


# ── Queue operations ──────────────────────────────────────────────────────────

def _purge_stale_entries() -> None:
    """Remove 'waiting' entries older than STALE_MINUTES (abandoned tabs)."""
    try:
        cutoff = (datetime.now(timezone.utc) - timedelta(minutes=STALE_MINUTES)).isoformat()
        supabase_admin.table("instant_match_queue").delete().eq(
            "status", "waiting"
        ).lt("joined_at", cutoff).execute()
    except Exception:
        pass


def _find_compatible_partner(user_id: str, gender: str, preferred_gender: str) -> str | None:
    try:
        res = (
            supabase_admin.table("instant_match_queue")
            .select("user_id,joined_at")
            .eq("status", "waiting")
            .neq("user_id", user_id)
            .order("joined_at", desc=False)
            .limit(30)
            .execute()
        )
    except Exception:
        return None
    for entry in (res.data or []):
        cid = entry["user_id"]
        try:
            p = (
                supabase_admin.table("profiles")
                .select("gender,preferred_gender")
                .eq("id", cid)
                .maybe_single()
                .execute()
            )
        except Exception:
            continue
        if not p or not p.data:
            continue
        c = p.data
        if c.get("gender") == preferred_gender and c.get("preferred_gender") == gender:
            return cid
    return None


def _create_match_record(user_a: str, user_b: str) -> str:
    for actor, target in [(user_a, user_b), (user_b, user_a)]:
        try:
            supabase_admin.table("match_interactions").upsert(
                {"actor_id": actor, "target_id": target, "action": "like"},
                on_conflict="actor_id,target_id",
            ).execute()
        except Exception:
            pass
    try:
        existing = (
            supabase_admin.table("matches").select("id")
            .or_(
                f"and(user1_id.eq.{user_a},user2_id.eq.{user_b}),"
                f"and(user1_id.eq.{user_b},user2_id.eq.{user_a})"
            ).execute()
        )
        if existing.data:
            return existing.data[0]["id"]
        created = supabase_admin.table("matches").insert(
            {"user1_id": user_a, "user2_id": user_b}
        ).execute()
        return created.data[0]["id"] if created.data else ""
    except Exception:
        return ""


# ── Public API ────────────────────────────────────────────────────────────────

def join_queue(user_id: str) -> dict:
    """Join queue or get immediately paired into a 'confirming' state."""
    if not is_feature_enabled():
        raise HTTPException(403, "Instant Match is currently disabled by the admin.")

    from app.matches.service import _assert_verified
    _assert_verified(user_id)

    # Check quota BEFORE joining (so the button shows the right count)
    _check_quota(user_id)

    _purge_stale_entries()

    me       = _get_profile(user_id)
    gender   = me.get("gender") or ""
    preferred = me.get("preferred_gender") or ""
    if not gender or not preferred:
        raise HTTPException(400, "Complete your profile before using Instant Match.")

    partner_id = _find_compatible_partner(user_id, gender, preferred)

    if partner_id:
        match_id    = _create_match_record(user_id, partner_id)
        expires_at  = (
            datetime.now(timezone.utc) + timedelta(seconds=CONFIRM_WINDOW_S)
        ).isoformat()

        # Both enter 'confirming' state — quota is consumed on /confirm, not here
        supabase_admin.table("instant_match_queue").upsert(
            {"user_id": user_id, "status": "confirming",
             "matched_with": partner_id, "chat_match_id": match_id,
             "confirmation_expires_at": expires_at},
            on_conflict="user_id",
        ).execute()
        supabase_admin.table("instant_match_queue").update(
            {"status": "confirming", "matched_with": user_id,
             "chat_match_id": match_id, "confirmation_expires_at": expires_at}
        ).eq("user_id", partner_id).execute()

        # Notifications
        try:
            from app.notifications import service as notif
            notif.create(partner_id, "match_created", actor_id=user_id,   match_id=match_id)
            notif.create(user_id,    "match_created", actor_id=partner_id, match_id=match_id)
        except Exception:
            pass

        partner = _get_profile(partner_id)
        return {
            "status":     "confirming",
            "match_id":   match_id,
            "expires_at": expires_at,
            "partner":    _partner_summary(partner),
        }

    # No partner yet → join waiting queue
    supabase_admin.table("instant_match_queue").upsert(
        {"user_id": user_id, "status": "waiting",
         "matched_with": None, "chat_match_id": None,
         "confirmation_expires_at": None},
        on_conflict="user_id",
    ).execute()
    return {"status": "waiting"}


def poll_status(user_id: str) -> dict:
    """Poll while searching or in the confirmation window."""
    try:
        res = (
            supabase_admin.table("instant_match_queue")
            .select("status,matched_with,chat_match_id,confirmation_expires_at")
            .eq("user_id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        return {"status": "not_in_queue"}

    if not res or not res.data:
        return {"status": "not_in_queue"}

    row    = res.data
    status = row["status"]

    if status == "confirming":
        partner_id = row["matched_with"]
        match_id   = row["chat_match_id"]
        expires_at = row.get("confirmation_expires_at")
        try:
            partner = _get_profile(partner_id)
            return {
                "status":     "confirming",
                "match_id":   match_id,
                "expires_at": expires_at,
                "partner":    _partner_summary(partner),
            }
        except Exception:
            return {"status": "confirming", "match_id": match_id,
                    "expires_at": expires_at, "partner": None}

    if status == "partner_skipped":
        # Clean up own entry — frontend will re-call /join to search again
        try:
            supabase_admin.table("instant_match_queue").delete().eq("user_id", user_id).execute()
        except Exception:
            pass
        return {"status": "partner_skipped"}

    return {"status": status}  # "waiting"


def skip_match(user_id: str) -> dict:
    """Called when user presses Skip during the 5-second confirmation window.
    Marks the partner's queue entry as 'partner_skipped' so they know to go
    back to searching on their next poll.
    """
    try:
        res = (
            supabase_admin.table("instant_match_queue")
            .select("matched_with,status")
            .eq("user_id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        res = None

    if res and res.data and res.data.get("status") == "confirming":
        partner_id = res.data.get("matched_with")
        if partner_id:
            try:
                supabase_admin.table("instant_match_queue").update(
                    {"status": "partner_skipped"}
                ).eq("user_id", partner_id).execute()
            except Exception:
                pass

    try:
        supabase_admin.table("instant_match_queue").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    return {"status": "skipped"}


def confirm_match(user_id: str) -> dict:
    """Called when user presses 'Start Chat' or the 5-second timer fires.
    Consumes quota, removes from queue, returns match_id + partner info.
    Marks the match as is_instant_match=True so it stays hidden from Messages.
    """
    try:
        res = (
            supabase_admin.table("instant_match_queue")
            .select("matched_with,chat_match_id,status")
            .eq("user_id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        res = None

    if not res or not res.data:
        return {"status": "not_in_queue"}

    row        = res.data
    match_id   = row.get("chat_match_id")
    partner_id = row.get("matched_with")

    # Consume quota now (only on confirmed use)
    try:
        _consume_quota(user_id)
    except Exception:
        pass

    # Remove own entry
    try:
        supabase_admin.table("instant_match_queue").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    # Mark the match as a temporary instant-match chat (hidden from Messages tab)
    if match_id:
        try:
            supabase_admin.table("matches").update(
                {"is_instant_match": True, "instant_match_ended": False, "im_invite_from": None}
            ).eq("id", match_id).execute()
        except Exception:
            pass

    partner_data = None
    if partner_id:
        try:
            partner_data = _partner_summary(_get_profile(partner_id))
        except Exception:
            pass

    return {"status": "confirmed", "match_id": match_id, "partner": partner_data}


def leave_queue(user_id: str) -> dict:
    """Cancel search (while in 'waiting' state)."""
    try:
        supabase_admin.table("instant_match_queue").delete().eq("user_id", user_id).execute()
    except Exception:
        pass
    return {"status": "cancelled"}


# ── Instant Match Chat ────────────────────────────────────────────────────────

def _assert_im_participant(user_id: str, match_id: str) -> dict:
    """Return the match row; raise 403/404 if not a participant or not an IM chat."""
    res = (
        supabase_admin.table("matches")
        .select("id,user1_id,user2_id,is_instant_match,instant_match_ended,im_invite_from")
        .eq("id", match_id)
        .maybe_single()
        .execute()
    )
    if not res or not res.data:
        raise HTTPException(404, "Match not found")
    match = res.data
    if match["user1_id"] != user_id and match["user2_id"] != user_id:
        raise HTTPException(403, "You are not a participant in this match")
    return match


def get_chat_status(user_id: str, match_id: str) -> dict:
    """Poll endpoint: returns whether the IM chat is still live and any invite state."""
    match = _assert_im_participant(user_id, match_id)
    partner_id = match["user2_id"] if match["user1_id"] == user_id else match["user1_id"]
    invite_from = match.get("im_invite_from")

    invite_status = None  # none | sent | received
    if invite_from == user_id:
        invite_status = "sent"
    elif invite_from and invite_from != user_id:
        invite_status = "received"

    return {
        "ended":        match.get("instant_match_ended", False),
        "invite_status": invite_status,
        "invite_from":  invite_from,
        "partner_id":   partner_id,
    }


def leave_instant_chat(user_id: str, match_id: str) -> dict:
    """User leaves the IM chat — marks it as ended for both sides.
    The chat history is preserved but nobody can send new messages.
    """
    _assert_im_participant(user_id, match_id)
    try:
        supabase_admin.table("matches").update(
            {"instant_match_ended": True}
        ).eq("id", match_id).execute()
    except Exception:
        pass
    return {"status": "left"}


def send_friend_invite(user_id: str, match_id: str) -> dict:
    """Send a friend invite within the IM chat.
    Sets im_invite_from = user_id on the match row.
    """
    match = _assert_im_participant(user_id, match_id)
    if match.get("instant_match_ended"):
        raise HTTPException(403, "Chat has ended. Cannot send invite.")
    if match.get("im_invite_from"):
        raise HTTPException(400, "An invite is already pending.")
    try:
        supabase_admin.table("matches").update(
            {"im_invite_from": user_id}
        ).eq("id", match_id).execute()
    except Exception as e:
        raise HTTPException(500, "Failed to send friend invite") from e
    return {"status": "invite_sent"}


def accept_friend_invite(user_id: str, match_id: str) -> dict:
    """Accept the friend invite — converts the chat into a permanent match.
    Clears is_instant_match and im_invite_from so it appears in Messages.
    """
    match = _assert_im_participant(user_id, match_id)
    invite_from = match.get("im_invite_from")
    if not invite_from:
        raise HTTPException(400, "No pending invite.")
    if invite_from == user_id:
        raise HTTPException(400, "You cannot accept your own invite.")
    try:
        supabase_admin.table("matches").update({
            "is_instant_match":    False,
            "instant_match_ended": False,
            "im_invite_from":      None,
            "removed_at":          None,
        }).eq("id", match_id).execute()
    except Exception as e:
        raise HTTPException(500, "Failed to accept invite") from e
    # Create a notification for the inviter
    try:
        from app.notifications import service as notif
        notif.create(invite_from, "match_created", actor_id=user_id, match_id=match_id)
    except Exception:
        pass
    return {"status": "accepted", "match_id": match_id}


def decline_friend_invite(user_id: str, match_id: str) -> dict:
    """Decline/cancel the pending friend invite."""
    match = _assert_im_participant(user_id, match_id)
    if not match.get("im_invite_from"):
        raise HTTPException(400, "No pending invite.")
    try:
        supabase_admin.table("matches").update(
            {"im_invite_from": None}
        ).eq("id", match_id).execute()
    except Exception as e:
        raise HTTPException(500, "Failed to decline invite") from e
    return {"status": "declined"}
