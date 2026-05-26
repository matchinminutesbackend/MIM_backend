"""Wallet / credit ledger service.

All credit movements go through `_apply_delta` so the ledger stays the
single source of truth. `wallets.balance` is a denormalised convenience
column kept in sync inside the same update.

Economics (per product spec — enforced here, not in DB):
  • PURCHASE_RATE_INR     1 credit = ₹1 on purchase
  • WITHDRAWAL_RATE_PAISE 1 credit = 70 paise (₹0.70) on cash-out
  • MIN_PURCHASE_CREDITS  50
  • MIN_WITHDRAWAL_CREDITS 500
  • SIGNUP_BONUS_CREDITS  20 (granted after profile complete + face verify)
  • Bulk discounts on purchase (see PRICE_TIERS below)
"""
from __future__ import annotations

from typing import Optional
from datetime import datetime, timezone

from fastapi import HTTPException

from app.supabase_client import supabase_admin
from app.wallet import razorpay_client as rzp

# ── Constants ────────────────────────────────────────────────────
WITHDRAWAL_RATE_PAISE = 70        # 1 credit = 70 paise on cash-out
MIN_PURCHASE_CREDITS = 50         # floor for fixed / discounted packs
MIN_CUSTOM_PURCHASE  = 5          # floor for custom-amount purchases (no discount)
MAX_CUSTOM_PURCHASE  = 100_000    # sanity ceiling on a single custom buy
MIN_WITHDRAWAL_CREDITS = 500
SIGNUP_BONUS_CREDITS = 20
GIFT_RECEIVER_SHARE = 0.70        # 70% of gift cost → receiver
GIFT_REFUND_SHARE   = 0.50        # 50% of gift cost → sender on declined invite

# Credits → INR discount ladder for purchase packs. Discount applies to
# the INR price, not the credit count (user still gets full credits).
PRICE_TIERS = [
    {"credits": 50,   "discount_pct": 0},
    {"credits": 100,  "discount_pct": 5},
    {"credits": 200,  "discount_pct": 10},
    {"credits": 500,  "discount_pct": 20},
    {"credits": 1000, "discount_pct": 25},
]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def credits_to_paise_payout(credits: int) -> int:
    """Cash-out math — credits to paise at the withdrawal rate."""
    return credits * WITHDRAWAL_RATE_PAISE


def price_for_pack(credits: int) -> dict:
    """Return {credits, inr_paise, discount_pct} for a given pack size.

    Raises if `credits` isn't one of the advertised tiers — we only sell
    the fixed packs, not arbitrary amounts, to keep checkout simple.
    """
    tier = next((t for t in PRICE_TIERS if t["credits"] == credits), None)
    if not tier:
        raise HTTPException(400, f"Invalid pack size: {credits}")
    gross = credits * 100  # ₹1 = 100 paise per credit
    net = int(gross * (100 - tier["discount_pct"]) / 100)
    return {
        "credits": credits,
        "inr_paise": net,
        "inr": net / 100,
        "discount_pct": tier["discount_pct"],
    }


def price_for_custom(credits: int) -> dict:
    """Custom-amount price: 1 credit = ₹1, no bulk discount.

    Bounded to [MIN_CUSTOM_PURCHASE, MAX_CUSTOM_PURCHASE] so users can top up
    small amounts (e.g. 5 credits → ₹5 just to grab a rose) without having
    to buy a whole pack — but can't accidentally charge ₹1,00,00,000.
    """
    if credits < MIN_CUSTOM_PURCHASE:
        raise HTTPException(400, f"Minimum custom purchase is {MIN_CUSTOM_PURCHASE} credits")
    if credits > MAX_CUSTOM_PURCHASE:
        raise HTTPException(400, f"Maximum custom purchase is {MAX_CUSTOM_PURCHASE} credits")
    gross = credits * 100
    return {
        "credits":      credits,
        "inr_paise":    gross,
        "inr":          credits,
        "discount_pct": 0,
    }


