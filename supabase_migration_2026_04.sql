-- ================================================================
-- MatchInMinutes — Incremental migration (April 2026)
-- ================================================================
-- Additive migration for the following features:
--   1. Face verification (is_verified, verification_image_url, cover_image_url)
--   2. Tinder-style profile details (DOB, zodiac, drinking, smoking, workout,
--      pets, children, diet, religion, languages, height_cm, first_date_idea)
--   3. Soft-delete ("Remove friend") on matches (removed_at, removed_by)
--   4. In-app notifications (invitations + message previews)
--
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run: every statement uses IF NOT EXISTS / IF EXISTS.
-- ================================================================

-- ── 1. PROFILES: verification + cover + Tinder-style fields ──────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified            BOOLEAN     DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_image_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cover_image_url        TEXT;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS date_of_birth          DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS zodiac_sign            TEXT;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS drinking               TEXT
  CHECK (drinking IS NULL OR drinking IN ('never','rarely','socially','often','prefer_not_to_say'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS smoking                TEXT
  CHECK (smoking IS NULL OR smoking IN ('never','socially','regularly','trying_to_quit','prefer_not_to_say'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS workout                TEXT
  CHECK (workout IS NULL OR workout IN ('never','sometimes','regularly','daily'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pets                   TEXT
  CHECK (pets IS NULL OR pets IN ('dog','cat','both','other','none','want_one'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS children               TEXT
  CHECK (children IS NULL OR children IN ('have_and_want_more','have_and_dont_want_more','want','dont_want','unsure'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS diet                   TEXT
  CHECK (diet IS NULL OR diet IN ('vegetarian','vegan','non_vegetarian','eggetarian','jain','other'));

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS religion               TEXT;
-- Expand the education CHECK to cover the richer list exposed in the UI.
-- Drop the old constraint (if present) and replace with the new allow-list.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_education_level_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_education_level_check
  CHECK (
    education_level IS NULL OR education_level IN (
      'less_than_high_school','high_school','some_college','associates',
      'diploma','trade_school','bachelors','postgraduate_diploma','masters',
      'professional','phd','postdoc','other'
    )
  );
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS languages              TEXT[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS height_cm              INTEGER
  CHECK (height_cm IS NULL OR (height_cm >= 120 AND height_cm <= 230));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS first_date_idea        TEXT
  CHECK (first_date_idea IS NULL OR char_length(first_date_idea) <= 300);

CREATE INDEX IF NOT EXISTS idx_profiles_is_verified ON public.profiles(is_verified);

-- ── 2. MATCHES: soft-delete for "Remove Friend" ──────────────────
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS removed_at  TIMESTAMPTZ;
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS removed_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_matches_removed ON public.matches(removed_at);

-- ── 3. NOTIFICATIONS ─────────────────────────────────────────────
-- Unified table: invitations (actionable) + new-message previews + other.
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL,   -- e.g. 'match_created', 'like_received', 'match_invitation', 'match_removed', 'message'
  actor_id    UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  match_id    UUID        REFERENCES public.matches(id)  ON DELETE CASCADE,
  payload     JSONB       DEFAULT '{}'::jsonb,
  is_read     BOOLEAN     DEFAULT FALSE,
  is_handled  BOOLEAN     DEFAULT FALSE,   -- set true when user accepts/declines an invitation
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_user_time   ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_user_unread ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notif_match       ON public.notifications(match_id);
