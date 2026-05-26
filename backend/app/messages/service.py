from app.supabase_client import supabase_admin
from fastapi import HTTPException


def _assert_participant(user_id: str, match_id: str) -> dict:
    """Raise 403 if user is not part of this match. Returns match row."""
    res = supabase_admin.table("matches").select("*").eq("id", match_id).execute()
    if not res.data:
        raise HTTPException(404, "Match not found")
    match = res.data[0]
    if match["user1_id"] != user_id and match["user2_id"] != user_id:
        raise HTTPException(403, "You are not a participant in this match")
    return match


def get_conversations(user_id: str) -> list:
    matches_res = supabase_admin.table("matches").select(
        "*,"
        "user1:profiles!user1_id(id, name, main_image_url, city, age, last_seen),"
        "user2:profiles!user2_id(id, name, main_image_url, city, age, last_seen)"
    ).or_(
        f"user1_id.eq.{user_id},user2_id.eq.{user_id}"
    ).eq("is_instant_match", False).execute()  # hide temporary instant-match chats

    conversations = []
    for match in (matches_res.data or []):
        partner = match["user2"] if match["user1_id"] == user_id else match["user1"]
        match_id = match["id"]

        # Last message in this conversation
        last_msg = supabase_admin.table("messages") \
            .select("content, sender_id, created_at") \
            .eq("match_id", match_id) \
            .order("created_at", desc=True) \
            .limit(1).execute()

        # Unread count (messages from partner that I haven't read)
        unread = supabase_admin.table("messages") \
            .select("id", count="exact") \
            .eq("match_id", match_id) \
            .eq("is_read", False) \
            .neq("sender_id", user_id).execute()

        conversations.append({
            "match_id": match_id,
            "partner": partner,
            "last_message": last_msg.data[0] if last_msg.data else None,
            "unread_count": unread.count or 0,
            "matched_at": match["created_at"],
            # Soft-unfriend metadata so the UI can render a read-only banner
            "removed_at": match.get("removed_at"),
            "removed_by": match.get("removed_by"),
        })

    # Sort by most recent activity
    conversations.sort(
        key=lambda c: (
            c["last_message"]["created_at"] if c["last_message"] else c["matched_at"]
        ),
        reverse=True,
    )
    return conversations


def get_messages(user_id: str, match_id: str) -> list:
    _assert_participant(user_id, match_id)
    res = supabase_admin.table("messages") \
        .select("*") \
        .eq("match_id", match_id) \
        .order("created_at", desc=False).execute()
    return res.data or []


def send_message(user_id: str, match_id: str, content: str) -> dict:
    match = _assert_participant(user_id, match_id)

    # Soft-removed matches are read-only — history stays, new sends are blocked
    if match.get("removed_at"):
        raise HTTPException(403, "This conversation has been closed. You can no longer send messages.")

    content = content.strip()
    if not content:
        raise HTTPException(400, "Message cannot be empty")
    if len(content) > 2000:
        raise HTTPException(400, "Message is too long (max 2000 characters)")

    res = supabase_admin.table("messages").insert({
        "match_id": match_id,
        "sender_id": user_id,
        "content": content,
        "is_read": False,
    }).execute()

    if not res.data:
        raise HTTPException(500, "Failed to send message")
    return res.data[0]


def _format_duration(seconds: int) -> str:
    """Human-readable call duration. Keeps the message short but precise."""
    seconds = max(0, int(seconds))
    if seconds < 60:
        return f"{seconds}s"
    m, s = divmod(seconds, 60)
    if m < 60:
        return f"{m}m {s}s" if s else f"{m}m"
    h, m = divmod(m, 60)
    return f"{h}h {m}m"


def send_call_summary(
    user_id: str,
    match_id: str,
    *,
    media: str,           # 'audio' | 'video'
    duration_seconds: int,
    missed: bool,
) -> dict:
    """Insert a system message describing a just-ended call. Server formats
    the text so the client can't spoof fake durations or media types. The
    content is still a plain ``messages.content`` string — the frontend
    recognises the ``📞`` / ``🎥`` / ``📵`` prefix and styles it as a call
    chip instead of a chat bubble.
    """
    match = _assert_participant(user_id, match_id)
    if match.get("removed_at"):
        # Don't log calls into torn-down threads — nothing to show anyway.
        raise HTTPException(403, "This conversation is closed.")

    media = "video" if media == "video" else "audio"
    label = "Video call" if media == "video" else "Voice call"
    if missed:
        content = f"📵 Missed {label.lower()}"
    else:
        icon = "🎥" if media == "video" else "📞"
        content = f"{icon} {label} · {_format_duration(duration_seconds)}"

    res = supabase_admin.table("messages").insert({
        "match_id": match_id,
        "sender_id": user_id,
        "content": content,
        "is_read": False,
    }).execute()
    if not res.data:
        raise HTTPException(500, "Failed to log call")
    return res.data[0]


def mark_read(user_id: str, match_id: str) -> dict:
    _assert_participant(user_id, match_id)
    # Mark all messages in this match as read, where the sender is NOT me
    supabase_admin.table("messages") \
        .update({"is_read": True}) \
        .eq("match_id", match_id) \
        .neq("sender_id", user_id) \
        .eq("is_read", False).execute()
    return {"ok": True}
