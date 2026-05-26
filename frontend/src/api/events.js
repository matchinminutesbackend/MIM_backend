// Fire-and-forget telemetry client. Calls POST /events with the user's
// access token. Designed to be cheap to call — errors never propagate.
//
// Usage:
//   import { track, EVENTS } from "../api/events";
//   track(EVENTS.PLANS_VIEWED);
//   track(EVENTS.PAYMENT_STARTED, { kind: "subscription", slug: "pro_monthly", amount_inr: 399 });
//   track(EVENTS.PROFILE_VIEWED, null, targetUserId);

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";

export const EVENTS = {
  PAGE_VIEW:        "page_view",
  PAYWALL_SHOWN:    "paywall_shown",
  PLANS_VIEWED:     "plans_viewed",
  CREDITS_VIEWED:   "credits_viewed",
  PAYMENT_STARTED:  "payment_started",
  PAYMENT_SUCCESS:  "payment_success",
  PAYMENT_FAILED:   "payment_failed",
  PROFILE_VIEWED:   "profile_viewed",
  PROFILE_LIKED:    "profile_liked",
  PROFILE_PASSED:   "profile_passed",
  MESSAGE_SENT:     "message_sent",
  CALL_STARTED:     "call_started",
  CALL_BLOCKED:     "call_blocked",
  GIFT_SENT:        "gift_sent",
};

// De-dupe burst calls of the same event in the same tick so a hook
// that fires every render doesn't spam the table.
const _recent = new Map();
const DEDUPE_MS = 800;

export function track(event, meta = null, targetId = null) {
  if (!event) return;
  const token = localStorage.getItem("access_token");
  if (!token) return;

  const key = `${event}:${targetId || ""}:${JSON.stringify(meta || {})}`;
  const now = Date.now();
  const last = _recent.get(key) || 0;
  if (now - last < DEDUPE_MS) return;
  _recent.set(key, now);
  // Cheap GC so the Map doesn't grow forever.
  if (_recent.size > 200) {
    for (const [k, t] of _recent) {
      if (now - t > 30_000) _recent.delete(k);
    }
  }

  try {
    fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        event,
        target_id: targetId || null,
        meta: meta || {},
      }),
      keepalive: true, // survive page navigation / tab close
    }).catch(() => {});
  } catch {
    /* never throw from telemetry */
  }
}

export default track;
