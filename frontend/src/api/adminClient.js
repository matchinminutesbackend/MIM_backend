// Admin API layer — separate from the consumer `api` so the admin SPA
// keeps its own JWT (localStorage key `admin_token`) and redirects to
// `/admin/login` on 401 instead of the user login screen.

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";

const TOKEN_KEY = "admin_token";

export function getAdminToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAdminToken(token) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export function clearAdminSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem("admin_user");
}

function qs(params) {
  const entries = Object.entries(params || {}).filter(
    ([, v]) => v !== undefined && v !== null && v !== ""
  );
  if (!entries.length) return "";
  return (
    "?" +
    entries
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&")
  );
}

async function request(path, options = {}) {
  const token = getAdminToken();
  const headers = { "Content-Type": "application/json", ...options.headers };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  if (res.status === 401) {
    clearAdminSession();
    // Avoid redirect loop when already on login screen.
    if (!window.location.pathname.startsWith("/admin/login")) {
      window.location.href = "/admin/login";
    }
    throw new Error("Admin session expired. Please sign in again.");
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: "Request failed" }));
    const msg =
      typeof err.detail === "string"
        ? err.detail
        : err.detail?.message || "Request failed";
    const e = new Error(msg);
    e.status = res.status;
    e.detail = err.detail;
    throw e;
  }

  // 204 etc.
  if (res.status === 204) return null;
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

export const adminApi = {
  // ── Auth ────────────────────────────────────────────
  login: (email, password) =>
    request("/admin/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),

  me: () => request("/admin/me"),

  // ── Stats ───────────────────────────────────────────
  stats: () => request("/admin/stats"),
  signupTrend: (days = 14) => request(`/admin/stats/signups${qs({ days })}`),

  // ── Users ───────────────────────────────────────────
  listUsers: ({ limit = 50, offset = 0, scope = "all", q = "" } = {}) =>
    request(`/admin/users${qs({ limit, offset, scope, q })}`),
  getUserDetail: (userId) => request(`/admin/users/${userId}/detail`),
  setUserActive: (userId, isActive) =>
    request(`/admin/users/${userId}/active`, {
      method: "PATCH",
      body: JSON.stringify({ is_active: isActive }),
    }),
  setUserAdmin: (userId, isAdmin) =>
    request(`/admin/users/${userId}/admin`, {
      method: "PATCH",
      body: JSON.stringify({ is_admin: isAdmin }),
    }),
  adjustCredits: (userId, delta, reason) =>
    request(`/admin/users/${userId}/credits`, {
      method: "POST",
      body: JSON.stringify({ delta, reason }),
    }),

  // ── Verifications ───────────────────────────────────
  listVerifications: ({ status = "pending", limit = 50 } = {}) =>
    request(`/admin/verifications${qs({ status, limit })}`),
  approveVerification: (userId) =>
    request(`/admin/verifications/${userId}/approve`, { method: "POST" }),
  rejectVerification: (userId, reason) =>
    request(`/admin/verifications/${userId}/reject`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    }),

  // ── Gifts ───────────────────────────────────────────
  listGifts: () => request("/admin/gifts"),
  updateGift: (giftId, patch) =>
    request(`/admin/gifts/${giftId}`, {
      method: "PATCH",
      body: JSON.stringify(patch),
    }),

  // ── Plans ───────────────────────────────────────────
  listPlans: () => request("/admin/plans"),
  updatePlan: (slug, monthlyInr) =>
    request(`/admin/plans/${slug}`, {
      method: "PATCH",
      body: JSON.stringify({ monthly_inr: monthlyInr }),
    }),

  // ── Withdrawals ─────────────────────────────────────
  listWithdrawals: ({ status = "", limit = 50 } = {}) =>
    request(`/admin/withdrawals${qs({ status, limit })}`),
  markWithdrawal: (id, { status, rzpPayoutId = null, reason = null }) =>
    request(`/admin/withdrawals/${id}`, {
      method: "PATCH",
      body: JSON.stringify({
        status,
        rzp_payout_id: rzpPayoutId,
        reason,
      }),
    }),

  // ── Settings ────────────────────────────────────────
  listSettings: () => request("/admin/settings"),
  updateSetting: (key, value) =>
    request("/admin/settings", {
      method: "PATCH",
      body: JSON.stringify({ key, value }),
    }),

  // ── Audit ───────────────────────────────────────────
  audit: (limit = 100) => request(`/admin/audit${qs({ limit })}`),

  // ── Advertisement ────────────────────────────────────
  getAd: () => request("/admin/ad"),
  saveAd: (linkUrl, file) => {
    const token = getAdminToken();
    const form = new FormData();
    form.append("link_url", linkUrl);
    if (file) form.append("file", file);
    return fetch(`${BASE_URL}/admin/ad`, {
      method: "POST",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: form,
    }).then(async (res) => {
      if (!res.ok) {
        const err = await res.json().catch(() => ({ detail: "Upload failed" }));
        throw new Error(typeof err.detail === "string" ? err.detail : "Upload failed");
      }
      return res.json();
    });
  },
  deleteAd: () => request("/admin/ad", { method: "DELETE" }),

  // ── Subscription grant ───────────────────────────────
  grantSubscription: (userId, plan, months, reason) =>
    request(`/admin/users/${userId}/grant-subscription`, {
      method: "POST",
      body: JSON.stringify({ plan, months, reason }),
    }),

  // ── Photo moderation ─────────────────────────────────
  deleteUserPhoto: (userId, imageId) =>
    request(`/admin/users/${userId}/photos/${imageId}`, { method: "DELETE" }),
};

export default adminApi;
