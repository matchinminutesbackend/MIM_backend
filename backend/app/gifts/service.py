"""Gift catalog + send flow.

Economy (spec):
  • Sender pays the full gift cost (debit).
  • Chat-context: receiver immediately gets 70% credited.
  • Invite-context: held as `pending` until the invite is accepted / declined.
      – accept  → receiver gets 70% credited, status → delivered
      – decline → sender gets 50% refunded (50% kept by platform),
                  status → refunded
  • Minimum gift cost is 30 credits — enforced via the DB CHECK on `gifts`
    and by the seed data we ship.
"""
from __future__ import annotations

from typing import Optional, Literal
from fastapi import HTTPException

from app.supabase_client import supabase_admin
from app.wallet import service as wallet_service


Context = Literal["invite", "chat"]


# ── Catalog ──────────────────────────────────────────────────────
def list_gifts() -> list[dict]:
    """Active catalog ordered by sort_order (cost ascending in practice)."""
    res = (
        supabase_admin.table("gifts")
        .select("*")
        .eq("is_active", True)
        .order("sort_order").execute()
    )
    return res.data or []


def get_gift(slug: str) -> dict:
    res = (
        supabase_admin.table("gifts")
        .select("*").eq("slug", slug).eq("is_active", True)
        .limit(1).execute()
    )
    if not res.data:
        raise HTTPException(404, f"Gift '{slug}' not found")
    return res.data[0]


def _receiver_share(cost: int) -> int:
    """70% of cost, floored — receiver never gets more than what's priced."""
    return int(cost * wallet_service.GIFT_RECEIVER_SHARE)


def _refund_share(cost: int) -> int:
    """50% refund on declined invite, floored."""
    return int(cost * wallet_service.GIFT_REFUND_SHARE)


# ── Send gift ────────────────────────────────────────────────────
def send_gift(
    sender_id: str,
    receiver_id: str,
    gift_slug: str,
    context: Context,
    match_id: Optional[str] = None,
    message_id: Optional[str] = None,
) -> dict:
    """Debit the sender, create a gift_send row, and (for chat context)
    credit the receiver immediately. For invite context, status stays
    `pending` until the partner accepts/declines the invitation.
    """
    if sender_id == receiver_id:
        raise HTTPException(400, "You can't send a gift to yourself")

    gift = get_gift(gift_slug)
    cost = gift["cost"]

    # Sender funds check (friendly pre-flight; _apply_delta also enforces)
    sender_wallet = wallet_service.get_or_create_wallet(sender_id)
    if sender_wallet["balance"] < cost:
        raise HTTPException(402, f"Insufficient credits ({cost} needed)")

    share = _receiver_share(cost)
    status = "delivered" if context == "chat" else "pending"

    send_row = supabase_admin.table("gift_sends").insert({
        "gift_id":        gift["id"],
        "sender_id":      sender_id,
        "receiver_id":    receiver_id,
        "context":        context,
        "match_id":       match_id,
        "message_id":     message_id,
        "cost":           cost,
        "receiver_share": share,
        "status":         status,
    }).execute()

    if not send_row.data:
        raise HTTPException(500, "Failed to record gift send")
    gs = send_row.data[0]

    # Debit sender now (both contexts)
    wallet_service._apply_delta(
        sender_id, -cost, "gift_sent",
        ref_id=gs["id"],
        meta={"gift_slug": gift_slug, "gift_name": gift["name"], "context": context,
              "receiver_id": receiver_id, "match_id": match_id},
    )

    # Chat-context: receiver gets 70% immediately.
    if context == "chat":
        wallet_service._apply_delta(
            receiver_id, share, "gift_received",
            ref_id=gs["id"],
            meta={"gift_slug": gift_slug, "gift_name": gift["name"],
                  "sender_id": sender_id, "match_id": match_id},
        )

    return {
        "gift_send": gs,
        "gift": {k: gift[k] for k in ("slug", "name", "icon", "cost", "tier")},
    }


def settle_invite_gift_accept(gift_send_id: str) -> Optional[dict]:
    """Accepted invite → credit the receiver their 70% share and mark delivered.

    Idempotent: a row already in `delivered` or `refunded` returns unchanged.
    """
    row = (
        supabase_admin.table("gift_sends")
        .select("*").eq("id", gift_send_id).limit(1).execute()
    )
    if not row.data:
        return None
    gs = row.data[0]
    if gs["status"] != "pending":
        return gs

    wallet_service._apply_delta(
        gs["receiver_id"], gs["receiver_share"], "gift_received",
        ref_id=gs["id"],
        meta={"via": "invite_accept", "sender_id": gs["sender_id"]},
    )
    updated = (
        supabase_admin.table("gift_sends")
        .update({"status": "delivered"}).eq("id", gs["id"]).execute()
    )
    return updated.data[0] if updated.data else gs


def settle_invite_gift_decline(gift_send_id: str) -> Optional[dict]:
    """Declined invite → refund 50% to sender (remaining 50% stays on platform)."""
    row = (
        supabase_admin.table("gift_sends")
        .select("*").eq("id", gift_send_id).limit(1).execute()
    )
    if not row.data:
        return None
    gs = row.data[0]
    if gs["status"] != "pending":
        return gs

    refund = _refund_share(gs["cost"])
    if refund > 0:
        wallet_service._apply_delta(
            gs["sender_id"], refund, "gift_refund",
            ref_id=gs["id"],
            meta={"via": "invite_decline", "receiver_id": gs["receiver_id"],
                  "platform_kept": gs["cost"] - refund},
        )
    updated = (
        supabase_admin.table("gift_sends")
        .update({"status": "refunded"}).eq("id", gs["id"]).execute()
    )
    return updated.data[0] if updated.data else gs


# ── Listing helpers ──────────────────────────────────────────────
def gifts_for_match(match_id: str, limit: int = 20) -> list[dict]:
    """Gift history for a chat view — both directions, newest first.

    Returned rows are JOIN-flat: each row carries the catalog snapshot
    (name/icon/tier) embedded under `gift` so the UI doesn't need a
    second lookup.
    """
    res = (
        supabase_admin.table("gift_sends")
        .select("*, gift:gifts!gift_id(slug,name,icon,tier)")
        .eq("match_id", match_id)
        .order("created_at", desc=True)
        .limit(limit).execute()
    )
    return res.data or []
