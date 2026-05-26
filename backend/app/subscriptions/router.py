"""Subscriptions API — premium plans + quota status.

Routes (all under /subscriptions):
  GET  /me                → { premium, plan, expires_at, quota: {...} }
  GET  /plans             → catalogue (plans + free quotas)
  POST /purchase/order    → Razorpay order for a plan
  POST /purchase/verify   → signature check + activate

The UI polls /me once per Discover view so the quota chip stays fresh
without a background worker.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.subscriptions import service
from app.wallet import razorpay_client

log = logging.getLogger(__name__)

router = APIRouter()


class PlanOrderRequest(BaseModel):
    plan: str  # one of the six slugs in service.PLANS


class PlanVerifyRequest(BaseModel):
    order_id: str
    payment_id: str
    signature: str
    plan: str


@router.get("/me")
async def me(user=Depends(get_current_user)):
    """One-shot status call for the client: am I premium, what's my
    quota, and (if premium) when does it expire.

    Safe-fallback to free-tier defaults if tables don't exist yet.
    """
    try:
        sub = service.get_active_subscription(user["id"])
        quota = service.get_quota_status(user["id"])
        female = service.is_female(user["id"])
    except Exception as e:
        log.warning("subscriptions.me fallback (tables missing?): %s", e)
        return {
            "premium": False, "plan": None, "tier": None, "expires_at": None,
            "female": False, "can_call": False,
            "quota": {
                "gated": True, "reason": "free",
                "hearts_used": 0, "passes_used": 0,
                "hearts_limit": service.FREE_HEARTS_PER_DAY,
                "passes_limit": service.FREE_PASSES_PER_DAY,
            },
        }

    tier = service.tier_of(sub["plan"]) if sub else None
    # Women get calling for free, same as every other feature.
    can_call = female or tier == "pro"
    return {
        "premium":     sub is not None,      # True for Plus OR Pro
        "plan":        sub["plan"] if sub else None,
        "tier":        tier,                 # 'plus' | 'pro' | None
        "months":      sub["months"] if sub else None,
        "expires_at":  sub["expires_at"] if sub else None,
        "female":      female,
        "can_call":    can_call,
        "quota":       quota,
    }


@router.get("/plans")
async def plans():
    """Public plan catalogue. Exposed so the paywall can render without
    hitting /me first (and so we can SEO the pricing page later).
    """
    return {
        "plans": service._effective_plans(),
        "free_hearts_per_day": service.FREE_HEARTS_PER_DAY,
        "free_passes_per_day": service.FREE_PASSES_PER_DAY,
    }


@router.post("/purchase/order")
async def create_order(
    body: PlanOrderRequest,
    user=Depends(get_current_user),
):
    return service.create_subscription_order(user["id"], body.plan)


@router.post("/purchase/verify")
async def verify(
    body: PlanVerifyRequest,
    user=Depends(get_current_user),
):
    sub = service.verify_and_activate(
        user["id"], body.order_id, body.payment_id, body.signature, body.plan
    )
    return {
        "premium":    True,
        "plan":       sub["plan"],
        "expires_at": sub["expires_at"],
    }