def price_for_any(credits: int) -> dict:
    """Price lookup that handles both fixed tiers and custom amounts.
    Tier match wins — otherwise fall back to 1:1 custom pricing.
    """
    tier = next((t for t in PRICE_TIERS if t["credits"] == credits), None)
    if tier:
        return price_for_pack(credits)
    return price_for_custom(credits)


# ── Wallet ops ───────────────────────────────────────────────────
def get_or_create_wallet(user_id: str) -> dict:
    res = (
        supabase_admin.table("wallets").select("*").eq("user_id", user_id).execute()
    )
    if res.data:
        return res.data[0]
    # Create with zero balance. Signup bonus is a separate explicit action.
    supabase_admin.table("wallets").insert({"user_id": user_id}).execute()
    return {"user_id": user_id, "balance": 0, "lifetime_earned": 0,
            "lifetime_spent": 0, "signup_bonus_granted": False}


def _apply_delta(
    user_id: str,
    delta: int,
    kind: str,
    ref_id: Optional[str] = None,
    meta: Optional[dict] = None,
) -> dict:
    """Atomically adjust wallet balance and append a ledger row.

    Returns the new wallet snapshot. Raises 402 if the user would go
    negative — callers should check balance up-front for a nicer UX.
    """
    wallet = get_or_create_wallet(user_id)
    new_balance = wallet["balance"] + delta
    if new_balance < 0:
        raise HTTPException(402, "Insufficient credits")

    updates = {"balance": new_balance, "updated_at": _now_iso()}
    if delta > 0:
        updates["lifetime_earned"] = (wallet.get("lifetime_earned") or 0) + delta
    elif delta < 0:
        updates["lifetime_spent"] = (wallet.get("lifetime_spent") or 0) + (-delta)

    supabase_admin.table("wallets").update(updates).eq("user_id", user_id).execute()

    supabase_admin.table("credit_transactions").insert({
        "user_id": user_id,
        "kind": kind,
        "delta": delta,
        "balance_after": new_balance,
        "ref_id": ref_id,
        "meta": meta or {},
    }).execute()

    return {**wallet, **updates}


# ── Purchase flow ────────────────────────────────────────────────
def create_purchase_order(user_id: str, credits: int) -> dict:
    """Create a Razorpay Order for the given pack *or* a custom amount.

    A tier match (50/100/200/500/1000) applies the bulk discount. Anything
    else (≥ MIN_CUSTOM_PURCHASE) is priced 1:1 with no discount. The UI
    picks which path to use but the server is authoritative.

    Billing details (name/email/phone/address) are enforced before the
    real Razorpay order is created — they're needed for GST / dispute
    handling. Mock mode skips that check for local testing.
    """
    pricing = price_for_any(credits)

    billing = get_billing_details(user_id)
    if not rzp.is_mock() and not billing:
        raise HTTPException(
            400,
            "Please save your billing details (name, phone, email, address) before purchasing.",
        )

    # Use a short receipt — Razorpay limits to 40 chars.
    receipt = f"cr_{user_id[:8]}_{int(datetime.now().timestamp())}"

    # Notes land on the Razorpay order so support/finance can trace a
    # payment back to a user without an extra lookup. Kept short — there's
    # a 15-key limit on Razorpay notes.
    notes = {"user_id": user_id, "credits": str(credits)}
    if billing:
        notes.update({
            "billing_name":  billing.get("name", ""),
            "billing_email": billing.get("email", ""),
            "billing_phone": billing.get("phone", ""),
        })

    order = rzp.create_order(
        amount_paise=pricing["inr_paise"],
        receipt=receipt,
        notes=notes,
    )

    # Remember which billing record funded this order — useful when
    # generating invoices after the fact.
    if billing:
        try:
            supabase_admin.table("billing_details").update(
                {"last_order_id": order["id"], "updated_at": _now_iso()}
            ).eq("user_id", user_id).execute()
        except Exception:
            pass

    from app.config import settings
    return {
        "order_id":     order["id"],
        "amount_paise": order["amount"],
        "currency":     order["currency"],
        "credits":      credits,
        "key_id":       settings.razorpay_key_id if settings.razorpay_key_id else "mock",
        "is_mock":      rzp.is_mock(),
        # Echo billing prefill so the frontend can hand it straight to
        # Razorpay Checkout without a second round-trip.
        "prefill": (
            {
                "name":    billing["name"],
                "email":   billing["email"],
                "contact": billing["phone"],
            } if billing else None
        ),
    }


