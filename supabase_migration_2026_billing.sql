-- ================================================================
-- MatchInMinutes — Billing Details migration
-- ================================================================
-- Run ONCE after supabase_migration_2026_wallet.sql.
--
-- Captures the billing info Razorpay needs on every real checkout
-- (name / phone / email / address). Stored once per user and reused
-- on subsequent purchases so the checkout feels one-click.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.billing_details (
  user_id         UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  name            TEXT        NOT NULL,
  email           TEXT        NOT NULL,
  phone           TEXT        NOT NULL,
  address_line1   TEXT        NOT NULL,
  address_line2   TEXT,
  city            TEXT        NOT NULL,
  state           TEXT        NOT NULL,
  pincode         TEXT        NOT NULL,
  country         TEXT        NOT NULL DEFAULT 'IN',
  -- Snapshot of the last Razorpay order that used this record — handy
  -- for reconciling disputes but not critical.
  last_order_id   TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
