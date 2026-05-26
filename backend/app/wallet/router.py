import logging

from fastapi import APIRouter, Depends, Body
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.wallet import service, razorpay_client

log = logging.getLogger(__name__)

router = APIRouter()


# Zero-state returned by GET /balance when the wallet tables don't exist
# yet (migration not run) — lets the UI render the redesigned page with a
# zero balance instead of failing the whole view.
_ZERO_BALANCE = {
    "balance": 0,
    "lifetime_earned": 0,
    "lifetime_spent": 0,
    "signup_bonus_granted": False,
    "withdrawal_rate_paise": service.WITHDRAWAL_RATE_PAISE,
    "min_withdrawal_credits": service.MIN_WITHDRAWAL_CREDITS,
}


# ── Schemas ──────────────────────────────────────────────────────
class CreateOrderRequest(BaseModel):
    # Accepts either a discounted pack size (50/100/200/500/1000) or a
    # custom top-up amount (≥ 5, 1:1 no-discount). Server decides which
    # pricing applies — the client only sends the credit count.
    credits: int = Field(..., ge=5, le=100_000,
                         description="Pack size (50/100/200/500/1000) or custom amount ≥ 5")


class VerifyPaymentRequest(BaseModel):
    order_id: str
    payment_id: str
    signature: str
    credits: int


class WithdrawRequest(BaseModel):
    credits: int = Field(..., ge=500)


class BillingDetailsRequest(BaseModel):
    name: str
    email: str
    phone: str
    address_line1: str
    address_line2: str | None = None
    city: str
    state: str
    pincode: str
    country: str | None = "IN"


class PayoutDetailsRequest(BaseModel):
    method: str  # 'upi' | 'bank'
    upi_id: str | None = None
    account_name: str | None = None
    account_number: str | None = None
    ifsc: str | None = None


# ── Routes ───────────────────────────────────────────────────────
@router.get("/balance")
async def balance(user=Depends(get_current_user)):
    """Wallet balance + lifetime stats. Side-effect: also tries to grant
    the signup bonus — cheap and keeps the UI responsive without a
    dedicated endpoint call from the face-verify flow.

    If the wallet tables don't exist yet (migration not applied), returns
    a zero-state so the UI still renders instead of erroring.
    """
    try:
        service.grant_signup_bonus_if_eligible(user["id"])
        w = service.get_or_create_wallet(user["id"])
    except Exception as e:
        log.warning("wallet.balance fallback (tables missing?): %s", e)
        return _ZERO_BALANCE
    return {
        "balance": w["balance"],
        "lifetime_earned": w.get("lifetime_earned", 0),
        "lifetime_spent": w.get("lifetime_spent", 0),
        "signup_bonus_granted": w.get("signup_bonus_granted", False),
        "withdrawal_rate_paise": service.WITHDRAWAL_RATE_PAISE,
        "min_withdrawal_credits": service.MIN_WITHDRAWAL_CREDITS,
    }


@router.get("/packs")
async def packs():
    """Available purchase packs with INR price after discount."""
    return [service.price_for_pack(t["credits"]) | {"discount_pct": t["discount_pct"]}
            for t in service.PRICE_TIERS]


@router.post("/purchase/order")
async def create_order(
    body: CreateOrderRequest,
    user=Depends(get_current_user),
):
    return service.create_purchase_order(user["id"], body.credits)


@router.post("/purchase/verify")
async def verify_payment(
    body: VerifyPaymentRequest,
    user=Depends(get_current_user),
):
    wallet = service.verify_and_credit_purchase(
        user["id"], body.order_id, body.payment_id, body.signature, body.credits
    )
    return {"balance": wallet["balance"], "credited": body.credits}


@router.get("/transactions")
async def transactions(user=Depends(get_current_user)):
    try:
        return service.list_transactions(user["id"])
    except Exception as e:
        log.warning("wallet.transactions fallback (tables missing?): %s", e)
        return []


@router.get("/billing-details")
async def get_billing_details(user=Depends(get_current_user)):
    """Return the user's saved billing record (or null). Safe-fallback
    to null if the table doesn't exist yet so the UI can still show the
    form the first time.
    """
    try:
        details = service.get_billing_details(user["id"])
    except Exception as e:
        log.warning("wallet.billing-details fallback (tables missing?): %s", e)
        return None
    return details


@router.put("/billing-details")
async def set_billing_details(
    body: BillingDetailsRequest,
    user=Depends(get_current_user),
):
    return service.save_billing_details(user["id"], body.model_dump())


@router.get("/payout-details")
async def get_payout_details(user=Depends(get_current_user)):
    try:
        details = service.get_payout_details(user["id"])
    except Exception as e:
        log.warning("wallet.payout-details fallback (tables missing?): %s", e)
        return None
    if not details:
        return None
    # Never return Razorpay internal ids to the client.
    return {
        "method": details.get("method"),
        "upi_id": details.get("upi_id"),
        "account_name": details.get("account_name"),
        "account_number_last4": (details.get("account_number") or "")[-4:] or None,
        "ifsc": details.get("ifsc"),
    }


@router.put("/payout-details")
async def set_payout_details(
    body: PayoutDetailsRequest,
    user=Depends(get_current_user),
):
    service.save_payout_details(user["id"], body.model_dump())
    return await get_payout_details(user=user)


@router.get("/withdrawals")
async def list_withdrawals(user=Depends(get_current_user)):
    try:
        return service.list_withdrawals(user["id"])
    except Exception as e:
        log.warning("wallet.withdrawals fallback (tables missing?): %s", e)
        return []


@router.post("/withdraw")
async def withdraw(
    body: WithdrawRequest,
    user=Depends(get_current_user),
):
    return service.request_withdrawal(user["id"], body.credits)


@router.get("/config")
async def config():
    """Minimal, public config the Wallet UI needs. Exposes the PUBLIC
    Razorpay key id so the frontend can open Checkout without another
    round-trip. `is_mock` tells the UI to skip opening Razorpay and
    auto-verify for local testing.
    """
    from app.config import settings
    return {
        "key_id": settings.razorpay_key_id if settings.razorpay_key_id else "mock",
        "is_mock": razorpay_client.is_mock(),
    }
