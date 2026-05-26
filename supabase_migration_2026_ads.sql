-- ================================================================
-- MatchInMinutes — Advertisement migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================

CREATE TABLE IF NOT EXISTS public.advertisements (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url   TEXT        NOT NULL,
  link_url    TEXT        NOT NULL,
  is_active   BOOLEAN     DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── TRIGGER: auto-update updated_at ─────────────────────────────
DROP TRIGGER IF EXISTS advertisements_updated_at ON public.advertisements;
CREATE TRIGGER advertisements_updated_at
  BEFORE UPDATE ON public.advertisements
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── INDEX ───────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_advertisements_active ON public.advertisements(is_active);
