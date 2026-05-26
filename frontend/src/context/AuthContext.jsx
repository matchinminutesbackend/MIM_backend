import { createContext, useContext, useState, useEffect } from "react";
import { api } from "../api/client";

// Must match backend `settings.google_client_id` (Railway env var GOOGLE_CLIENT_ID).
// This is the OAuth client from the Google Cloud project whose Authorized
// JavaScript origins list includes matchinminutes.com — switch this value
// and the Railway env var together, never separately, or token verification
// will 401 even though the browser sign-in appears to succeed.
export const GOOGLE_CLIENT_ID =
  "610696728606-hjv0463opi1e5umn1nas2e3589ss9dqv.apps.googleusercontent.com";

// Lazy-load Google Identity Services script, memoised so multiple pages share one load.
let gsiPromise = null;
export function loadGoogleScript() {
  if (typeof window === "undefined") return Promise.reject(new Error("SSR"));
  if (window.google?.accounts?.id) return Promise.resolve(window.google);
  if (gsiPromise) return gsiPromise;
  gsiPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[src="https://accounts.google.com/gsi/client"]');
    if (existing) {
      existing.addEventListener("load", () => resolve(window.google));
      existing.addEventListener("error", () => reject(new Error("Failed to load Google script")));
      return;
    }
    const s = document.createElement("script");
    s.src = "https://accounts.google.com/gsi/client";
    s.async = true;
    s.defer = true;
    s.onload = () => resolve(window.google);
    s.onerror = () => reject(new Error("Failed to load Google script"));
    document.head.appendChild(s);
  });
  return gsiPromise;
}

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  // null = not yet fetched, true/false = resolved
  const [platformOpen, setPlatformOpen] = useState(null);
  // Populated when the backend returns 403 account_banned on any request
  const [banInfo, setBanInfo] = useState(null);

  // Listen for mid-session ban events dispatched by api/client.js
  useEffect(() => {
    function onBanned(e) { setBanInfo(e.detail || {}); }
    window.addEventListener("auth:banned", onBanned);
    return () => window.removeEventListener("auth:banned", onBanned);
  }, []);

  useEffect(() => {
    // Always fetch platform status — no auth needed. Fail-open (true) on error.
    api.config.platform()
      .then(d => setPlatformOpen(d.platform_open !== false))
      .catch(() => setPlatformOpen(true));

    const token = localStorage.getItem("access_token");
    const savedUser = localStorage.getItem("user");
    if (token && savedUser) {
      setUser(JSON.parse(savedUser));
      api.profile.me()
        .then(setProfile)
        .catch(e => {
          // Surface ban to the UI instead of silently failing
          if (e.code === "account_banned") setBanInfo(e.detail || { message: e.message });
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  async function login(email, password) {
    const res = await api.auth.login({ email, password });
    localStorage.setItem("access_token", res.access_token);
    localStorage.setItem("refresh_token", res.refresh_token);
    const u = { id: res.user_id, email: res.email };
    localStorage.setItem("user", JSON.stringify(u));
    setUser(u);
    const p = await api.profile.me().catch(() => null);
    setProfile(p);
    return { user: u, profile: p };
  }

  async function signup(email, password, name, phone_number) {
    const res = await api.auth.signup({ email, password, name, phone_number });
    if (res.access_token) {
      localStorage.setItem("access_token", res.access_token);
      const u = { id: res.user_id, email: res.email };
      localStorage.setItem("user", JSON.stringify(u));
      setUser(u);
    }
    return res;
  }

  // Exchanges a Google ID token for our own session. Returns the backend payload
  // including `is_new_user` and `is_complete` so callers can route correctly.
  async function googleSignIn(idToken) {
    const res = await api.auth.google(idToken);
    localStorage.setItem("access_token", res.access_token);
    localStorage.setItem("refresh_token", res.refresh_token || res.access_token);
    const u = { id: res.user_id, email: res.email };
    localStorage.setItem("user", JSON.stringify(u));
    setUser(u);
    const p = await api.profile.me().catch(() => null);
    setProfile(p);
    return { ...res, profile: p };
  }

  function logout() {
    api.auth.logout();
    localStorage.clear();
    setUser(null);
    setProfile(null);
    setBanInfo(null);
  }

  function clearBan() {
    setBanInfo(null);
    logout();
  }

  function refreshProfile() {
    return api.profile.me().then(setProfile);
  }

  function refreshPlatform() {
    return api.config.platform()
      .then(d => setPlatformOpen(d.platform_open !== false))
      .catch(() => setPlatformOpen(true));
  }

  return (
    <AuthContext.Provider value={{ user, profile, loading, platformOpen, banInfo, login, signup, googleSignIn, logout, clearBan, refreshProfile, refreshPlatform }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
