"""
WebSocket layer for real-time chat + WebRTC call signaling.

Protocol
────────
Client connects:  ws://host/ws/chat?token=<JWT>

Server → Client events (JSON):
  { "type": "connected",          "user_id": "..." }
  { "type": "new_message",        "match_id": "...", "message": {...} }
  { "type": "messages_read",      "match_id": "...", "reader_id": "..." }
  { "type": "messages_delivered", "match_id": "...", "message_ids": [...] }
  { "type": "typing",             "match_id": "...", "user_id": "..." }
  { "type": "match_created",      "match_id": "...", "partner": {...} }
  { "type": "user_status",        "user_id": "...", "online": true|false, "last_seen": "..." }
  { "type": "error",              "detail": "..." }
  { "type": "pong" }

  — Call signaling (forwarded as-is to the partner) —
  { "type": "call_invite",   "match_id": "...", "from_user_id": "...",
    "call_id": "...", "media": "audio|video", "caller": {name, photo} }
  { "type": "call_accept",   "match_id": "...", "from_user_id": "...", "call_id": "..." }
  { "type": "call_decline",  "match_id": "...", "from_user_id": "...", "call_id": "...", "reason": "..." }
  { "type": "call_hangup",   "match_id": "...", "from_user_id": "...", "call_id": "...", "duration": 123 }
  { "type": "call_offer",    "match_id": "...", "from_user_id": "...", "call_id": "...", "sdp": {...} }
  { "type": "call_answer",   "match_id": "...", "from_user_id": "...", "call_id": "...", "sdp": {...} }
  { "type": "call_ice",      "match_id": "...", "from_user_id": "...", "call_id": "...", "candidate": {...} }

Client → Server events (JSON):
  { "type": "ping" }
  { "type": "typing", "match_id": "..." }

  — Call signaling (client originates; server verifies match & forwards) —
  { "type": "call_invite|call_accept|call_decline|call_hangup|call_offer|
             call_answer|call_ice",
    "match_id": "...",  // required — used to find the partner
    "call_id":  "...",  // client-generated uuid; ties offer/answer/ice together
    ...payload-specific fields }

Regular text messages are still sent via REST POST /messages/{match_id}; the
server broadcasts a `new_message` event after insert so validation, auth,
and storage all live on a single code path.

Call signaling, by contrast, is latency-sensitive and never persisted —
so it rides the socket directly. We only forward between verified match
participants and only if the caller's tier permits it (Pro or female).
"""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Dict, Set

from fastapi import WebSocket, WebSocketDisconnect, Query, APIRouter
from app.auth.utils import decode_token
from app.supabase_client import supabase_admin

log = logging.getLogger("chat.ws")
router = APIRouter()

# Message types that belong to the WebRTC signaling channel. Kept as a
# frozenset so the dispatch-loop lookup is O(1).
_CALL_KINDS = frozenset({
    "call_invite",   # caller → callee: new ring
    "call_accept",   # callee → caller: accepted, please send offer
    "call_decline",  # callee → caller: declined (or busy)
    "call_hangup",   # either → either: end the call
    "call_offer",    # caller → callee: RTCSessionDescription (offer)
    "call_answer",   # callee → caller: RTCSessionDescription (answer)
    "call_ice",      # either → either: RTCIceCandidate
})