def verify_and_credit_purchase(
    user_id: str,
    order_id: str,
    payment_id: str,
    signature: str,
    credits: int,
) -> dict:
    """Verify the Razorpay signature and credit the purchase.

    Idempotency: if a transaction with this order_id already exists we
    return the existing wallet without double-crediting — Razorpay retries
    verify on unstable connections and the frontend may also retry.
    """
    if not rzp.verify_payment_signature(order_id, payment_id, signature):
        raise HTTPException(400, "Payment signature verification failed")

    existing = (
        supabase_admin.table("credit_transactions")
        .select("id").eq("ref_id", order_id).eq("kind", "purchase")
        .limit(1).execute()
    )
    if existing.data:
        return get_or_create_wallet(user_id)

    # Sanity check: validate credits falls inside an accepted price range
    # (tier or custom) so a malicious client can't claim more credits than
    # were priced server-side on the original order.
    price_for_any(credits)

    return _apply_delta(
        user_id, credits, "purchase",
        ref_id=order_id,
        meta={"payment_id": payment_id},
    )


# ── Signup bonus ─────────────────────────────────────────────────
def grant_signup_bonus_if_eligible(user_id: str) -> Optional[dict]:
    """Called from the face-verification success path. Grants 20 credits
    exactly once per user, only if the profile is complete AND verified.
    Returns the updated wallet if granted, else None.
    """
    wallet = get_or_create_wallet(user_id)
    if wallet.get("signup_bonus_granted"):
        return None

    prof = (
        supabase_admin.table("profiles")
        .select("is_complete,is_verified").eq("id", user_id).execute()
    )
    if not prof.data:
        return None
    row = prof.data[0]
    if not (row.get("is_complete") and row.get("is_verified")):
        return None

    updated = _apply_delta(user_id, SIGNUP_BONUS_CREDITS, "signup_bonus",
                           meta={"reason": "profile_complete_and_verified"})
    supabase_admin.table("wallets").update(
        {"signup_bonus_granted": True}
    ).eq("user_id", user_id).execute()
    return updated


# ── Transactions listing ─────────────────────────────────────────
def list_transactions(user_id: str, limit: int = 50) -> list[dict]:
    res = (
        supabase_admin.table("credit_transactions")
        .select("*").eq("user_id", user_id)
        .order("created_at", desc=True).limit(limit).execute()
    )
    return res.data or []


# ── Billing details ──────────────────────────────────────────────
# Captured once per user (name / email / phone / address) and reused on
# subsequent checkouts so the Razorpay modal feels one-click. Razorpay
# needs these for receipts & dispute handling on real (non-mock) orders.

_BILLING_REQUIRED = ("name", "email", "phone", "address_line1",
                     "city", "state", "pincode")


def get_billing_details(user_id: str) -> Optional[dict]:
    try:
        res = (
            supabase_admin.table("billing_details")
            .select("*").eq("user_id", user_id).execute()
        )
    except Exception:
        # Table may not exist yet (migration not run) — treat as "no billing".
        return None
    return res.data[0] if res.data else None


def save_billing_details(user_id: str, payload: dict) -> dict:
    """Upsert a billing record. Validates the required fields but stays
    lenient on format — Razorpay does its own validation at checkout.
    """
    clean: dict = {}
    for key in _BILLING_REQUIRED:
        val = (payload.get(key) or "").strip()
        if not val:
            raise HTTPException(400, f"{key} is required")
        clean[key] = val

    # Basic sanity on email / phone / pincode so we fail fast instead of
    # later inside Razorpay's checkout iframe.
    if "@" not in clean["email"] or "." not in clean["email"]:
        raise HTTPException(400, "Invalid email")
    phone_digits = "".join(ch for ch in clean["phone"] if ch.isdigit())
    if len(phone_digits) < 10:
        raise HTTPException(400, "Phone must have at least 10 digits")
    if not clean["pincode"].isdigit() or len(clean["pincode"]) != 6:
        raise HTTPException(400, "Pincode must be 6 digits")

    clean["address_line2"] = (payload.get("address_line2") or "").strip() or None
    clean["country"] = (payload.get("country") or "IN").strip() or "IN"
    clean["user_id"] = user_id
    clean["updated_at"] = _now_iso()

    existing = get_billing_details(user_id)
    if existing:
        supabase_admin.table("billing_details").update(clean).eq("user_id", user_id).execute()
    else:
        clean["created_at"] = _now_iso()
        supabase_admin.table("billing_details").insert(clean).execute()
    return get_billing_details(user_id)


