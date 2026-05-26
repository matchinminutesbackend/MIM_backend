import { useState, useEffect, useRef } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth, loadGoogleScript, GOOGLE_CLIENT_ID } from "../context/AuthContext";
import { Mail, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";
import PhoneCollageBg from "../components/PhoneCollageBg";
import BrandLogo from "../components/BrandLogo";

export default function Login() {
  const { login, googleSignIn } = useAuth();
  const navigate = useNavigate();
  const googleBtnRef = useRef(null);
  const [form, setForm] = useState({ email: "", password: "" });
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const { profile } = await login(form.email, form.password);
      navigate(profile?.is_complete ? "/dashboard" : "/signup");
    } catch (err) {
      setError(err.message || "Invalid email or password");
    } finally {
      setLoading(false);
    }
  }

  // Mount the Google Sign-In button once the GSI script is ready.
  useEffect(() => {
    let cancelled = false;
    loadGoogleScript()
      .then((google) => {
        if (cancelled || !googleBtnRef.current) return;
        google.accounts.id.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: async (resp) => {
            setError("");
            setLoading(true);
            try {
              const result = await googleSignIn(resp.credential);
              navigate(result.is_complete ? "/dashboard" : "/signup");
            } catch (err) {
              setError(err.message || "Google sign-in failed");
            } finally {
              setLoading(false);
            }
          },
        });
        google.accounts.id.renderButton(googleBtnRef.current, {
          theme: "outline",
          size: "large",
          width: googleBtnRef.current.offsetWidth || 360,
          text: "signin_with",
          shape: "rectangular",
        });
      })
      .catch(() => setError("Couldn't load Google sign-in. Please check your connection."));
    return () => { cancelled = true; };
  }, [googleSignIn, navigate]);

  return (
    <div className="min-h-screen flex">
      {/* Left panel — Tinder-style phone collage backdrop, no hero copy */}
      <div className="hidden lg:flex flex-1 relative overflow-hidden">
        <PhoneCollageBg />
      </div>

      {/* Right panel */}
      <div className="flex-1 flex items-center justify-center bg-white px-6 py-12">
        <div className="w-full max-w-md">
          {/* Logo — heart-M wordmark on the white side, dark text */}
          <Link to="/" className="inline-flex mb-10">
            <BrandLogo variant="full" size="lg" tone="dark" />
          </Link>

          <h2 className="text-3xl font-bold text-gray-900 mb-2">Welcome back</h2>
          <p className="text-gray-500 mb-8">Sign in to continue your journey</p>

          {error && (
            <div className="mb-5 flex items-start gap-2.5 p-4 bg-red-50 border border-red-200 rounded-xl text-red-600 text-sm">
              <span className="text-base">⚠️</span> {error}
            </div>
          )}

          {/* Google Sign-In */}
          <div className="mb-5">
            <div ref={googleBtnRef} className="w-full flex justify-center min-h-[44px]" />
          </div>

          <div className="flex items-center gap-3 mb-5">
            <div className="flex-1 h-px bg-gray-200" />
            <span className="text-xs text-gray-400 font-medium uppercase tracking-wide">or continue with email</span>
            <div className="flex-1 h-px bg-gray-200" />
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Email address</label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                <input
                  type="email" required autoComplete="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  placeholder="you@example.com"
                  className="w-full border border-gray-200 rounded-xl pl-11 pr-4 py-3.5 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-sm font-medium text-gray-700">Password</label>
                <button type="button" className="text-xs text-pink-600 hover:text-pink-700 font-medium">
                  Forgot password?
                </button>
              </div>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                <input
                  type={showPwd ? "text" : "password"} required autoComplete="current-password"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  placeholder="••••••••"
                  className="w-full border border-gray-200 rounded-xl pl-11 pr-12 py-3.5 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-transparent transition text-sm"
                />
                <button type="button" onClick={() => setShowPwd(!showPwd)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                  {showPwd ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <input type="checkbox" id="remember" className="w-4 h-4 accent-pink-500 rounded" />
              <label htmlFor="remember" className="text-sm text-gray-600">Remember me for 30 days</label>
            </div>

            <button
              type="submit" disabled={loading}
              className="w-full flex items-center justify-center gap-2 py-3.5 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold hover:from-pink-600 hover:to-pink-700 transition disabled:opacity-60 text-sm shadow-lg shadow-pink-200"
            >
              {loading ? (
                <span className="flex items-center gap-2"><span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> Signing in…</span>
              ) : (
                <><span>Sign In</span> <ArrowRight size={16} /></>
              )}
            </button>
          </form>

          <div className="mt-6 pt-6 border-t border-gray-100 text-center">
            <p className="text-sm text-gray-500">
              Don't have an account?{" "}
              <Link to="/signup" className="text-pink-600 hover:text-pink-700 font-semibold">
                Create one free →
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
