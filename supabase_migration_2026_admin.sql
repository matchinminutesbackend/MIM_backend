-- ================================================================
-- MatchInMinutes — Admin Dashboard migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Depends on: supabase_schema.sql (users, profiles)
--             supabase_migration_2026_wallet.sql (gifts, withdrawal_requests)
--
-- Adds:
--   • users.is_admin                — flag that unlocks /admin endpoints
--   • admin_audit_log               — who did what, for every admin action
--   • app_settings                  — key/value table for tunables
--                                     (commission rate, withdrawal floor, etc.)
--   • profiles.verification_status  — pending | approved | rejected | none
--   • profiles.verification_note    — rejection reason surfaced to the user
-- ================================================================

-- ── 1. ADMIN FLAG ─────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_users_is_admin ON public.users(is_admin) WHERE is_admin = TRUE;

-- ── 2. VERIFICATION WORKFLOW ──────────────────────────────────────
-- We used to auto-approve selfies on upload. The admin dashboard
-- introduces a review queue — status stays `pending` until a human
-- clicks approve/reject. `is_verified` stays as a derived convenience
-- flag, set by the service layer when status flips to `approved`.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS verification_status TEXT
    NOT NULL DEFAULT 'none'
    CHECK (verification_status IN ('none', 'pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_reviewed_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_reviewed_by  UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS verification_note         TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_verif_status
  ON public.profiles(verification_status)
  WHERE verification_status = 'pending';

-- Backfill — any existing verified rows become 'approved', everything
-- else stays 'none' (users never uploaded) or if they uploaded but
-- weren't flipped yet, we leave them as 'none' so they can re-upload.
UPDATE public.profiles
   SET verification_status = 'approved'
 WHERE is_verified = TRUE
   AND verification_status = 'none';

-- ── 3. ADMIN AUDIT LOG ────────────────────────────────────────────
-- Every admin mutation lands here. Read-only queries are NOT logged.
-- `action` is a free-form string like 'user.disable', 'gift.price_update',
-- 'verification.approve', 'withdrawal.mark_paid', etc.
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    UUID        NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  action      TEXT        NOT NULL,
  target_type TEXT,                                  -- 'user' | 'gift' | 'plan' | 'withdrawal' | 'settings'
  target_id   TEXT,                                  -- stringified PK (UUIDs or slugs)
  meta        JSONB       DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_admin_time ON public.admin_audit_log(admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_target     ON public.admin_audit_log(target_type, target_id);

-- ── 4. APP SETTINGS (key/value tunables) ──────────────────────────
-- Avoids redeploys for knob changes. Seeded with the product's defaults
-- so the admin UI can render the current values right away.
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         TEXT        PRIMARY KEY,
  value       JSONB       NOT NULL,
  description TEXT,
  updated_by  UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.app_settings (key, value, description) VALUES
  ('commission.gift_platform_share', '0.30',
    'Platform share on chat gifts — receiver gets 1 − this. Matches gifts.service.GIFT_RECEIVER_SHARE.'),
  ('commission.gift_refund_share',   '0.50',
    'Refund fraction returned to sender when an invite gift is declined.'),
  ('commission.payout_rate_inr',     '0.70',
    'INR value per credit on cash-out. UI shows this on the withdrawal screen.'),
  ('withdrawal.min_credits',         '500',
    'Minimum credits a user must hold to request a withdrawal.')
ON CONFLICT (key) DO NOTHING;

-- ── 5. SUBSCRIPTION PLAN OVERRIDES ────────────────────────────────
-- The PLANS catalogue lives in code for speed, but admins need to
-- tweak prices without a redeploy. This table lets them override
-- `monthly_inr` per plan slug; the service layer applies the override
-- on read. An empty row means "use the code default".
CREATE TABLE IF NOT EXISTS public.plan_overrides (
  slug         TEXT        PRIMARY KEY,
  monthly_inr  INTEGER     NOT NULL CHECK (monthly_inr > 0),
  updated_by   UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 6. HOW TO BOOTSTRAP THE FIRST ADMIN ───────────────────────────
-- After running this migration, promote yourself manually:
--
--   UPDATE public.users SET is_admin = TRUE WHERE email = 'you@matchinminutes.com';
--
-- Every subsequent admin can be flipped from the dashboard.
