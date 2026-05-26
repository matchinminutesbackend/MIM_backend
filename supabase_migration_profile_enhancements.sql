-- Migration: Add college_university and workplace fields to profiles table
-- Feature: profile-enhancements
-- Date: 2026-05-03

-- Add new columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS college_university TEXT,
ADD COLUMN IF NOT EXISTS workplace TEXT;

-- No indexes needed as these are optional display fields
-- not used for filtering or searching

-- Rollback instructions (if needed):
-- ALTER TABLE public.profiles
-- DROP COLUMN IF EXISTS college_university,
-- DROP COLUMN IF EXISTS workplace;