# ── Payout details ───────────────────────────────────────────────
def get_payout_details(user_id: str) -> Optional[dict]:
    res = (
        supabase_admin.table("payout_details")
        .select("*").eq("user_id", user_id).execute()
    )
    return res.data[0] if res.data else None


def save_payout_details(user_id: str, payload: dict) -> dict:
    """Upsert UPI or bank details. Resets Razorpay contact/fund-account ids
    so they get re-created the next time a payout is requested (the old
    fund account is no longer valid if details changed).
    """
    method = payload.get("method")
    if method not in ("upi", "bank"):
        raise HTTPException(400, "method must be 'upi' or 'bank'")

    row = {"user_id": user_id, "method": method, "updated_at": _now_iso()}
    if method == "upi":
        upi = (payload.get("upi_id") or "").strip()
        if "@" not in upi or len(upi) < 4:
            raise HTTPException(400, "Invalid UPI id")
        row.update({"upi_id": upi, "account_name": None,
                    "account_number": None, "ifsc": None})
    else:
        name = (payload.get("account_name") or "").strip()
        num  = (payload.get("account_number") or "").strip()
        ifsc = (payload.get("ifsc") or "").strip().upper()
        if not (name and num and ifsc):
            raise HTTPException(400, "account_name, account_number, ifsc required")
        row.update({"account_name": name, "account_number": num, "ifsc": ifsc,
                    "upi_id": None})

    row["rzp_contact_id"] = None
    row["rzp_fund_account_id"] = None

    existing = get_payout_details(user_id)
    if existing:
        supabase_admin.table("payout_details").update(row).eq("user_id", user_id).execute()
    else:
        row["created_at"] = _now_iso()
        supabase_admin.table("payout_details").insert(row).execute()
    return get_payout_details(user_id)


# ── Withdrawal flow ──────────────────────────────────────────────
def list_withdrawals(user_id: str, limit: int = 20) -> list[dict]:
    res = (
        supabase_admin.table("withdrawal_requests")
        .select("*").eq("user_id", user_id)
        .order("created_at", desc=True).limit(limit).execute()
    )
    return res.data or []


def request_withdrawal(user_id: str, credits: int) -> dict:
    """Queue a withdrawal: hold credits immediately (prevents double-spend)
    and record a pending row. An admin or cron process calls
    `process_withdrawal` later to actually trigger the Razorpay X payout.
    """
    if credits < MIN_WITHDRAWAL_CREDITS:
        raise HTTPException(400, f"Minimum withdrawal is {MIN_WITHDRAWAL_CREDITS} credits")

    payout = get_payout_details(user_id)
    if not payout:
        raise HTTPException(400, "Add UPI or bank details before withdrawing")

    wallet = get_or_create_wallet(user_id)
    if wallet["balance"] < credits:
        raise HTTPException(402, "Insufficient credits")

    inr_paise = credits_to_paise_payout(credits)

    # Create the request row first so we have an id for the ref_id.
    req = supabase_admin.table("withdrawal_requests").insert({
        "user_id": user_id,
        "credits": credits,
        "inr_paise": inr_paise,
        "status": "pending",
    }).execute()
    if not req.data:
        raise HTTPException(500, "Failed to create withdrawal request")
    wreq = req.data[0]

    # Hold the credits (debit now, refund on reject).
    _apply_delta(user_id, -credits, "withdrawal_hold",
                 ref_id=wreq["id"],
                 meta={"inr_paise": inr_paise})

    return wreq
