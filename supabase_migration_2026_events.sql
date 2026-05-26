-- ================================================================
-- MatchInMinutes — Telemetry / user events migration
-- ================================================================
-- Run ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Depends on: supabase_schema.sql (users)
--
-- A single append-only event table powers the "user detail" section
-- of the admin dashboard — payment attempts, paywall shown counts,
-- page visits, profile views, etc. Nothing here is critical-path;
-- writes fail silently on the client so a dropped event never breaks
-- a user's action.
-- ================================================================

-- Main event log. Keep this lean (five columns) — we rely on JSONB
-- `meta` to carry per-event shape without schema churn.
CREATE TABLE IF NOT EXISTS public.user_events (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        REFERENCES public.users(id) ON DELETE CASCADE,
  event       TEXT        NOT NULL,     -- see "Event taxonomy" below
  target_id   TEXT,                      -- stringified id of whatever the
                                         -- event is about (profile viewed,
                                         -- plan slug, order id, etc.)
  meta        JSONB       DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Queries are almost always "events for user X, newest first" or
-- "count of event Y in window". Two indexes cover both.
CREATE INDEX IF NOT EXISTS idx_user_events_user_time
  ON public.user_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_events_event_time
  ON public.user_events(event, created_at DESC);

-- ── Event taxonomy (client-driven) ───────────────────────────────
-- page_view           meta: { path, referrer? }
-- paywall_shown       meta: { kind: 'quota'|'calls', plans_surfaced? }
-- plans_viewed        — user visited subscription plans / upgrade screen
-- credits_viewed      — user visited wallet / credit packs screen
-- payment_started     meta: { kind: 'subscription'|'credits', slug?, amount_inr }
-- payment_success     meta: { kind, order_id, payment_id, amount_inr }
-- payment_failed      meta: { kind, order_id?, reason }
-- profile_viewed      target_id: viewed profile's user_id
-- profile_liked       target_id: liked profile's user_id
-- profile_passed      target_id: passed profile's user_id
-- message_sent        meta: { match_id, length }
-- call_started        meta: { match_id, media }
-- call_blocked        meta: { match_id, reason: 'calls_locked' }  (paywall hit on call)
-- gift_sent           target_id: gift slug, meta: { receiver_id, cost, context }
-- ================================================================
