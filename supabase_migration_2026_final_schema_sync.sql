-- ================================================================
-- MatchInMinutes — Final Schema Sync Migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- 
-- This migration fills in the final missing schema pieces required
-- by the backend:
-- 1. Google Auth support in the users table
-- 2. Admin moderation (ban) fields in the profiles table
-- 3. The reports table for user complaints
-- ================================================================

-- ── 1. Fix Users Table for Google Auth ───────────────────────────
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
ALTER TABLE public.users ALTER COLUMN password_hash DROP NOT NULL;

-- ── 2. Add Ban Fields to Profiles ────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_reason TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_expires_at TIMESTAMPTZ;

-- ── 3. Create Reports Table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for admin dashboard queries
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created ON public.reports(created_at DESC);
