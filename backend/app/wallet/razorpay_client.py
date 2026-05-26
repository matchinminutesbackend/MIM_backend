"""Thin wrapper around Razorpay's REST API using httpx.

We deliberately skip the official `razorpay` Python SDK to avoid another
dependency — Razorpay's HTTP API is simple Basic-Auth JSON. Covers:

  • Orders.create         (Checkout purchase flow)
  • Payment verification  (HMAC-SHA256 signature over order_id|payment_id)
  • Payouts.create        (Razorpay X — for withdrawals)
  • Contacts/Fund accounts (Razorpay X — one-time payout setup)

If `settings.razorpay_key_id` is blank OR `razorpay_mode == "mock"` the
module runs in mock mode: `create_order` returns a synthetic id and
`verify_payment_signature` always succeeds. This lets local dev exercise
the full flow without hitting real Razorpay.
"""
from __future__ import annotations

import hmac
import hashlib
import base64
import uuid
from typing import Any

import httpx

from app.config import settings

RAZORPAY_BASE = "https://api.razorpay.com/v1"


def is_mock() -> bool:
    return settings.razorpay_mode == "mock" or not settings.razorpay_key_id


def _auth_header() -> dict[str, str]:
    raw = f"{settings.razorpay_key_id}:{settings.razorpay_key_secret}".encode()
    return {"Authorization": "Basic " + base64.b64encode(raw).decode()}


def _post(path: str, body: dict) -> dict:
    if is_mock():
        raise RuntimeError("Razorpay is in mock mode — call was not expected")
    with httpx.Client(timeout=15.0) as client:
        r = client.post(f"{RAZORPAY_BASE}{path}", json=body, headers=_auth_header())
        r.raise_for_status()
        return r.json()


def create_order(amount_paise: int, receipt: str, notes: dict | None = None) -> dict:
    """Create a Razorpay Order. Amount is in paise (₹1 = 100 paise).

    Returns the raw order object; the frontend needs `id`, `amount`, `currency`.
    In mock mode returns a synthetic order so the UI flow can be tested.
    """
    if is_mock():
        return {
            "id": f"order_mock_{uuid.uuid4().hex[:14]}",
            "amount": amount_paise,
            "currency": "INR",
            "receipt": receipt,
            "status": "created",
            "notes": notes or {},
        }
    return _post("/orders", {
        "amount": amount_paise,
        "currency": "INR",
        "receipt": receipt,
        "notes": notes or {},
    })


def verify_payment_signature(order_id: str, payment_id: str, signature: str) -> bool:
    """HMAC-SHA256 verification per Razorpay Checkout docs.

    In mock mode always returns True — callers must still validate that
    the order_id matches one they actually created.
    """
    if is_mock():
        return True
    if not (order_id and payment_id and signature):
        return False
    payload = f"{order_id}|{payment_id}".encode()
    expected = hmac.new(
        settings.razorpay_key_secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


# ── Razorpay X (Payouts) ─────────────────────────────────────────
# Used for withdrawals. Requires RazorpayX activation + an account
# number. For mock mode we simulate a queued payout.

def create_contact(name: str, email: str | None, phone: str | None) -> dict:
    if is_mock():
        return {"id": f"cont_mock_{uuid.uuid4().hex[:14]}"}
    body = {"name": name, "type": "customer"}
    if email:
        body["email"] = email
    if phone:
        body["contact"] = phone
    return _post("/contacts", body)


def create_fund_account_upi(contact_id: str, upi_id: str, name: str) -> dict:
    if is_mock():
        return {"id": f"fa_mock_{uuid.uuid4().hex[:14]}"}
    return _post("/fund_accounts", {
        "contact_id": contact_id,
        "account_type": "vpa",
        "vpa": {"address": upi_id},
    })


def create_fund_account_bank(
    contact_id: str, account_name: str, account_number: str, ifsc: str,
) -> dict:
    if is_mock():
        return {"id": f"fa_mock_{uuid.uuid4().hex[:14]}"}
    return _post("/fund_accounts", {
        "contact_id": contact_id,
        "account_type": "bank_account",
        "bank_account": {
            "name": account_name,
            "account_number": account_number,
            "ifsc": ifsc,
        },
    })


def create_payout(
    fund_account_id: str,
    amount_paise: int,
    mode: str,            # "UPI" | "IMPS" | "NEFT" | "RTGS"
    reference_id: str,
    account_number: str,  # RazorpayX account number
) -> dict:
    """Trigger an actual payout. In mock mode returns a fake queued payout.

    `account_number` is the business's RazorpayX virtual account — it is
    NOT the user's bank account. Set via env (razorpayx_account_number).
    """
    if is_mock():
        return {
            "id": f"pout_mock_{uuid.uuid4().hex[:14]}",
            "status": "queued",
            "amount": amount_paise,
        }
    return _post("/payouts", {
        "account_number": account_number,
        "fund_account_id": fund_account_id,
        "amount": amount_paise,
        "currency": "INR",
        "mode": mode,
        "purpose": "payout",
        "queue_if_low_balance": True,
        "reference_id": reference_id,
    })
