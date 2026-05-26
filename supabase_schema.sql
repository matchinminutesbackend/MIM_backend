-- ================================================================
-- MatchInMinutes — Complete Database Schema
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
--
-- ⚠️  Tables are NOT created automatically when you start the backend.
--     You MUST run this SQL in Supabase before the first launch.
--
-- To reset everything: uncomment the DROP TABLE lines below first.
-- ================================================================

-- DROP TABLE IF EXISTS public.messages           CASCADE;
-- DROP TABLE IF EXISTS public.matches            CASCADE;
-- DROP TABLE IF EXISTS public.match_interactions CASCADE;
-- DROP TABLE IF EXISTS public.profile_images     CASCADE;
-- DROP TABLE IF EXISTS public.profiles           CASCADE;
-- DROP TABLE IF EXISTS public.users              CASCADE;

-- ── 1. USERS  (custom auth – NO Supabase Auth used) ──────────────
-- Supabase is used ONLY as a Postgres database here.
-- Auth (passwords, JWT) is handled 100% in the FastAPI backend.
CREATE TABLE IF NOT EXISTS public.users (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT        NOT NULL,
  email         TEXT        UNIQUE NOT NULL,
  phone_number  TEXT,
  password_hash TEXT        NOT NULL,
  is_active     BOOLEAN     DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. PROFILES  (dating profile, completed after signup) ────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id               UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  name             TEXT        NOT NULL,
  age              INTEGER     NOT NULL CHECK (age >= 18 AND age <= 100),
  gender           TEXT        NOT NULL CHECK (gender IN ('male','female','non_binary','prefer_not_to_say')),
  preferred_gender TEXT        NOT NULL CHECK (preferred_gender IN ('male','female','non_binary','prefer_not_to_say')),
  city             TEXT        NOT NULL,
  country          TEXT        NOT NULL,
  relationship_goal TEXT       NOT NULL CHECK (relationship_goal IN ('long_term','short_term','marriage','friendship','casual','unsure')),
  phone_number     TEXT,
  education_level  TEXT        CHECK (education_level IN ('high_school','diploma','bachelors','masters','phd','other')),
  occupation       TEXT,
  bio              TEXT        CHECK (char_length(bio) <= 500),
  hobbies          TEXT[]      DEFAULT '{}',
  vibes            TEXT[]      DEFAULT '{}',
  relationship_status TEXT     CHECK (relationship_status IN ('single','divorced','widowed','separated')),
  main_image_url   TEXT,
  is_complete      BOOLEAN     DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. PROFILE IMAGES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile_images (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  image_url   TEXT        NOT NULL,
  is_main     BOOLEAN     DEFAULT FALSE,
  order_index INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. MATCH INTERACTIONS  (like / pass) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.match_interactions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action      TEXT        NOT NULL CHECK (action IN ('like','pass')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (actor_id, target_id)
);

-- ── 5. MATCHES  (mutual likes) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.matches (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user2_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user1_id, user2_id)
);

-- ── 6. MESSAGES  (only between matched users) ────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id    UUID        NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id   UUID        NOT NULL REFERENCES public.users(id)   ON DELETE CASCADE,
  content     TEXT        NOT NULL CHECK (char_length(content) >= 1 AND char_length(content) <= 2000),
  is_read     BOOLEAN     DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── TRIGGER: auto-update profiles.updated_at ─────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── INDEXES ──────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_users_email          ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_profiles_gender      ON public.profiles(gender, preferred_gender);
CREATE INDEX IF NOT EXISTS idx_profiles_city        ON public.profiles(city);
CREATE INDEX IF NOT EXISTS idx_profiles_complete    ON public.profiles(is_complete);
CREATE INDEX IF NOT EXISTS idx_images_user          ON public.profile_images(user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_actor   ON public.match_interactions(actor_id);
CREATE INDEX IF NOT EXISTS idx_interactions_target  ON public.match_interactions(target_id);
CREATE INDEX IF NOT EXISTS idx_matches_user1        ON public.matches(user1_id);
CREATE INDEX IF NOT EXISTS idx_matches_user2        ON public.matches(user2_id);
CREATE INDEX IF NOT EXISTS idx_messages_match_time  ON public.messages(match_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender      ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread      ON public.messages(match_id, is_read, sender_id);

-- ── STORAGE BUCKET ───────────────────────────────────────────────
-- Run separately in Supabase Dashboard → Storage → New Bucket
--   Name: profile-images   Public: ✅ yes
-- Or via SQL:
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-images', 'profile-images', true)
ON CONFLICT (id) DO NOTHING;

-- ── NOTE ON ROW LEVEL SECURITY ───────────────────────────────────
-- RLS is NOT enabled. The backend uses the service_role key which
-- bypasses RLS anyway. All access control is enforced in FastAPI.
-- Enable RLS + policies later if you add direct client DB access.
