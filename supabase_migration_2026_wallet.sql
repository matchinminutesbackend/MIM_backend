-- ================================================================
-- MatchInMinutes — Credits / Wallet / Gifts migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Depends on: supabase_schema.sql (users, profiles, matches tables)
--
-- Adds:
--   • wallets              — one row per user, tracks credit balance
--   • credit_transactions  — audit ledger: purchases, gifts, withdrawals, bonus
--   • gifts                — catalog of giftable items (seeded below)
--   • gift_sends           — one row per gift sent, visible in chat/invite
--   • withdrawal_requests  — user-requested payouts (pending/processing/paid)
--   • payout_details       — UPI / bank details for Razorpay X payouts
--
-- Economics (enforced in backend service layer, not DB):
--   • 1 credit = ₹1 on purchase
--   • Receiver keeps 70% of gift cost as credits
--   • 1 credit = ₹0.70 on cash-out
--   • Min purchase 50 credits, min withdrawal 500 credits
--   • Signup bonus 20 credits after profile complete + face verified
-- ================================================================

-- ── 1. WALLETS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id       UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  balance       INTEGER     NOT NULL DEFAULT 0 CHECK (balance >= 0),
  lifetime_earned  INTEGER  NOT NULL DEFAULT 0,  -- total credits ever received (for stats)
  lifetime_spent   INTEGER  NOT NULL DEFAULT 0,  -- total credits ever spent on gifts
  signup_bonus_granted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. CREDIT TRANSACTIONS (audit ledger) ────────────────────────
-- Every credit movement lands here. `delta` is signed (+ credit, – debit).
-- `kind` discriminates the source; `ref_id` links to gift_sends /
-- razorpay order id / withdrawal_requests.id depending on kind.
CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kind          TEXT        NOT NULL CHECK (kind IN (
                    'purchase',         -- + credits from Razorpay payment
                    'signup_bonus',     -- + 20 credits after profile + face verify
                    'gift_sent',        -- – credits (sender pays gift.cost)
                    'gift_received',    -- + credits (receiver gets 70% of gift.cost)
                    'gift_refund',      -- + credits (invite declined, 50% refund to sender)
                    'withdrawal_hold',  -- – credits (reserved when withdrawal requested)
                    'withdrawal_refund',-- + credits (withdrawal rejected, credits returned)
                    'admin_adjust'      -- +/– credits (manual admin correction)
                )),
  delta         INTEGER     NOT NULL,
  balance_after INTEGER     NOT NULL,   -- snapshot for audit
  ref_id        TEXT,                    -- razorpay order_id / gift_sends.id / withdrawal_requests.id
  meta          JSONB       DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ctxn_user_time ON public.credit_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ctxn_kind      ON public.credit_transactions(kind);
CREATE INDEX IF NOT EXISTS idx_ctxn_ref       ON public.credit_transactions(ref_id);

-- ── 3. GIFTS CATALOG ─────────────────────────────────────────────
-- Seeded below. `is_active` lets admins retire items without losing
-- historical references in gift_sends.
CREATE TABLE IF NOT EXISTS public.gifts (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          TEXT        UNIQUE NOT NULL,
  name          TEXT        NOT NULL,
  icon          TEXT        NOT NULL,   -- emoji or asset key
  cost          INTEGER     NOT NULL CHECK (cost >= 30),  -- floor set by product rules
  tier          TEXT        NOT NULL CHECK (tier IN ('common','rare','epic','legendary')),
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  sort_order    INTEGER     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. GIFT SENDS ────────────────────────────────────────────────
-- One row per gift sent. `context` = 'invite' (attached to a match
-- invitation) or 'chat' (inside an open conversation).
-- `status` tracks the lifecycle for invite-context gifts which can be
-- declined (→ partial refund) before they ever reach the recipient.
CREATE TABLE IF NOT EXISTS public.gift_sends (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_id         UUID        NOT NULL REFERENCES public.gifts(id),
  sender_id       UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id     UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  context         TEXT        NOT NULL CHECK (context IN ('invite','chat')),
  match_id        UUID        REFERENCES public.matches(id) ON DELETE SET NULL,
  message_id      UUID        REFERENCES public.messages(id) ON DELETE SET NULL,
  cost            INTEGER     NOT NULL,  -- snapshot of gifts.cost at send time
  receiver_share  INTEGER     NOT NULL,  -- snapshot of 70% payout
  status          TEXT        NOT NULL DEFAULT 'delivered' CHECK (status IN (
                    'delivered',   -- receiver got their credits (chat context, or accepted invite)
                    'pending',     -- invite context awaiting accept/decline
                    'refunded'     -- invite declined, sender refunded 50%
                  )),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gift_sends_sender   ON public.gift_sends(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_sends_receiver ON public.gift_sends(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_sends_match    ON public.gift_sends(match_id);

-- ── 5. PAYOUT DETAILS ────────────────────────────────────────────
-- UPI is the default in India; bank account is the fallback. Stored
-- one row per user and reused across withdrawals.
CREATE TABLE IF NOT EXISTS public.payout_details (
  user_id         UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  method          TEXT        NOT NULL CHECK (method IN ('upi','bank')),
  -- UPI
  upi_id          TEXT,
  -- Bank
  account_name    TEXT,
  account_number  TEXT,
  ifsc            TEXT,
  -- Razorpay X bookkeeping
  rzp_contact_id      TEXT,
  rzp_fund_account_id TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── 6. WITHDRAWAL REQUESTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  credits         INTEGER     NOT NULL CHECK (credits >= 500),
  inr_paise       INTEGER     NOT NULL,              -- ₹0.70/credit × credits × 100
  status          TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN (
                    'pending','processing','paid','rejected','cancelled'
                  )),
  rzp_payout_id   TEXT,       -- Razorpay X payout id once initiated
  failure_reason  TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_withdrawals_user   ON public.withdrawal_requests(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON public.withdrawal_requests(status);

-- ── 7. SEED GIFT CATALOG ─────────────────────────────────────────
INSERT INTO public.gifts (slug, name, icon, cost, tier, sort_order) VALUES
  ('rose',      'Rose',      '🌹', 30,   'common',    1),
  ('chocolate', 'Chocolate', '🍫', 50,   'common',    2),
  ('teddy',     'Teddy',     '🧸', 100,  'rare',      3),
  ('bouquet',   'Bouquet',   '💐', 200,  'rare',      4),
  ('ring',      'Ring',      '💍', 500,  'epic',      5),
  ('diamond',   'Diamond',   '💎', 1000, 'legendary', 6)
ON CONFLICT (slug) DO UPDATE
  SET name       = EXCLUDED.name,
      icon       = EXCLUDED.icon,
      cost       = EXCLUDED.cost,
      tier       = EXCLUDED.tier,
      sort_order = EXCLUDED.sort_order;

-- ── 8. BACKFILL WALLETS FOR EXISTING USERS ───────────────────────
-- Create a zero-balance wallet for every user who doesn't have one yet.
-- Signup bonus is NOT granted here — it only fires when the user also
-- has profile.is_verified = TRUE (enforced in the backend service).
INSERT INTO public.wallets (user_id, balance)
SELECT u.id, 0
  FROM public.users u
  LEFT JOIN public.wallets w ON w.user_id = u.id
 WHERE w.user_id IS NULL;

-- ── 9. MESSAGE → GIFT LINK ───────────────────────────────────────
-- Lets chat messages render as gift cards by pointing at a gift_sends row.
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS gift_send_id UUID
  REFERENCES public.gift_sends(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_messages_gift_send ON public.messages(gift_send_id);
