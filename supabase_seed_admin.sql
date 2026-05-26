-- ================================================================
-- MatchInMinutes — Seed the first admin account
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- PREREQUISITES (must be run first, in order):
--   1. supabase_schema.sql
--   2. supabase_migration_2026_04.sql
--   3. supabase_migration_2026_wallet.sql
--   4. supabase_migration_2026_admin.sql   ← this adds users.is_admin
--
-- Creates the first admin user so you can sign in to /admin/login
-- without going through the consumer signup flow.
--
--   Email:    admin@matchinminutes.com
--   Password: Admin@MIM2025
--
-- Change the password after first login by updating password_hash
-- (or by plugging a password-reset flow into the admin console later).
-- ================================================================

INSERT INTO public.users (name, email, password_hash, is_active, is_admin)
VALUES (
  'Platform Admin',
  'admin@matchinminutes.com',
  -- bcrypt hash of 'Admin@MIM2025'
  '$2b$12$QmiSitrwItwUReuZWSSMheWPgNoXpyT2Z4ew1B7Bc1vq9iVv3HTVi',
  TRUE,
  TRUE
)
ON CONFLICT (email) DO UPDATE
  SET is_admin      = TRUE,
      is_active     = TRUE,
      password_hash = EXCLUDED.password_hash,
      name          = EXCLUDED.name;

-- Verify
SELECT id, email, name, is_admin, is_active, created_at
  FROM public.users
 WHERE email = 'admin@matchinminutes.com';
