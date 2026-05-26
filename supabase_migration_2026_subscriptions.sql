-- ================================================================
-- MatchInMinutes — Subscriptions + daily quota migration
-- ================================================================
-- Run ONCE after supabase_migration_2026_billing.sql.
--
-- Model:
--   • Free (men):   10 likes/day + 30 passes/day (resets IST midnight)
--   • Free (women): unlimited — no rows ever written for them
--   • Premium:      unlimited likes + passes for the subscription window
--
-- Economics: ₹199 (1mo) / ₹537 (3mo @ ₹179) / ₹894 (6mo @ ₹149) upfront
-- via Razorpay. Women never see the paywall.
-- ================================================================

-- ── Subscriptions ────────────────────────────────────────────────
-- One row per purchased window. We keep history (don't UPSERT) so
-- renewals, refunds and dispute replies can reference the exact order.
-- `expires_at` is the authoritative end — backend just checks NOW() < expires_at.
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan            TEXT        NOT NULL CHECK (plan IN ('monthly', 'quarterly', 'halfyearly')),
  months          INTEGER     NOT NULL CHECK (months IN (1, 3, 6)),
  -- Price is snapshotted at purchase so changing the catalog later
  -- doesn't mutate past invoices.
  inr_paise       INTEGER     NOT NULL CHECK (inr_paise > 0),
  starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL,
  status          TEXT        NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'expired', 'refunded', 'cancelled')),
  razorpay_order_id   TEXT    UNIQUE,
  razorpay_payment_id TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Fast "is this user premium right now?" lookup. Covers the common
-- case of one active sub; the partial index keeps it tiny.
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_active
  ON public.subscriptions (user_id, expires_at DESC)
  WHERE status = 'active';


-- ── Daily quota ──────────────────────────────────────────────────
-- Counter rows, one per (user, date). Much cheaper than counting
-- match_interactions every request and lets us reset by just dropping
-- the row — no UPDATE storm at midnight.
--
-- `quota_date` is an IST calendar date (we compute it in Python to
-- avoid Postgres timezone config drift).
CREATE TABLE IF NOT EXISTS public.daily_quota (
  user_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  quota_date    DATE        NOT NULL,
  hearts_used   INTEGER     NOT NULL DEFAULT 0,
  passes_used   INTEGER     NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, quota_date)
);

-- Cleanup old quota rows (>30 days) can be a cron. Not enforced in SQL
-- — the PK lookup by (user_id, today) stays fast regardless.
