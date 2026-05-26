-- ================================================================
-- MatchInMinutes — Matrimony + Profile Enhancements Migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
--
-- This migration adds:
--   1. workplace & college_university columns
--   2. caste, sub_caste, sub_religion, annual_income columns
--   3. Expands relationship_goal CHECK to allow 'serious_marriage'
-- ================================================================

-- 1. Add workplace & college/university columns (from profile enhancements)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS workplace TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS college_university TEXT;

-- 2. Add the new matrimony columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS caste TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sub_caste TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sub_religion TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS annual_income TEXT;

-- 3. Update the relationship_goal CHECK constraint to include 'serious_marriage'
--    The original constraint only allows: long_term, short_term, marriage,
--    friendship, casual, unsure — inserting 'serious_marriage' would fail.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_relationship_goal_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_relationship_goal_check
  CHECK (
    relationship_goal IS NULL OR relationship_goal IN (
      'long_term','short_term','marriage','serious_marriage',
      'friendship','casual','unsure'
    )
  );