class ConnectionManager:
    """Tracks active WebSocket connections per user. One user may have many
    open tabs/devices — all of them receive broadcasts addressed to that user."""

    def __init__(self) -> None:
        self._conns: Dict[str, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        async with self._lock:
            self._conns.setdefault(user_id, set()).add(ws)

    async def disconnect(self, user_id: str, ws: WebSocket) -> None:
        async with self._lock:
            sockets = self._conns.get(user_id)
            if not sockets:
                return
            sockets.discard(ws)
            if not sockets:
                self._conns.pop(user_id, None)

    def is_online(self, user_id: str) -> bool:
        return user_id in self._conns

    async def send_to_user(self, user_id: str, payload: dict) -> None:
        sockets = list(self._conns.get(user_id, ()))
        if not sockets:
            return
        data = json.dumps(payload, default=str)
        dead: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_text(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(user_id, ws)

    async def send_to_many(self, user_ids, payload: dict) -> None:
        await asyncio.gather(*(self.send_to_user(uid, payload) for uid in user_ids))


manager = ConnectionManager()


def _match_participants(match_id: str) -> tuple[str, str] | None:
    res = supabase_admin.table("matches").select("user1_id, user2_id").eq("id", match_id).execute()
    if not res.data:
        return None
    row = res.data[0]
    return row["user1_id"], row["user2_id"]


def _get_match_partner_ids(user_id: str) -> list[str]:
    """Return all partner user IDs from non-removed matches."""
    res = supabase_admin.table("matches") \
        .select("user1_id, user2_id") \
        .or_(f"user1_id.eq.{user_id},user2_id.eq.{user_id}") \
        .is_("removed_at", "null").execute()
    return [
        row["user2_id"] if row["user1_id"] == user_id else row["user1_id"]
        for row in (res.data or [])
    ]


def _update_last_seen(user_id: str) -> str:
    now = datetime.now(timezone.utc).isoformat()
    supabase_admin.table("profiles").update({"last_seen": now}).eq("id", user_id).execute()
    return now


async def _broadcast_online_status(user_id: str, online: bool, last_seen: str | None = None) -> None:
    partners = _get_match_partner_ids(user_id)
    payload: dict = {"type": "user_status", "user_id": user_id, "online": online}
    if last_seen:
        payload["last_seen"] = last_seen
    await manager.send_to_many(partners, payload)


async def _deliver_pending_messages(user_id: str) -> None:
    """Mark all undelivered messages addressed to user_id as delivered and
    notify each unique sender so they can upgrade their tick from ✓ to ✓✓."""
    match_res = supabase_admin.table("matches") \
        .select("id") \
        .or_(f"user1_id.eq.{user_id},user2_id.eq.{user_id}") \
        .is_("removed_at", "null").execute()
    match_ids = [row["id"] for row in (match_res.data or [])]
    if not match_ids:
        return

    for match_id in match_ids:
        res = supabase_admin.table("messages") \
            .update({"is_delivered": True}) \
            .eq("match_id", match_id) \
            .neq("sender_id", user_id) \
            .eq("is_delivered", False) \
            .execute()
        if res.data:
            msg_ids = [m["id"] for m in res.data]
            senders = {m["sender_id"] for m in res.data}
            for sender_id in senders:
                await manager.send_to_user(sender_id, {
                    "type": "messages_delivered",
                    "match_id": match_id,
                    "message_ids": msg_ids,
                })


async def broadcast_new_message(match_id: str, message: dict) -> None:
    parties = _match_participants(match_id)
    if not parties:
        return
    sender_id = message.get("sender_id")
    receiver_id = parties[1] if parties[0] == sender_id else parties[0]

    # Auto-deliver if the receiver is currently connected
    if manager.is_online(receiver_id):
        supabase_admin.table("messages") \
            .update({"is_delivered": True}) \
            .eq("id", message["id"]).execute()
        message = {**message, "is_delivered": True}
        await manager.send_to_user(sender_id, {
            "type": "messages_delivered",
            "match_id": match_id,
            "message_ids": [message["id"]],
        })

    await manager.send_to_many(parties, {
        "type": "new_message",
        "match_id": match_id,
        "message": message,
    })

    # FCM: always send a push so the receiver gets a system notification banner
    # regardless of whether their WebSocket is currently open. The client-side
    # local notification (from the WS handler) already fires when the app is
    # in the foreground, but FCM is needed for background / killed-app state.
    try:
        from app.fcm import send_push
        sender_profile = supabase_admin.table("profiles") \
            .select("name").eq("id", sender_id).single().execute()
        sender_name = (sender_profile.data or {}).get("name", "Someone")
        content = message.get("content", "")
        body = content[:80] + ("…" if len(content) > 80 else "")
        send_push(
            receiver_id,
            title=f"{sender_name} 💬",
            body=body or "Sent you a message",
            data={"type": "new_message", "match_id": str(match_id)},
        )
    except Exception:
        pass


async def broadcast_messages_read(match_id: str, reader_id: str) -> None:
    parties = _match_participants(match_id)
    if not parties:
        return
    await manager.send_to_many(parties, {
        "type": "messages_read",
        "match_id": match_id,
        "reader_id": reader_id,
    })


def _notif_push_text(notification: dict) -> tuple[str, str]:
    """Return (title, body) for a FCM push based on the notification type."""
    ntype = notification.get("type", "")
    actor_name = (notification.get("actor") or {}).get("name") or "Someone"
    payload = notification.get("payload") or {}

    if ntype == "match_created":
        return "New Match! 🎉", f"You and {actor_name} matched!"
    if ntype == "like_received":
        return "New Like ❤️", f"{actor_name} liked your profile"
    if ntype == "gift_like":
        gift_msg = payload.get("message", "")
        body = f"{actor_name} super liked you 🎁"
        if gift_msg:
            body += f': "{gift_msg}"'
        return "Super Like 🎁", body
    if ntype == "match_invitation":
        return "Friend Request 💕", f"{actor_name} wants to reconnect"
    if ntype == "match_restored":
        return "Friend Restored 💕", f"You and {actor_name} are friends again!"
    if ntype == "invitation_declined":
        return "Invite Update", f"{actor_name} passed your invite"
    if ntype == "profile_view":
        return "Profile Viewed 👀", f"{actor_name} viewed your profile"
    # Fallback
    return "MatchInMinutes", "You have a new notification"


async def broadcast_notification(user_id: str, notification: dict) -> None:
    """Push a new notification row to any connected tab/device of the user.

    If the user is not currently connected via WebSocket (app backgrounded or
    closed), we also send an FCM push notification so they see it on-device.
    """
    await manager.send_to_user(user_id, {
        "type": "notification",
        "notification": notification,
    })

    # FCM: only fire when the user has no active WebSocket connection.
    if not manager.is_online(user_id):
        try:
            from app.fcm import send_push  # local import — avoids hard dependency
            title, body = _notif_push_text(notification)
            send_push(
                user_id,
                title=title,
                body=body,
                data={"type": notification.get("type", ""), "notification_id": str(notification.get("id", ""))},
            )
        except Exception:
            pass


async def broadcast_match_removed(match_id: str, remover_id: str, partner_id: str) -> None:
    """Notify both parties that a match was torn down. Frontends should drop the
    conversation from their UI and close any open chat for that match."""
    for uid in (remover_id, partner_id):
        await manager.send_to_user(uid, {
            "type": "match_removed",
            "match_id": match_id,
            "removed_by": remover_id,
            "partner_id": partner_id if uid == remover_id else remover_id,
        })


async def broadcast_match_created(match_id: str, user_a_id: str, user_b_id: str) -> None:
    """Notify both parties that a mutual match was formed."""
    profiles = supabase_admin.table("profiles") \
        .select("id, name, main_image_url, city, age") \
        .in_("id", [user_a_id, user_b_id]).execute()
    by_id = {p["id"]: p for p in (profiles.data or [])}

    for uid, partner_id in ((user_a_id, user_b_id), (user_b_id, user_a_id)):
        await manager.send_to_user(uid, {
            "type": "match_created",
            "match_id": match_id,
            "partner": by_id.get(partner_id),
        })


@router.websocket("/ws/chat")
async def chat_socket(ws: WebSocket, token: str = Query(...)):
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Invalid token")
    except Exception:
        await ws.close(code=4401)
        return

    await ws.accept()
    await manager.connect(user_id, ws)
    await ws.send_json({"type": "connected", "user_id": user_id})

    # Notify match partners this user is now online
    await _broadcast_online_status(user_id, online=True)
    # Deliver any messages that arrived while the user was offline
    await _deliver_pending_messages(user_id)

    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send_json({"type": "error", "detail": "Invalid JSON"})
                continue

            kind = msg.get("type")

            if kind == "ping":
                await ws.send_json({"type": "pong"})

            elif kind == "typing":
                match_id = msg.get("match_id")
                if not match_id:
                    continue
                parties = _match_participants(match_id)
                if not parties or user_id not in parties:
                    continue
                partner_id = parties[1] if parties[0] == user_id else parties[0]
                await manager.send_to_user(partner_id, {
                    "type": "typing",
                    "match_id": match_id,
                    "user_id": user_id,
                })

            elif kind in _CALL_KINDS:
                # Call signaling is forwarded as-is to the partner. We
                # verify the match participation on every hop, and on the
                # initial `call_invite` we additionally gate on tier so
                # non-Pro users can't even start ringing a partner.
                match_id = msg.get("match_id")
                if not match_id:
                    continue
                parties = _match_participants(match_id)
                if not parties or user_id not in parties:
                    continue
                partner_id = parties[1] if parties[0] == user_id else parties[0]

                if kind == "call_invite":
                    # Gate the caller — women + Pro pass; everyone else
                    # gets a typed error the client turns into a paywall.
                    try:
                        from app.subscriptions import service as subs
                        subs.check_can_call(user_id)
                    except Exception:
                        await ws.send_json({
                            "type":     "call_error",
                            "match_id": match_id,
                            "call_id":  msg.get("call_id"),
                            "code":     "calls_locked",
                            "detail":   "Voice & video calls are a Pro feature.",
                        })
                        continue

                # Forward full payload (sdp, candidate, media, etc.) plus
                # the sender id so the receiver can match the call_id.
                forward = {**msg, "from_user_id": user_id}
                await manager.send_to_user(partner_id, forward)

            # silently ignore unknown types
    except WebSocketDisconnect:
        pass
    except Exception as e:
        log.warning("ws error for user=%s: %s", user_id, e)
    finally:
        await manager.disconnect(user_id, ws)
        # Only mark offline when no other tabs/devices remain connected
        if not manager.is_online(user_id):
            last_seen = _update_last_seen(user_id)
            await _broadcast_online_status(user_id, online=False, last_seen=last_seen)
