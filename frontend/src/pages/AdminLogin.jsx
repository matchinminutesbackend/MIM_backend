import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Mail, Lock, Eye, EyeOff, ShieldCheck, Loader2 } from "lucide-react";
import {
  adminApi,
  setAdminToken,
  getAdminToken,
  clearAdminSession,
} from "../api/adminClient";

/**
 * AdminLogin — gated entry to the admin dashboard.
 *
 * Visually distinct from the consumer Login (no illustration, no Google SSO)
 * so nobody stumbles in by accident. Only accounts with users.is_admin = TRUE
 * can mint a token here; the backend returns 403 otherwise.
 */
export default function AdminLogin() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: "", password: "" });
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // If a valid admin token is already present, skip the form.
  useEffect(() => {
    let cancelled = false;
    const token = getAdminToken();
    if (!token) return;
    adminApi
      .me()
      .then(() => {
        if (!cancelled) navigate("/admin", { replace: true });
      })
      .catch(() => {
        // Stale / revoked token — scrub and stay on the form.
        clearAdminSession();
      });
    return () => {
      cancelled = true;
    };
  }, [navigate]);

  async function handleSubmit(e) {
    e.preventDefault();
    if (loading) return;
    setError("");
    setLoading(true);
    try {
      const res = await adminApi.login(form.email.trim(), form.password);
      setAdminToken(res.access_token);
      localStorage.setItem(
        "admin_user",
        JSON.stringify({ id: res.user_id, email: res.email, name: res.name })
      );
      navigate("/admin", { replace: true });
    } catch (err) {
      setError(err.message || "Unable to sign in");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center px-6 py-12">
      <div className="w-full max-w-md">
        {/* Header — badge + title */}
        <div className="mb-10 text-center">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-slate-800 border border-slate-700 mb-4">
            <ShieldCheck className="w-6 h-6 text-pink-400" />
          </div>
          <h1 className="text-2xl font-semibold tracking-tight">
            MatchInMinutes · Admin Console
          </h1>
          <p className="mt-2 text-sm text-slate-400">
            Restricted area. Sign in with your authorized admin account.
          </p>
        </div>

        {/* Card */}
        <form
          onSubmit={handleSubmit}
          className="rounded-2xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-7 space-y-5 shadow-2xl"
        >
          {error ? (
            <div className="rounded-lg border border-red-900/60 bg-red-950/50 text-red-200 text-sm px-3 py-2">
              {error}
            </div>
          ) : null}

          <label className="block">
            <span className="text-xs font-medium text-slate-400 uppercase tracking-wider">
              Work Email
            </span>
            <div className="mt-1.5 relative">
              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                type="email"
                required
                autoComplete="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                placeholder="you@matchinminutes.com"
                className="w-full rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm pl-9 pr-3 py-2.5 placeholder-slate-600"
              />
            </div>
          </label>

          <label className="block">
            <span className="text-xs font-medium text-slate-400 uppercase tracking-wider">
              Password
            </span>
            <div className="mt-1.5 relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                type={showPwd ? "text" : "password"}
                required
                autoComplete="current-password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                placeholder="••••••••"
                className="w-full rounded-lg bg-slate-950 border border-slate-800 focus:border-pink-500 focus:ring-1 focus:ring-pink-500/40 outline-none text-sm pl-9 pr-10 py-2.5 placeholder-slate-600"
              />
              <button
                type="button"
                onClick={() => setShowPwd((v) => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
                aria-label={showPwd ? "Hide password" : "Show password"}
              >
                {showPwd ? (
                  <EyeOff className="w-4 h-4" />
                ) : (
                  <Eye className="w-4 h-4" />
                )}
              </button>
            </div>
          </label>

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-lg bg-pink-600 hover:bg-pink-500 text-white font-medium py-2.5 text-sm transition-colors flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                Signing in…
              </>
            ) : (
              "Sign in to Console"
            )}
          </button>

          <p className="text-[11px] text-slate-500 leading-relaxed text-center">
            All actions in the admin console are logged. Access is limited to
            authorized MatchInMinutes personnel.
          </p>
        </form>

        <p className="text-center text-xs text-slate-600 mt-6">
          © {new Date().getFullYear()} MatchInMinutes — Internal tools
        </p>
      </div>
    </div>
  );
}
