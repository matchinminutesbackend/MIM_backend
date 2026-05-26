import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { motion, AnimatePresence, useMotionValue, useTransform } from "framer-motion";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { api } from "../api/client";
import { track, EVENTS } from "../api/events";
import { useChatSocket } from "../api/chatSocket";
import { useCall } from "../api/useCall";
import CallOverlay from "../components/CallOverlay";
import BrandLogo from "../components/BrandLogo";
import CompatibilitySection from "../components/CompatibilitySection";
import {
  GiftPickerModal,
  GiftReceivedOverlay,
  GiftChatCard,
  GiftButton,
} from "../components/Gifts";
import {
  Home, MessageCircle, Heart, Star, User, LogOut,
  ChevronLeft, ChevronRight, X, Send, Search,
  MapPin, Briefcase, Check, CheckCheck, Clock,
  SlidersHorizontal, GraduationCap, Sparkles,
  Edit2, Camera, Trash2, Upload, Save, Plus, Menu, UserMinus,
  Bell, UserPlus, Wallet, Coins, ArrowDownCircle, ArrowUpCircle, Gift,
  Loader2, AlertCircle, Landmark, Smartphone,
  Phone, Video, Zap,
} from "lucide-react";

// ─── helpers ─────────────────────────────────────────────────────────────────
function avatar(profile) {
  const name = profile?.name || "U";
  return (
    profile?.main_image_url ||
    `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&bg=ec4899&color=fff&size=128`
  );
}

function timeAgo(ts) {
  if (!ts) return "";
  const diff = Date.now() - new Date(ts).getTime();
  if (diff < 60_000)  return "now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m`;
  if (diff < 86_400_000) return new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  return new Date(ts).toLocaleDateString([], { month: "short", day: "numeric" });
}

function formatMsgTime(ts) {
  if (!ts) return "";
  const d = new Date(ts);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function Toast({ toast }) {
  if (!toast) return null;
  return (
    <div className={`fixed top-5 right-5 z-50 flex items-center gap-2 px-5 py-3 rounded-2xl shadow-2xl text-white font-semibold text-sm transition-all ${
      toast.type === "error" ? "bg-red-500" : "bg-gradient-to-r from-pink-500 to-purple-500"
    }`}>
      {toast.msg}
    </div>
  );
}

// ─── Match Celebration Modal ──────────────────────────────────────────────────
function MatchModal({ me, partner, onClose, onSayHello }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      style={{ background: "linear-gradient(160deg, #1a0a2e 0%, #0d0d1a 60%, #1a0618 100%)" }}>

      {/* Floating hearts decoration */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {[...Array(8)].map((_, i) => (
          <div key={i}
            className="absolute text-pink-500 opacity-30 animate-bounce"
            style={{
              left: `${10 + i * 12}%`,
              top: `${5 + (i % 3) * 12}%`,
              fontSize: `${14 + (i % 3) * 8}px`,
              animationDelay: `${i * 0.3}s`,
              animationDuration: `${1.8 + (i % 3) * 0.5}s`,
            }}>❤</div>
        ))}
      </div>

      <div className="relative w-full max-w-sm mx-4 sm:mx-auto pb-10 sm:pb-0 text-center">

        {/* Overlapping photo cards */}
        <div className="relative flex items-end justify-center h-64 mb-6">
          {/* Me — left card, tilted left */}
          <div className="absolute z-10"
            style={{ transform: "rotate(-8deg) translateX(-48px) translateY(10px)" }}>
            <div className="w-36 h-48 rounded-2xl overflow-hidden border-[3px] border-white shadow-2xl shadow-black/60">
              <img
                src={me?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(me?.name || "Me")}&bg=ec4899&color=fff&size=200`}
                alt="You"
                className="w-full h-full object-cover"
              />
            </div>
          </div>
          {/* Partner — right card, tilted right, slightly on top */}
          <div className="absolute z-20"
            style={{ transform: "rotate(6deg) translateX(48px) translateY(0px)" }}>
            <div className="w-36 h-48 rounded-2xl overflow-hidden border-[3px] border-white shadow-2xl shadow-black/60">
              <img
                src={partner?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(partner?.name || "?")}&bg=7c3aed&color=fff&size=200`}
                alt={partner?.name}
                className="w-full h-full object-cover"
              />
            </div>
          </div>
          {/* Heart badge between them */}
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 z-30 w-11 h-11 rounded-full bg-gradient-to-br from-pink-500 to-red-500 border-2 border-white shadow-lg flex items-center justify-center">
            <Heart size={20} className="text-white fill-white" />
          </div>
        </div>

        {/* Text */}
        <p className="text-pink-400 font-bold text-xs tracking-[0.2em] uppercase mb-2">
          Congratulations
        </p>
        <h2 className="text-white font-black text-3xl leading-tight mb-2">
          It's a match,<br />{partner?.name}!!
        </h2>
        <p className="text-white/50 text-sm mb-8">
          Start a conversation now with each other
        </p>

        {/* Buttons */}
        <div className="space-y-3 px-4">
          <button
            onClick={onSayHello || onClose}
            className="w-full py-4 rounded-2xl bg-gradient-to-r from-pink-500 to-rose-500 text-white font-bold text-base hover:opacity-90 active:scale-95 transition shadow-lg shadow-pink-900/40 flex items-center justify-center gap-2"
          >
            <MessageCircle size={18} />
            Say hello
          </button>
          <button
            onClick={onClose}
            className="w-full py-4 rounded-2xl bg-white/10 border border-white/20 text-white/80 font-semibold text-base hover:bg-white/15 active:scale-95 transition"
          >
            Keep swiping
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Banned Page ─────────────────────────────────────────────────────────────
function BannedPage({ banInfo, onLogout }) {
  const expiresAt  = banInfo?.ban_expires_at || null;
  const reason     = banInfo?.message || "Your account has been suspended.";
  const [timeLeft, setTimeLeft] = useState(null);
  const [expired,  setExpired]  = useState(false);

  useEffect(() => {
    if (!expiresAt) return;
    function tick() {
      const ms = new Date(expiresAt).getTime() - Date.now();
      if (ms <= 0) { setExpired(true); setTimeLeft(null); return; }
      const s = Math.floor(ms / 1000);
      setTimeLeft({
        days:  Math.floor(s / 86400),
        hours: Math.floor((s % 86400) / 3600),
        mins:  Math.floor((s % 3600) / 60),
        secs:  s % 60,
      });
    }
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [expiresAt]);

  const pad = n => String(n).padStart(2, "0");

  return (
    <div className="fixed inset-0 flex flex-col items-center justify-center p-6 text-center overflow-y-auto"
      style={{ background: "linear-gradient(160deg, #0f0a1e 0%, #0d0d18 55%, #1a0812 100%)" }}>

      {/* Floating particles */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {[...Array(12)].map((_, i) => (
          <div key={i} className="absolute rounded-full bg-red-500/10 animate-pulse"
            style={{
              width:  `${20 + (i % 4) * 15}px`,
              height: `${20 + (i % 4) * 15}px`,
              left:   `${5 + i * 8}%`,
              top:    `${8 + (i % 5) * 18}%`,
              animationDelay: `${i * 0.4}s`,
              animationDuration: `${2 + (i % 3)}s`,
            }} />
        ))}
      </div>

      <div className="relative max-w-md w-full space-y-8">
        {/* Icon */}
        <div className="mx-auto w-24 h-24 rounded-full bg-red-500/10 border-2 border-red-500/30 flex items-center justify-center">
          <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" className="w-9 h-9 text-red-400" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10" />
              <line x1="4.93" y1="4.93" x2="19.07" y2="19.07" />
            </svg>
          </div>
        </div>

        {/* Title */}
        <div>
          <p className="text-red-400 font-bold text-xs tracking-[0.2em] uppercase mb-2">Account Suspended</p>
          <h1 className="text-white font-black text-3xl mb-3">You've been banned</h1>
          <p className="text-white/50 text-sm leading-relaxed max-w-xs mx-auto">{reason}</p>
        </div>

        {/* Timer — temp ban */}
        {expiresAt && !expired && timeLeft && (
          <div className="bg-white/5 border border-white/10 rounded-2xl p-6">
            <p className="text-white/40 text-xs uppercase tracking-widest mb-4">Ban lifts in</p>
            <div className="flex justify-center gap-3">
              {[
                { v: timeLeft.days,  l: "Days"  },
                { v: timeLeft.hours, l: "Hours" },
                { v: timeLeft.mins,  l: "Mins"  },
                { v: timeLeft.secs,  l: "Secs"  },
              ].map(({ v, l }) => (
                <div key={l} className="flex flex-col items-center gap-1">
                  <div className="w-14 h-14 rounded-xl bg-white/10 border border-white/10 flex items-center justify-center">
                    <span className="text-2xl font-black text-white tabular-nums">{pad(v)}</span>
                  </div>
                  <span className="text-white/30 text-[10px] uppercase tracking-wider">{l}</span>
                </div>
              ))}
            </div>
            <p className="text-white/25 text-xs mt-4">
              Lifts on {new Date(expiresAt).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })}
            </p>
          </div>
        )}

        {/* Timer expired — can try again */}
        {expiresAt && expired && (
          <div className="bg-green-500/10 border border-green-500/20 rounded-2xl p-4">
            <p className="text-green-400 font-semibold text-sm">Your ban has expired. Please log out and sign in again.</p>
          </div>
        )}

        {/* Permanent ban */}
        {!expiresAt && (
          <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
            <p className="text-white/40 text-xs uppercase tracking-widest mb-1">Duration</p>
            <p className="text-red-300 font-semibold">Permanent suspension</p>
          </div>
        )}

        {/* Support + Logout */}
        <div className="space-y-3">
          <p className="text-white/25 text-xs">
            If you believe this is a mistake, contact{" "}
            <a href="mailto:support@matchinminutes.com" className="text-white/50 hover:text-white/80 underline transition">
              support@matchinminutes.com
            </a>
          </p>
          <button
            onClick={onLogout}
            className="w-full py-4 rounded-2xl bg-white/10 border border-white/15 text-white/80 font-semibold text-base hover:bg-white/15 active:scale-95 transition flex items-center justify-center gap-2"
          >
            <LogOut size={18} /> Sign out
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Not Verified Modal ───────────────────────────────────────────────────────
function NotVerifiedModal({ verificationStatus, onClose, onGoVerify }) {
  const isPending  = verificationStatus === "pending";
  const isRejected = verificationStatus === "rejected";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" onClick={onClose}>
      <div
        className="bg-white rounded-3xl p-8 max-w-sm w-full mx-auto text-center shadow-2xl"
        onClick={e => e.stopPropagation()}
      >
        {/* Icon */}
        <div className={`w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4 ${
          isPending  ? "bg-blue-50"   :
          isRejected ? "bg-red-50"    :
                       "bg-amber-50"
        }`}>
          <span className="text-3xl">
            {isPending ? "⏳" : isRejected ? "❌" : "📸"}
          </span>
        </div>

        {/* Title */}
        <h2 className="text-xl font-bold text-gray-900 mb-2">
          {isPending  ? "Verification in Review"  :
           isRejected ? "Verification Rejected"   :
                        "Face Verification Required"}
        </h2>

        {/* Body */}
        <p className="text-sm text-gray-500 leading-relaxed mb-6">
          {isPending
            ? "Your selfie is currently being reviewed by our team. You'll be able to send likes once it's approved — usually within a few hours."
            : isRejected
            ? "Your selfie was rejected. Please re-upload a clear, well-lit selfie so our team can verify your identity."
            : "You need to verify your face before sending likes or invites. It only takes a minute and keeps our community safe."}
        </p>

        {/* CTAs */}
        <div className="space-y-2.5">
          {!isPending && (
            <button
              onClick={onGoVerify}
              className="w-full py-3 rounded-xl bg-gradient-to-r from-pink-500 to-rose-500 text-white font-semibold text-sm hover:opacity-90 transition shadow-md shadow-pink-100"
            >
              {isRejected ? "Re-upload Selfie" : "Verify Now →"}
            </button>
          )}
          <button
            onClick={onClose}
            className="w-full py-3 rounded-xl border border-gray-200 text-gray-500 font-medium text-sm hover:bg-gray-50 transition"
          >
            {isPending ? "Got it" : "Maybe later"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Filter Bar ───────────────────────────────────────────────────────────────
const RELATIONSHIP_GOALS = [
  { value: "",            label: "Any goal" },
  { value: "long_term",   label: "Long-term" },
  { value: "short_term",  label: "Short-term" },
  { value: "marriage",    label: "Marriage" },
  { value: "friendship",  label: "Friendship" },
  { value: "casual",      label: "Casual" },
  { value: "unsure",      label: "Unsure" },
];

const EDUCATION_LEVELS = [
  { value: "",                      label: "Any education" },
  { value: "less_than_high_school", label: "Less than high school" },
  { value: "high_school",           label: "High school" },
  { value: "some_college",          label: "Some college" },
  { value: "associates",            label: "Associate degree" },
  { value: "diploma",               label: "Diploma / Certificate" },
  { value: "trade_school",          label: "Trade / Vocational school" },
  { value: "bachelors",             label: "Bachelor's degree" },
  { value: "postgraduate_diploma",  label: "Postgraduate diploma" },
  { value: "masters",               label: "Master's degree" },
  { value: "professional",          label: "Professional (MD / JD / MBA / CA)" },
  { value: "phd",                   label: "PhD / Doctorate" },
  { value: "postdoc",               label: "Postdoctoral" },
  { value: "other",                 label: "Other" },
];

// Religion dropdown — covers the world's major traditions + non-religious
// options. Stored as plain TEXT on the profile, so custom entries remain
// supported via a small "Other" text fallback.
const RELIGION_OPTIONS = [
  "Agnostic", "Atheist", "Spiritual but not religious",
  "Buddhist", "Catholic", "Christian", "Eastern Orthodox", "Hindu",
  "Jain", "Jewish", "Muslim", "Parsi / Zoroastrian", "Protestant",
  "Shinto", "Sikh", "Taoist", "Wiccan / Pagan",
  "Other", "Prefer not to say",
];

// Pretty-print an enum value like "long_term" → "Long term".
// Leaves already-spaced strings alone but still capitalises the first letter.
function prettify(v) {
  if (v === null || v === undefined || v === "") return "";
  const s = String(v).replace(/_/g, " ").trim();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// Title-case each word — for multi-word enum values like
// "prefer_not_to_say" → "Prefer Not To Say". Use sparingly; `prettify` is
// usually nicer because only the first letter is capitalised.
function titleCase(v) {
  if (!v) return "";
  return String(v).replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function FilterBar({ filters, onChange, onReset, total }) {
  const [open, setOpen] = useState(false);
  const activeCount = Object.values(filters).filter(v => v !== "" && v !== null && v !== undefined).length;

  function update(patch) { onChange({ ...filters, ...patch }); }

  return (
    <div className="mb-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <h2 className="text-lg font-bold text-gray-800">Discover People</h2>
          <span className="text-xs text-gray-400 bg-gray-100 px-3 py-1 rounded-full">{total} matches</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={filters.search || ""}
              onChange={e => update({ search: e.target.value })}
              placeholder="Search by name"
              className="pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl w-52 focus:outline-none focus:ring-2 focus:ring-pink-400 focus:border-transparent"
            />
          </div>
          <button onClick={() => setOpen(o => !o)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold border-2 flex items-center gap-2 transition ${
              open || activeCount > 0
                ? "border-pink-400 text-pink-600 bg-pink-50"
                : "border-gray-200 text-gray-600 hover:border-pink-200"
            }`}>
            <SlidersHorizontal size={14} /> Filters{activeCount > 0 && ` · ${activeCount}`}
          </button>
          {activeCount > 0 && (
            <button onClick={onReset} className="text-xs text-gray-500 hover:text-pink-600 underline">Clear</button>
          )}
        </div>
      </div>

      {open && (
        <div className="mt-3 bg-white rounded-2xl border border-gray-100 p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <div>
            <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Age range</label>
            <div className="flex items-center gap-2 mt-1">
              <input type="number" min={18} max={100} value={filters.min_age || ""}
                onChange={e => update({ min_age: e.target.value })}
                placeholder="Min"
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400" />
              <span className="text-gray-400">–</span>
              <input type="number" min={18} max={100} value={filters.max_age || ""}
                onChange={e => update({ max_age: e.target.value })}
                placeholder="Max"
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400" />
            </div>
          </div>
          <div>
            <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">City</label>
            <input value={filters.city || ""} onChange={e => update({ city: e.target.value })}
              placeholder="e.g. Bengaluru"
              className="mt-1 w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400" />
          </div>
          <div>
            <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Country</label>
            <input value={filters.country || ""} onChange={e => update({ country: e.target.value })}
              placeholder="e.g. India"
              className="mt-1 w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400" />
          </div>
          <div>
            <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Looking for</label>
            <select value={filters.relationship_goal || ""}
              onChange={e => update({ relationship_goal: e.target.value })}
              className="mt-1 w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400 bg-white">
              {RELATIONSHIP_GOALS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
          <div>
            <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Education</label>
            <select value={filters.education_level || ""}
              onChange={e => update({ education_level: e.target.value })}
              className="mt-1 w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400 bg-white">
              {EDUCATION_LEVELS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Profile Detail Modal ─────────────────────────────────────────────────────
function ProfileDetailModal({ userId, onClose, onLike, onPass, onUnmatch, showToast }) {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [imgIdx, setImgIdx] = useState(0);
  const [acting, setActing] = useState(false);
  const [autoPaused, setAutoPaused] = useState(false);
  const [confirmUnmatch, setConfirmUnmatch] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api.profile.byId(userId)
      .then(p => { if (!cancelled) { setProfile(p); setImgIdx(0); } })
      .catch(e => { if (!cancelled) { showToast(e.message, "error"); onClose(); } })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [userId, onClose, showToast]);

  const images = profile?.images?.length
    ? profile.images.map(i => i.image_url)
    : [profile?.main_image_url].filter(Boolean);

  // Auto-advance the carousel every 3s — pauses on hover or after manual nav.
  useEffect(() => {
    if (!profile || images.length <= 1 || autoPaused) return;
    const t = setInterval(() => setImgIdx(i => (i + 1) % images.length), 3000);
    return () => clearInterval(t);
  }, [profile, images.length, autoPaused]);

  // Keyboard nav: ESC closes, ←/→ cycle photos
  useEffect(() => {
    function onKey(e) {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft" && images.length > 1)  { setImgIdx(i => (i - 1 + images.length) % images.length); setAutoPaused(true); }
      if (e.key === "ArrowRight" && images.length > 1) { setImgIdx(i => (i + 1) % images.length);                  setAutoPaused(true); }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [images.length, onClose]);

  async function handle(action) {
    if (acting) return;
    setActing(true);
    try {
      if (action === "like") await onLike(userId);
      else await onPass(userId);
      onClose();
    } finally {
      setActing(false);
    }
  }

  function goPrev(e) { e?.stopPropagation(); setAutoPaused(true); setImgIdx(i => (i - 1 + images.length) % images.length); }
  function goNext(e) { e?.stopPropagation(); setAutoPaused(true); setImgIdx(i => (i + 1) % images.length); }

  return (
    /* On mobile: slides up from bottom (items-end). On md+: centred overlay */
    <div className="fixed inset-0 z-50 flex items-end md:items-center justify-center bg-black/60 backdrop-blur-sm md:p-4" onClick={onClose}>
      <div onClick={e => e.stopPropagation()}
        className="bg-white rounded-t-3xl md:rounded-3xl w-full max-w-5xl md:max-h-[92vh] shadow-2xl flex flex-col md:flex-row overflow-hidden"
        style={{ maxHeight: "92dvh" }}>
        {loading || !profile ? (
          <div className="flex-1 h-[70vh] flex items-center justify-center">
            <div className="w-8 h-8 border-2 border-pink-400 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {/* ─── Left: photo carousel ─── */}
            <div
              className="relative md:w-1/2 bg-gradient-to-br from-pink-100 to-purple-100 min-h-[260px] md:min-h-[560px] flex-shrink-0 group"
              onMouseEnter={() => setAutoPaused(true)}
              onMouseLeave={() => setAutoPaused(false)}
            >
              {images.length > 0 ? (
                images.map((src, i) => (
                  <img
                    key={src}
                    src={src} alt={profile.name}
                    className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-700 ${i === imgIdx ? "opacity-100" : "opacity-0"}`}
                  />
                ))
              ) : (
                <div className="w-full h-full flex items-center justify-center text-[9rem] font-black text-pink-300">
                  {profile.name?.[0]}
                </div>
              )}

              {/* Progress bars for each image */}
              {images.length > 1 && (
                <div className="absolute top-3 left-3 right-3 flex gap-1 z-10">
                  {images.map((_, i) => (
                    <button key={i} onClick={(e) => { e.stopPropagation(); setAutoPaused(true); setImgIdx(i); }}
                      className={`h-1 flex-1 rounded-full transition-all ${i === imgIdx ? "bg-white" : "bg-white/40"}`} />
                  ))}
                </div>
              )}

              {/* Prev / Next */}
              {images.length > 1 && (
                <>
                  <button onClick={goPrev}
                    className="absolute left-3 top-1/2 -translate-y-1/2 w-10 h-10 bg-white/90 hover:bg-white rounded-full flex items-center justify-center shadow-md opacity-0 group-hover:opacity-100 transition z-10">
                    <ChevronLeft size={18} />
                  </button>
                  <button onClick={goNext}
                    className="absolute right-3 top-1/2 -translate-y-1/2 w-10 h-10 bg-white/90 hover:bg-white rounded-full flex items-center justify-center shadow-md opacity-0 group-hover:opacity-100 transition z-10">
                    <ChevronRight size={18} />
                  </button>
                </>
              )}

              {/* Name overlay */}
              <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/75 via-black/30 to-transparent p-5 z-10">
                <h2 className="text-white text-2xl md:text-3xl font-bold">{profile.name}{profile.age ? `, ${profile.age}` : ""}</h2>
                {(profile.city || profile.country) && (
                  <p className="text-white/85 text-sm flex items-center gap-1.5 mt-1">
                    <MapPin size={13} /> {[profile.city, profile.country].filter(Boolean).join(", ")}
                  </p>
                )}
              </div>
            </div>

            {/* ─── Right: details ─── */}
            <div className="md:w-1/2 flex flex-col flex-1 min-h-0 relative">
              {/* Close (X) */}
              <button onClick={onClose}
                className="absolute top-4 right-4 w-9 h-9 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-full flex items-center justify-center transition z-20"
                aria-label="Close">
                <X size={18} />
              </button>

              <div className="flex-1 overflow-y-auto p-6 pr-14 pb-2 space-y-5">
                {profile.bio && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-1.5">About</p>
                    <p className="text-sm text-gray-700 leading-relaxed">{profile.bio}</p>
                  </div>
                )}

                <div className="grid grid-cols-2 gap-y-4 gap-x-3 text-sm">
                  {profile.occupation && (
                    <DetailChip Icon={Briefcase} label="Work" value={profile.occupation} />
                  )}
                  {profile.education_level && (
                    <DetailChip Icon={GraduationCap} label="Education" value={prettify(profile.education_level)} />
                  )}
                  {profile.relationship_goal && (
                    <DetailChip Icon={Heart} label="Looking for" value={prettify(profile.relationship_goal)} />
                  )}
                  {profile.relationship_status && (
                    <DetailChip Icon={User} label="Status" value={prettify(profile.relationship_status)} />
                  )}
                  {profile.gender && (
                    <DetailChip Icon={User} label="Gender" value={prettify(profile.gender)} />
                  )}
                  {profile.zodiac_sign && (
                    <DetailChip Icon={Sparkles} label="Zodiac" value={profile.zodiac_sign} />
                  )}
                  {profile.height_cm && (
                    <DetailChip Icon={User} label="Height" value={`${profile.height_cm} cm`} />
                  )}
                  {profile.drinking && (
                    <DetailChip Icon={Sparkles} label="Drinking" value={prettify(profile.drinking)} />
                  )}
                  {profile.smoking && (
                    <DetailChip Icon={Sparkles} label="Smoking" value={prettify(profile.smoking)} />
                  )}
                  {profile.workout && (
                    <DetailChip Icon={Sparkles} label="Workout" value={prettify(profile.workout)} />
                  )}
                  {profile.pets && (
                    <DetailChip Icon={Sparkles} label="Pets" value={prettify(profile.pets)} />
                  )}
                  {profile.children && (
                    <DetailChip Icon={User} label="Children" value={prettify(profile.children)} />
                  )}
                  {profile.diet && (
                    <DetailChip Icon={Sparkles} label="Diet" value={prettify(profile.diet)} />
                  )}
                  {profile.religion && (
                    <DetailChip Icon={Sparkles} label="Religion" value={profile.religion} />
                  )}
                </div>

                {profile.languages?.length > 0 && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-2">Languages</p>
                    <div className="flex flex-wrap gap-2">
                      {profile.languages.map(l => (
                        <span key={l} className="text-xs px-3 py-1.5 bg-purple-50 text-purple-600 rounded-full border border-purple-100 font-medium">{l}</span>
                      ))}
                    </div>
                  </div>
                )}

                {profile.first_date_idea && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-1.5 flex items-center gap-1">
                      <Sparkles size={12} className="text-pink-400" /> Ideal first date
                    </p>
                    <p className="text-sm text-gray-700 leading-relaxed italic">"{profile.first_date_idea}"</p>
                  </div>
                )}

                {profile.vibes?.length > 0 && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-2 flex items-center gap-1">
                      <Sparkles size={12} className="text-pink-400" /> Vibes
                    </p>
                    <div className="flex flex-wrap gap-2">
                      {profile.vibes.map(v => (
                        <span key={v} className="text-xs px-3 py-1.5 bg-pink-50 text-pink-600 rounded-full border border-pink-100 font-medium">{v}</span>
                      ))}
                    </div>
                  </div>
                )}

                {profile.hobbies?.length > 0 && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-2">Hobbies</p>
                    <div className="flex flex-wrap gap-2">
                      {profile.hobbies.map(h => (
                        <span key={h} className="text-xs px-3 py-1.5 bg-gray-50 text-gray-700 rounded-full border border-gray-100">{h}</span>
                      ))}
                    </div>
                  </div>
                )}

                {profile.compatibility_answers?.length > 0 && (
                  <div>
                    <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-2.5 flex items-center gap-1">
                      💬 {profile.relationship_goal === "short_term" || profile.relationship_goal === "casual"
                        ? "Connection Style"
                        : profile.relationship_goal === "friendship"
                        ? "Friendship Compatibility"
                        : "Long-term Compatibility"}
                    </p>
                    <div className="flex gap-3 overflow-x-auto pb-1 snap-x snap-mandatory">
                      {profile.compatibility_answers.map((a, i) => (
                        <div key={i} className="flex-shrink-0 snap-start w-40 bg-gradient-to-br from-rose-50 to-pink-50 border border-rose-100 rounded-2xl p-3 flex flex-col gap-1.5">
                          <p className="text-[10px] text-gray-500 leading-snug line-clamp-3 font-medium">{a.question}</p>
                          <p className="text-xs font-bold text-pink-600 leading-snug line-clamp-2 mt-auto">{a.answer}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Already-connected: show "Remove Friend" instead of like/pass.
                  Matched contexts (Messages, Likes-accepted) pass onUnmatch. */}
              {onUnmatch ? (
                <div className="bg-white border-t border-gray-100 p-4 flex-shrink-0">
                  {confirmUnmatch ? (
                    <div className="space-y-2.5">
                      <p className="text-center text-sm text-gray-700">
                        Remove <span className="font-semibold">{profile.name}</span> as a friend?
                        This ends your chat and you won't see each other again.
                      </p>
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          onClick={() => setConfirmUnmatch(false)}
                          disabled={acting}
                          className="py-2.5 rounded-xl border border-gray-200 text-gray-700 text-sm font-semibold hover:bg-gray-50 transition disabled:opacity-50"
                        >
                          Cancel
                        </button>
                        <button
                          type="button"
                          onClick={async () => {
                            if (acting) return;
                            setActing(true);
                            try {
                              await onUnmatch(userId, profile);
                              onClose();
                            } finally {
                              setActing(false);
                            }
                          }}
                          disabled={acting}
                          className="py-2.5 rounded-xl bg-red-500 hover:bg-red-600 text-white text-sm font-semibold transition disabled:opacity-50 flex items-center justify-center gap-2"
                        >
                          {acting ? (
                            <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                          ) : (
                            <><Trash2 size={14} /> Yes, remove</>
                          )}
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => setConfirmUnmatch(true)}
                      className="w-full flex items-center justify-center gap-2 py-3 rounded-xl border border-red-200 bg-red-50 text-red-600 hover:bg-red-100 hover:border-red-300 transition text-sm font-semibold"
                    >
                      <UserMinus size={16} /> Remove Friend
                    </button>
                  )}
                </div>
              ) : (onLike || onPass) && (
                <div className="bg-white border-t border-gray-100 p-4 flex items-center justify-center gap-4 flex-shrink-0">
                  {onPass && (
                    <button onClick={() => handle("pass")} disabled={acting}
                      title="Pass"
                      className="w-14 h-14 rounded-full border-2 border-gray-200 bg-white text-gray-500 hover:border-red-300 hover:text-red-500 hover:bg-red-50 shadow-sm hover:shadow-md transition disabled:opacity-50 flex items-center justify-center active:scale-95">
                      <X size={22} />
                    </button>
                  )}
                  {onLike && (
                    <button onClick={() => handle("like")} disabled={acting}
                      title="Send Request"
                      className="w-16 h-16 rounded-full bg-gradient-to-br from-pink-500 to-pink-600 text-white shadow-lg shadow-pink-200 hover:shadow-pink-300 hover:scale-105 transition disabled:opacity-50 flex items-center justify-center active:scale-95">
                      <Heart size={26} className="fill-white" />
                    </button>
                  )}
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function DetailChip({ Icon, label, value }) {
  return (
    <div className="flex items-start gap-2">
      <div className="w-7 h-7 rounded-lg bg-pink-50 border border-pink-100 flex items-center justify-center flex-shrink-0 mt-0.5">
        <Icon size={13} className="text-pink-500" />
      </div>
      <div className="min-w-0">
        <p className="text-[10px] text-gray-400 uppercase tracking-wider">{label}</p>
        <p className="font-semibold text-gray-800 capitalize truncate">{value}</p>
      </div>
    </div>
  );
}

// ─── Discover Card ────────────────────────────────────────────────────────────
// Single-container design: the whole card is one `aspect-[3/4]` box with the
// image filling it absolutely and everything else (dots, arrows, info, action
// buttons) floating over it. This guarantees every card renders identically
// in the grid regardless of how many vibes chips a given profile has — the
// previous two-section layout (photo above, white action bar below) meant
// profiles with more chips pushed their card taller than their neighbours.
function DiscoverCard({ person, onLike, onPass, onOpen, onGiftLike, onSuperInvite, isMarriage }) {
  // Only show the main photo — other photos are available after opening the profile
  const mainPhoto = person.main_image_url
    || person.images?.find(i => i.is_main)?.image_url
    || person.images?.[0]?.image_url;

  return (
    <div
      onClick={() => onOpen?.(person.id)}
      className="relative aspect-[3/4] rounded-2xl overflow-hidden shadow-sm hover:shadow-xl transition-shadow border border-gray-100 cursor-pointer bg-gradient-to-br from-pink-100 to-purple-100 group"
    >
      {/* Main photo fills the entire card */}
      {mainPhoto ? (
        <img
          src={mainPhoto}
          alt={person.name}
          className="absolute inset-0 w-full h-full object-cover"
        />
      ) : (
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-6xl font-black text-pink-300">{person.name?.[0]}</span>
        </div>
      )}

      {/* Bottom gradient veil + info + actions stacked — all inside the image */}
      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent pt-14 pb-3 px-3">
        <h3 className="text-white font-bold text-lg leading-tight drop-shadow">{person.name}, {person.age}</h3>
        {person.city && (
          <p className="text-white/85 text-xs flex items-center gap-1 mt-0.5">
            <MapPin size={11} /> {person.city}{person.country ? `, ${person.country}` : ""}
          </p>
        )}
        {person.vibes?.length > 0 && (
          <div className="flex gap-1 mt-1.5 flex-wrap">
            {person.vibes.slice(0, 3).map(v => (
              <span key={v} className="text-[10px] px-2 py-0.5 bg-white/25 text-white rounded-full backdrop-blur-sm">{v}</span>
            ))}
          </div>
        )}

        {/* Action buttons — floating circular buttons on the gradient veil */}
        <div className="flex items-center justify-center gap-3 mt-3">
          <button
            onClick={(e) => { e.stopPropagation(); onPass(person.id); }}
            className="w-11 h-11 rounded-full bg-white/95 hover:bg-white text-gray-500 hover:text-red-500 shadow-lg hover:shadow-xl active:scale-95 transition flex items-center justify-center"
            title="Pass"
          >
            <X size={18} />
          </button>
          {isMarriage ? (
            /* Super Invite button replaces gift-like for marriage users */
            <button
              onClick={(e) => { e.stopPropagation(); onSuperInvite?.(person.id); }}
              className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-indigo-600 text-white shadow-lg shadow-purple-500/50 active:scale-95 transition flex items-center justify-center"
              title="Super Invite — your profile goes to the top of their feed"
            >
              ⭐
            </button>
          ) : (
            <button
              onClick={(e) => { e.stopPropagation(); onGiftLike?.({ id: person.id, name: person.name }); }}
              className="w-10 h-10 rounded-full bg-amber-400 hover:bg-amber-500 text-white shadow-lg shadow-amber-400/50 active:scale-95 transition flex items-center justify-center"
              title="Super like with gift"
            >
              <Gift size={17} />
            </button>
          )}
          <button
            onClick={(e) => { e.stopPropagation(); onLike(person.id); }}
            className="w-12 h-12 rounded-full bg-gradient-to-br from-pink-500 to-pink-600 text-white shadow-lg shadow-pink-600/40 hover:shadow-pink-600/60 active:scale-95 transition flex items-center justify-center"
            title="Like"
          >
            <Heart size={20} className="fill-white" />
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Mobile Swipe Deck ───────────────────────────────────────────────────────
// Tinder-style gesture UI for phones. One card at a time, two placeholders
// stacked behind for depth. Drag a card horizontally:
//   • past +100 px  → "like"  (onLike)
//   • past –100 px  → "pass"  (onPass)
//   • a pure tap (no drag)   → opens the profile detail modal (onOpen)
// We reuse the same handlers as the grid so matches/quotas/paywall all
// behave identically on mobile and desktop.
function SwipeCard({ person, onLike, onPass, onOpen, onExit, zIndex, offset, isTop }) {
  const x = useMotionValue(0);
  // Tilt the card slightly as it's dragged — same tiny 15° max rotation
  // Tinder uses so it doesn't feel floppy.
  const rotate  = useTransform(x, [-200, 0, 200], [-15, 0, 15]);
  const likeOp  = useTransform(x, [40, 140], [0, 1]);
  const passOp  = useTransform(x, [-140, -40], [1, 0]);

  const hero = person.main_image_url
    || person.images?.find(i => i.is_main)?.image_url
    || person.images?.[0]?.image_url;

  function handleDragEnd(_, info) {
    // Threshold: 100 px drag OR fast flick (>500 px/s velocity).
    const swipedRight = info.offset.x >  100 || info.velocity.x >  500;
    const swipedLeft  = info.offset.x < -100 || info.velocity.x < -500;
    if (swipedRight) {
      onExit("right");
      onLike(person.id);
    } else if (swipedLeft) {
      onExit("left");
      onPass(person.id);
    }
    // otherwise motion springs back to 0 automatically
  }

  return (
    <motion.div
      drag={isTop ? "x" : false}
      dragConstraints={{ left: 0, right: 0, top: 0, bottom: 0 }}
      dragElastic={0.9}
      onDragEnd={handleDragEnd}
      style={{
        x: isTop ? x : 0,
        rotate: isTop ? rotate : 0,
        zIndex,
        scale: 1 - offset * 0.04,
        y: offset * 8,
      }}
      initial={false}
      animate={{ opacity: 1 }}
      whileTap={isTop ? { cursor: "grabbing" } : undefined}
      className="absolute inset-0 rounded-3xl overflow-hidden shadow-2xl bg-gradient-to-br from-pink-100 to-purple-100 select-none"
    >
      {/* Tap target — a short click (no drag) opens the profile modal.
          We fire on click rather than mouseup so framer's drag threshold
          (3 px) still suppresses accidental opens during a swipe. */}
      <button
        onClick={() => onOpen?.(person.id)}
        className="absolute inset-0 w-full h-full cursor-pointer"
        aria-label={`Open ${person.name}'s profile`}
      >
        {hero ? (
          <img src={hero} alt={person.name} className="absolute inset-0 w-full h-full object-cover pointer-events-none" draggable={false} />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-8xl font-black text-pink-300">{person.name?.[0]}</span>
          </div>
        )}
      </button>

      {/* LIKE / NOPE stamps that fade in as user drags */}
      {isTop && (
        <>
          <motion.div
            style={{ opacity: likeOp }}
            className="absolute top-10 left-6 px-4 py-2 border-4 border-green-400 rounded-xl rotate-[-12deg] pointer-events-none z-20"
          >
            <span className="text-green-400 text-3xl font-black tracking-wider">LIKE</span>
          </motion.div>
          <motion.div
            style={{ opacity: passOp }}
            className="absolute top-10 right-6 px-4 py-2 border-4 border-red-400 rounded-xl rotate-[12deg] pointer-events-none z-20"
          >
            <span className="text-red-400 text-3xl font-black tracking-wider">NOPE</span>
          </motion.div>
        </>
      )}

      {/* Info veil at the bottom */}
      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent pt-16 pb-5 px-5 pointer-events-none">
        <h3 className="text-white font-bold text-2xl leading-tight drop-shadow">{person.name}, {person.age}</h3>
        {person.city && (
          <p className="text-white/90 text-sm flex items-center gap-1 mt-1">
            <MapPin size={13} /> {person.city}{person.country ? `, ${person.country}` : ""}
          </p>
        )}
        {person.vibes?.length > 0 && (
          <div className="flex gap-1.5 mt-2 flex-wrap">
            {person.vibes.slice(0, 3).map(v => (
              <span key={v} className="text-xs px-2.5 py-1 bg-white/25 text-white rounded-full backdrop-blur-sm">{v}</span>
            ))}
          </div>
        )}
      </div>
    </motion.div>
  );
}

function SwipeDeck({ candidates, onLike, onPass, onOpen, onGiftLike, onLoadMore, hasMore, loadingMore }) {
  // Keep a local index so the card flies off before its parent re-renders.
  // Parent's `candidates` only shrinks when matches/quota/network round-trip
  // finishes; we need the deck to feel instant.
  const [cursor, setCursor] = useState(0);
  // Reset the cursor if the candidate list is replaced (filters changed).
  useEffect(() => { setCursor(0); }, [candidates]);

  // Prefetch more when the user is 3 cards from the bottom of what's loaded.
  useEffect(() => {
    if (hasMore && !loadingMore && cursor >= candidates.length - 3) {
      onLoadMore?.();
    }
  }, [cursor, candidates.length, hasMore, loadingMore, onLoadMore]);

  function swipe(id, dir) {
    if (dir === "right") onLike(id);
    else onPass(id);
    setCursor((c) => c + 1);
  }

  // Show the current top card + up to 2 behind it so the deck looks stacked.
  const visible = candidates.slice(cursor, cursor + 3);

  if (cursor >= candidates.length) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center px-6">
        <div className="w-20 h-20 rounded-full bg-pink-50 flex items-center justify-center mb-4">
          <Heart size={36} className="text-pink-300" />
        </div>
        <h3 className="text-xl font-bold text-gray-800 mb-2">You're all caught up</h3>
        <p className="text-gray-400 text-sm max-w-xs">Check back soon — new people join every day.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center">
      {/*
        Card stack — fixed aspect ratio so the layout is predictable.
        `isolate` creates a new stacking context so the cards' internal
        z-indexes (3/2/1) don't escape and render above modals (z-50)
        elsewhere on the page. Without this, tapping a card opened the
        ProfileDetailModal but the swipe deck drew on top of it.
      */}
      <div className="relative isolate w-full max-w-sm aspect-[3/4.3]">
        <AnimatePresence>
          {visible.map((p, i) => {
            const isTop = i === 0;
            return (
              <SwipeCard
                key={p.id}
                person={p}
                isTop={isTop}
                offset={i}
                zIndex={3 - i}
                onLike={(id) => { /* handled in onExit */ void id; }}
                onPass={(id) => { /* handled in onExit */ void id; }}
                onOpen={onOpen}
                onExit={(dir) => swipe(p.id, dir)}
              />
            );
          })}
        </AnimatePresence>
      </div>

      {/* Big action buttons below the deck */}
      <div className="flex items-center justify-center gap-5 mt-6">
        <button
          onClick={() => { const top = candidates[cursor]; if (top) swipe(top.id, "left"); }}
          className="w-14 h-14 rounded-full bg-white shadow-lg border border-gray-200 text-gray-500 hover:text-red-500 active:scale-95 transition flex items-center justify-center"
          aria-label="Pass"
        >
          <X size={26} />
        </button>
        <button
          onClick={() => {
            const top = candidates[cursor];
            if (top) onGiftLike?.({ id: top.id, name: top.name });
          }}
          className="w-12 h-12 rounded-full bg-amber-400 hover:bg-amber-500 shadow-lg shadow-amber-400/40 text-white active:scale-95 transition flex items-center justify-center"
          aria-label="Gift like"
          title="Super like with gift"
        >
          <Gift size={22} />
        </button>
        <button
          onClick={() => { const top = candidates[cursor]; if (top) swipe(top.id, "right"); }}
          className="w-16 h-16 rounded-full bg-gradient-to-br from-pink-500 to-pink-600 shadow-lg shadow-pink-600/40 text-white active:scale-95 transition flex items-center justify-center"
          aria-label="Like"
        >
          <Heart size={28} className="fill-white" />
        </button>
      </div>

      {/* Hint row — swipe cue fades after a few seconds via CSS animation */}
      <p className="mt-4 text-xs text-gray-400 text-center">
        Tap to view profile · Swipe to decide
      </p>
    </div>
  );
}

// ─── Discover View ────────────────────────────────────────────────────────────
const EMPTY_FILTERS = {
  search: "", min_age: "", max_age: "", city: "", country: "",
  relationship_goal: "", education_level: "",
};

function DiscoverView({ showToast, onMatch, profile }) {
  const [candidates, setCandidates] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [openProfileId, setOpenProfileId] = useState(null);
  // Backend returns HTTP 403 with detail "verify_required" when an unverified
  // user tries to browse Discover. We mirror the same state for like() failures
  // so we can render a single "Verify to browse" card instead of a toast spam.
  const [verifyRequired, setVerifyRequired] = useState(false);
  const [paywall, setPaywall] = useState(null);
  // Gift-like: { id, name } of the person being gifted; null = modal closed
  const [giftTarget, setGiftTarget] = useState(null);
  // Simple "not verified" gate — shown proactively before any API call
  const [showNotVerified, setShowNotVerified] = useState(false);
  // Marriage-specific
  const isMarriage = profile?.relationship_goal === "serious_marriage";
  const [superInviteBalance, setSuperInviteBalance] = useState(null);
  const [showSuperInvitePurchase, setShowSuperInvitePurchase] = useState(false);
  const [quotaStatus, setQuotaStatus] = useState(null);

  // Load super-invite balance for marriage users
  useEffect(() => {
    if (!isMarriage) return;
    api.superInvites.balance().then(r => setSuperInviteBalance(r.balance ?? 0)).catch(() => {});
    api.subscriptions.me().then(r => setQuotaStatus(r.quota)).catch(() => {});
  }, [isMarriage]);

  // ── Instant Match state ──────────────────────────────────────────────────
  // imInfo  : { enabled, unlimited, remaining, used, limit }
  // imState : null | 'searching' | 'confirming' | 'partner_skipped' | 'chat'
  const [imInfo, setImInfo]         = useState(null);
  const [imState, setImState]       = useState(null);
  const [imPartner, setImPartner]   = useState(null);
  const [imMatchId, setImMatchId]   = useState(null);
  // imCountdown: seconds left in the 5-s confirmation window
  const [imCountdown, setImCountdown] = useState(5);
  // imSearchSecs: elapsed seconds while searching (shown in searching modal)
  const [imSearchSecs, setImSearchSecs] = useState(0);
  const imPollRef    = useRef(null);
  const imTimerRef   = useRef(null);
  const imCountRef   = useRef(null);  // countdown interval
  // IM chat state
  const [imChatMessages,    setImChatMessages]    = useState([]);
  const [imChatEnded,       setImChatEnded]       = useState(false);
  const [imChatInviteStatus, setImChatInviteStatus] = useState(null); // null|'sent'|'received'
  const [imChatAccepted,    setImChatAccepted]    = useState(false);
  const imChatPollRef  = useRef(null); // status poll interval
  const imMsgPollRef   = useRef(null); // message poll interval

  // Load feature info on mount
  useEffect(() => {
    api.instantMatch.info().then(setImInfo).catch(() => {});
  }, []);

  function _imClearAll() {
    [imPollRef, imTimerRef, imCountRef, imChatPollRef, imMsgPollRef].forEach(r => {
      if (r.current) { clearInterval(r.current); r.current = null; }
    });
  }

  function _imStartChat(matchId, partner) {
    setImMatchId(matchId);
    setImPartner(partner);
    setImChatMessages([]);
    setImChatEnded(false);
    setImChatInviteStatus(null);
    setImChatAccepted(false);
    setImState("chat");

    // Poll messages every 2 s
    imMsgPollRef.current = setInterval(async () => {
      try {
        const msgs = await api.messages.history(matchId);
        setImChatMessages(msgs || []);
      } catch (_) {}
    }, 2000);
    // Initial load immediately
    api.messages.history(matchId).then(m => setImChatMessages(m || [])).catch(() => {});

    // Poll chat status every 3 s (ended? invite?)
    imChatPollRef.current = setInterval(async () => {
      try {
        const st = await api.instantMatch.chatStatus(matchId);
        if (st.ended) {
          setImChatEnded(true);
          // stop polling once ended
          if (imMsgPollRef.current)  { clearInterval(imMsgPollRef.current);  imMsgPollRef.current  = null; }
          if (imChatPollRef.current) { clearInterval(imChatPollRef.current); imChatPollRef.current = null; }
        }
        setImChatInviteStatus(st.invite_status || null);
      } catch (_) {}
    }, 3000);
  }

  // Enter the 5-second confirmation window after a match is found
  function _imStartConfirming(partner, matchId, expiresAt) {
    setImPartner(partner);
    setImMatchId(matchId);
    // Calculate how many seconds are left from the server's expiry timestamp
    const msLeft = expiresAt
      ? Math.max(0, new Date(expiresAt).getTime() - Date.now())
      : 5000;
    const secsLeft = Math.ceil(msLeft / 1000);
    setImCountdown(secsLeft > 0 ? secsLeft : 5);
    setImState("confirming");
    // Clear any searching timers
    if (imTimerRef.current) { clearInterval(imTimerRef.current); imTimerRef.current = null; }
    if (imPollRef.current)  { clearInterval(imPollRef.current);  imPollRef.current  = null; }

    // Countdown tick — also polls for partner_skipped every second
    imCountRef.current = setInterval(async () => {
      setImCountdown(prev => {
        if (prev <= 1) {
          // Timer hit 0 — auto confirm
          clearInterval(imCountRef.current); imCountRef.current = null;
          _imDoConfirm();
          return 0;
        }
        return prev - 1;
      });
      // Poll for partner_skipped
      try {
        const s = await api.instantMatch.status();
        if (s.status === "partner_skipped") {
          _imClearAll();
          setImState("partner_skipped");
          // Auto-clear the "partner skipped" message after 2.5 s and restart search
          setTimeout(() => {
            setImState(null);
          }, 2500);
        }
      } catch (_) {}
    }, 1000);
  }

  async function _imDoConfirm() {
    _imClearAll();
    try {
      const res = await api.instantMatch.confirm();
      api.instantMatch.info().then(setImInfo).catch(() => {});
      // Open the instant match chat overlay (temporary — hidden from Messages)
      const chatPartner = res.partner || imPartner;
      const chatMatchId = res.match_id || imMatchId;
      _imStartChat(chatMatchId, chatPartner);
    } catch (e) {
      setImState(null);
      showToast("Could not connect to chat", "error");
    }
  }

  async function handleInstantMatch() {
    const vSt = (profile?.verification_status || (profile?.is_verified ? "approved" : "none")).toLowerCase();
    if (!profile?.is_verified && vSt !== "pending") {
      setShowNotVerified(true);
      return;
    }
    try {
      const res = await api.instantMatch.join();
      if (res.status === "confirming") {
        _imStartConfirming(res.partner, res.match_id, res.expires_at);
      } else {
        // Waiting — show searching modal and poll
        setImSearchSecs(0);
        setImState("searching");
        imTimerRef.current = setInterval(() => setImSearchSecs(s => s + 1), 1000);
        imPollRef.current  = setInterval(async () => {
          try {
            const s = await api.instantMatch.status();
            if (s.status === "confirming") {
              _imStartConfirming(s.partner, s.match_id, s.expires_at);
            } else if (s.status === "not_in_queue") {
              _imClearAll();
              setImState(null);
            }
          } catch (_) {}
        }, 2000);
      }
    } catch (e) {
      if (e.status === 402 && e.code === "quota_exceeded") {
        track(EVENTS.PAYWALL_SHOWN, { kind: "instant_match" });
        setPaywall({ kind: "instant_match", plans: e.detail?.plans || [] });
      } else {
        showToast(e.message || "Could not start Instant Match", "error");
      }
    }
  }

  async function handleImCancel() {
    _imClearAll();
    setImState(null);
    try { await api.instantMatch.leave(); } catch (_) {}
  }

  async function handleImSkip() {
    _imClearAll();
    setImState(null);
    try { await api.instantMatch.skip(); } catch (_) {}
    // Re-join the queue immediately to find a new partner
    setTimeout(() => handleInstantMatch(), 300);
  }

  async function handleImStartChat() {
    // User tapped "Start Chat" before timer ran out — confirm immediately
    if (imCountRef.current) { clearInterval(imCountRef.current); imCountRef.current = null; }
    await _imDoConfirm();
  }

  async function handleImChatLeave() {
    const matchId = imMatchId;
    _imClearAll();
    setImState(null);
    try { await api.instantMatch.chatLeave(matchId); } catch (_) {}
    api.instantMatch.info().then(setImInfo).catch(() => {});
  }

  async function handleImChatSendMessage(text) {
    if (!text.trim() || !imMatchId) return;
    try {
      const msg = await api.messages.send(imMatchId, text);
      setImChatMessages(prev => [...prev, msg]);
    } catch (e) {
      showToast(e.message || "Failed to send message", "error");
    }
  }

  async function handleImChatSendInvite() {
    try {
      await api.instantMatch.chatInvite(imMatchId);
      setImChatInviteStatus("sent");
    } catch (e) {
      showToast(e.message || "Could not send invite", "error");
    }
  }

  async function handleImChatAcceptInvite() {
    try {
      await api.instantMatch.chatAccept(imMatchId);
      setImChatInviteStatus(null);
      setImChatAccepted(true);
      // Brief celebration then close overlay — chat is now permanent in Messages
      setTimeout(() => {
        _imClearAll();
        setImState(null);
        window.dispatchEvent(new CustomEvent("dashboard:go",       { detail: "messages" }));
        window.dispatchEvent(new CustomEvent("messages:openMatch",  { detail: imMatchId }));
        showToast(`🎉 You're now friends with ${imPartner?.name}!`);
      }, 1800);
    } catch (e) {
      showToast(e.message || "Could not accept invite", "error");
    }
  }

  async function handleImChatDeclineInvite() {
    try {
      await api.instantMatch.chatDecline(imMatchId);
      setImChatInviteStatus(null);
    } catch (e) {
      showToast(e.message || "Could not decline invite", "error");
    }
  }

  // Debounce filter changes so we don't thrash the API while typing
  const [debouncedFilters, setDebouncedFilters] = useState(filters);
  useEffect(() => {
    const t = setTimeout(() => setDebouncedFilters(filters), 350);
    return () => clearTimeout(t);
  }, [filters]);

  const load = useCallback(async (pg, appliedFilters) => {
    try {
      const res = await api.matches.discover(pg, appliedFilters);
      const list = res.matches || [];
      setTotal(res.total || 0);
      if (pg === 1) setCandidates(list);
      else setCandidates(prev => [...prev, ...list]);
      setHasMore(pg * (res.limit || 12) < (res.total || 0));
      setPage(pg);
      setVerifyRequired(false);
    } catch (e) {
      // Backend distinguishes two "you can't browse yet" cases:
      //   verify_required → user never uploaded a selfie
      //   verify_rejected → their selfie got rejected by admin
      // We surface both via the same modal (the modal reads vStatus to
      // switch its copy between "upload selfie" and "your selfie was
      // rejected — try again").
      if ((e.message || "").includes("verify_required") || (e.message || "").includes("verify_rejected")) {
        setVerifyRequired(true);
        setCandidates([]);
        setTotal(0);
        setHasMore(false);
      } else {
        showToast(e.message, "error");
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [showToast]);

  useEffect(() => {
    setLoading(true);
    load(1, debouncedFilters);
  }, [debouncedFilters, load]);

  async function handleLike(id) {
    // Pre-check: block unverified users before hitting the API
    const vSt = (profile?.verification_status || (profile?.is_verified ? "approved" : "none")).toLowerCase();
    if (!profile?.is_verified && vSt !== "pending") {
      setShowNotVerified(true);
      return;
    }
    try {
      const res = await api.matches.like(id);
      track(EVENTS.PROFILE_LIKED, null, id);
      const partner = candidates.find(p => p.id === id);
      setCandidates(prev => prev.filter(p => p.id !== id));
      if (res.matched && partner) onMatch(partner);
      else showToast("Request sent ❤️");
    } catch (e) {
      // 402 quota_exceeded → open the paywall. Server embeds plans in
      // the error detail so we have everything we need to render cards.
      if (e.status === 402 && e.code === "quota_exceeded") {
        track(EVENTS.PAYWALL_SHOWN, { kind: e.detail?.kind || "heart" });
        setPaywall({ kind: e.detail?.kind || "heart", plans: e.detail?.plans || [] });
        return;
      }
      if ((e.message || "").toLowerCase().includes("verify your face")) {
        setShowNotVerified(true);
      } else {
        showToast(e.message, "error");
      }
    }
  }

  async function handlePass(id) {
    try {
      await api.matches.pass(id);
      track(EVENTS.PROFILE_PASSED, null, id);
      setCandidates(prev => prev.filter(p => p.id !== id));
    } catch (e) {
      if (e.status === 402 && e.code === "quota_exceeded") {
        track(EVENTS.PAYWALL_SHOWN, { kind: e.detail?.kind || "pass" });
        setPaywall({ kind: e.detail?.kind || "pass", plans: e.detail?.plans || [] });
        return;
      }
      setCandidates(prev => prev.filter(p => p.id !== id));
    }
  }

  async function handleGiftLike(id, message) {
    // Pre-check: block unverified users before hitting the API
    const vSt = (profile?.verification_status || (profile?.is_verified ? "approved" : "none")).toLowerCase();
    if (!profile?.is_verified && vSt !== "pending") {
      setGiftTarget(null);
      setShowNotVerified(true);
      return;
    }
    setCandidates(prev => prev.filter(p => p.id !== id));
    setGiftTarget(null);
    try {
      const res = await api.matches.giftLike(id, message);
      const partner = candidates.find(p => p.id === id);
      if (res.matched && partner) onMatch(partner);
      else showToast("Gift like sent 🎁");
    } catch (e) {
      if (e.status === 402 && e.code === "quota_exceeded") {
        track(EVENTS.PAYWALL_SHOWN, { kind: e.detail?.kind || "heart" });
        setPaywall({ kind: e.detail?.kind || "heart", plans: e.detail?.plans || [] });
        return;
      }
      if ((e.message || "").toLowerCase().includes("verify")) {
        setShowNotVerified(true);
      } else {
        showToast(e.message, "error");
      }
    }
  }

  async function handleSuperInvite(id) {
    const vSt = (profile?.verification_status || (profile?.is_verified ? "approved" : "none")).toLowerCase();
    if (!profile?.is_verified && vSt !== "pending") { setShowNotVerified(true); return; }
    if (superInviteBalance !== null && superInviteBalance <= 0) {
      setShowSuperInvitePurchase(true);
      return;
    }
    try {
      const res = await api.matches.superInvite(id);
      const partner = candidates.find(p => p.id === id);
      setCandidates(prev => prev.filter(p => p.id !== id));
      setSuperInviteBalance(b => Math.max(0, (b ?? 1) - 1));
      if (res.matched && partner) onMatch(partner);
      else showToast("⭐ Super Invite sent! Your profile is now at the top of their feed.");
    } catch (e) {
      if (e.status === 402 && e.code === "quota_exceeded") {
        setPaywall({ kind: e.detail?.kind || "heart", plans: e.detail?.plans || [] });
        return;
      }
      showToast(e.message || "Could not send super invite", "error");
    }
  }

  // Verification state machine (see backend/app/profile/schemas.py).
  //   'none'     → user skipped during signup: show amber "verify now" banner
  //   'pending'  → selfie uploaded, awaiting admin: show green "partially verified"
  //   'approved' → is_verified=true, no banner
  //   'rejected' → show red "re-upload required" banner with admin's reason
  const vStatus = (profile?.verification_status || (profile?.is_verified ? "approved" : "none")).toLowerCase();

  return (
    <div className="p-5">
      {profile && vStatus === "none" && (
        <div className="mb-4 flex items-center gap-3 p-3.5 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-sm">
          <Camera size={16} className="flex-shrink-0" />
          <span className="flex-1">
            Your profile isn't verified yet. Upload a selfie so others can match with you.
          </span>
          <button
            onClick={() => window.dispatchEvent(new CustomEvent("dashboard:go", { detail: "profile" }))}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-amber-500 text-white font-semibold text-xs hover:bg-amber-600 transition"
          >
            Verify now
          </button>
        </div>
      )}
      {profile && vStatus === "pending" && (
        <div className="mb-4 flex items-center gap-3 p-3.5 bg-blue-50 border border-blue-200 rounded-xl text-blue-800 text-sm">
          <Clock size={16} className="flex-shrink-0" />
          <span className="flex-1">
            <b>Partially verified.</b> Your selfie is waiting for admin review — you have full access in the meantime.
          </span>
        </div>
      )}
      {profile && vStatus === "rejected" && (
        <div className="mb-4 flex items-start gap-3 p-3.5 bg-red-50 border border-red-200 rounded-xl text-red-800 text-sm">
          <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <p className="font-semibold">Verification rejected — please re-upload</p>
            <p className="text-xs mt-0.5 text-red-700/90">
              {profile.verification_note || "Your selfie didn't match your profile photo. Please upload a clear, well-lit selfie."}
            </p>
          </div>
          <button
            onClick={() => window.dispatchEvent(new CustomEvent("dashboard:go", { detail: "profile" }))}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-red-500 text-white font-semibold text-xs hover:bg-red-600 transition"
          >
            Re-upload
          </button>
        </div>
      )}
      {/* 🕌 Serious Marriage header + daily free-trial status */}
      {isMarriage && (
        <div className="mb-4 p-4 bg-gradient-to-r from-purple-50 to-indigo-50 border border-purple-100 rounded-2xl space-y-2">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="text-xl">🕌</span>
              <div>
                <p className="text-sm font-bold text-purple-900">Serious Matrimony Feed</p>
                <p className="text-xs text-purple-600">Only verified matrimony seekers — no casuals</p>
              </div>
            </div>
            {superInviteBalance !== null && (
              <button
                onClick={() => setShowSuperInvitePurchase(true)}
                className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-purple-500 text-white text-xs font-semibold hover:bg-purple-600 transition"
              >
                ⭐ {superInviteBalance} Super {superInviteBalance === 1 ? "Invite" : "Invites"}
              </button>
            )}
          </div>
          {/* Daily free-trial meter */}
          {quotaStatus?.gated && (
            <div className="flex items-center gap-3 mt-1">
              <div className="flex-1 space-y-1">
                <div className="flex justify-between text-[10px] text-purple-700">
                  <span>Invites {quotaStatus.hearts_used}/{quotaStatus.hearts_limit} free today</span>
                  <span>Passes {quotaStatus.passes_used}/{quotaStatus.passes_limit} free today</span>
                </div>
                <div className="h-1.5 bg-purple-100 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-purple-400 rounded-full transition-all"
                    style={{ width: `${Math.min(100, ((quotaStatus.hearts_used || 0) / (quotaStatus.hearts_limit || 5)) * 100)}%` }}
                  />
                </div>
              </div>
              {(quotaStatus.hearts_used >= quotaStatus.hearts_limit || quotaStatus.passes_used >= quotaStatus.passes_limit) && (
                <button
                  onClick={() => setPaywall({ kind: "heart", plans: [] })}
                  className="flex-shrink-0 px-3 py-1.5 bg-purple-500 text-white text-xs font-bold rounded-xl hover:bg-purple-600 transition"
                >
                  Get ₹499/mo
                </button>
              )}
            </div>
          )}
        </div>
      )}

      {/* ⚡ Instant Match button — hidden when feature is off, hidden for marriage users */}
      {!isMarriage && imInfo?.enabled !== false && (
        <div className="mb-4 flex items-center justify-between gap-3 p-4 bg-gradient-to-r from-violet-50 to-pink-50 border border-violet-100 rounded-2xl">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center shadow-md shadow-violet-200 flex-shrink-0">
              <Zap size={18} className="text-white fill-white" />
            </div>
            <div>
              <p className="text-sm font-bold text-gray-900">Instant Match</p>
              <p className="text-xs text-gray-500">
                {imInfo?.unlimited
                  ? "Unlimited · find someone right now"
                  : imInfo
                  ? `${imInfo.remaining} free ${imInfo.remaining === 1 ? "use" : "uses"} left today`
                  : "Find someone online right now"}
              </p>
            </div>
          </div>
          <button
            onClick={handleInstantMatch}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-gradient-to-r from-violet-500 to-pink-500 text-white text-sm font-semibold shadow-md shadow-violet-200 hover:opacity-90 active:scale-95 transition flex-shrink-0"
          >
            <Zap size={14} className="fill-white" /> Match Now
          </button>
        </div>
      )}

      <FilterBar
        filters={filters}
        onChange={setFilters}
        onReset={() => setFilters(EMPTY_FILTERS)}
        total={total}
      />

      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="aspect-[3/4] rounded-2xl bg-gray-200 animate-pulse" />
          ))}
        </div>
      ) : candidates.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 text-center px-6">
          <div className="w-20 h-20 rounded-full bg-pink-50 flex items-center justify-center mb-4">
            <Heart size={36} className="text-pink-300" />
          </div>
          <h3 className="text-xl font-bold text-gray-800 mb-2">No matches found</h3>
          <p className="text-gray-400 text-sm max-w-xs">
            Try adjusting your filters or check back later as more people join.
          </p>
        </div>
      ) : (
        <>
          {/* Mobile: Tinder-style swipe deck. Hidden ≥ md. */}
          <div className="md:hidden">
            <SwipeDeck
              candidates={candidates}
              onLike={handleLike}
              onPass={handlePass}
              onOpen={setOpenProfileId}
              onGiftLike={setGiftTarget}
              hasMore={hasMore}
              loadingMore={loadingMore}
              onLoadMore={() => { setLoadingMore(true); load(page + 1, debouncedFilters); }}
            />
          </div>

          {/* Tablet / desktop: grid of cards. Hidden < md. */}
          <div className="hidden md:block">
            <div className="grid md:grid-cols-3 xl:grid-cols-4 gap-4">
              {candidates.map(p => (
                <DiscoverCard key={p.id} person={p}
                  onLike={handleLike} onPass={handlePass}
                  onOpen={setOpenProfileId}
                  onGiftLike={setGiftTarget}
                  onSuperInvite={handleSuperInvite}
                  isMarriage={isMarriage} />
              ))}
            </div>
            {hasMore && (
              <div className="mt-6 flex justify-center">
                <button onClick={() => { setLoadingMore(true); load(page + 1, debouncedFilters); }}
                  disabled={loadingMore}
                  className="px-8 py-2.5 rounded-xl border-2 border-pink-200 text-pink-600 text-sm font-semibold hover:bg-pink-50 transition disabled:opacity-50">
                  {loadingMore ? "Loading…" : "Load more"}
                </button>
              </div>
            )}
          </div>
        </>
      )}

      {openProfileId && (
        <ProfileDetailModal
          userId={openProfileId}
          showToast={showToast}
          onClose={() => setOpenProfileId(null)}
          onLike={handleLike}
          onPass={handlePass}
        />
      )}

      {/* Not-verified gate — shown when user tries to like without being verified */}
      {showNotVerified && (
        <NotVerifiedModal
          verificationStatus={profile?.verification_status || "none"}
          onClose={() => setShowNotVerified(false)}
          onGoVerify={() => {
            setShowNotVerified(false);
            window.dispatchEvent(new CustomEvent("dashboard:go", { detail: "profile" }));
          }}
        />
      )}

      {/* Face-verification gate. Opens as a pop-up instead of replacing the
          whole page — the user still sees the Discover layout behind it. */}
      {verifyRequired && (
        <VerifyFaceModal
          gated
          onClose={() => {
            // Closing without verifying keeps the amber banner at the top of
            // Discover and the catch-block will re-open this modal next time
            // they try to like someone.
            setVerifyRequired(false);
          }}
          onDone={() => {
            setVerifyRequired(false);
            showToast?.("Face verified — welcome to Discover ✨");
            // Reload candidates now that the backend will stop 403'ing us.
            setLoading(true);
            load(1, debouncedFilters);
          }}
          showToast={showToast}
        />
      )}

      {paywall && (
        <SubscriptionModal
          trigger={paywall.kind}
          profile={profile}
          onClose={() => setPaywall(null)}
          onUpgraded={() => {
            setPaywall(null);
            showToast?.("You're Premium! Unlimited swipes ✨");
            window.dispatchEvent(new CustomEvent("subs:changed"));
          }}
          showToast={showToast}
        />
      )}

      {/* Marriage free-trial-over paywall */}
      {isMarriage && paywall && (
        <MarriagePaywallModal
          kind={paywall.kind}
          onClose={() => setPaywall(null)}
          onUpgraded={() => {
            setPaywall(null);
            showToast?.("Marriage plan activated ✨");
          }}
          showToast={showToast}
        />
      )}

      {/* Super Invite purchase modal */}
      {showSuperInvitePurchase && (
        <SuperInvitePurchaseModal
          onClose={() => setShowSuperInvitePurchase(false)}
          onPurchased={(newBalance) => {
            setSuperInviteBalance(newBalance);
            setShowSuperInvitePurchase(false);
            showToast?.("5 Super Invites added! ⭐");
          }}
          showToast={showToast}
          profile={profile}
        />
      )}

      {/* Gift-like modal */}
      {giftTarget && (
        <GiftLikeModal
          name={giftTarget.name}
          onSend={(msg) => handleGiftLike(giftTarget.id, msg)}
          onClose={() => setGiftTarget(null)}
        />
      )}

      {/* ⚡ Instant Match — Searching modal */}
      {imState === "searching" && (
        <InstantMatchSearchingModal
          seconds={imSearchSecs}
          onCancel={handleImCancel}
        />
      )}

      {/* ⚡ Instant Match — 5s Confirmation modal */}
      {imState === "confirming" && imPartner && (
        <InstantMatchFoundModal
          me={profile}
          partner={imPartner}
          countdown={imCountdown}
          onStartChat={handleImStartChat}
          onSkip={handleImSkip}
        />
      )}

      {/* ⚡ Instant Match — Partner skipped notice */}
      {imState === "partner_skipped" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white rounded-3xl p-8 max-w-xs w-full text-center shadow-2xl">
            <div className="text-4xl mb-3">😔</div>
            <h3 className="text-lg font-bold text-gray-900 mb-1">They passed</h3>
            <p className="text-sm text-gray-500">Looking for your next match…</p>
            <div className="mt-4 flex justify-center">
              <div className="w-5 h-5 border-2 border-violet-400 border-t-transparent rounded-full animate-spin" />
            </div>
          </div>
        </div>
      )}

      {/* ⚡ Instant Match — Live Chat Overlay */}
      {imState === "chat" && imPartner && (
        <InstantMatchChatOverlay
          me={profile}
          partner={imPartner}
          matchId={imMatchId}
          messages={imChatMessages}
          ended={imChatEnded}
          inviteStatus={imChatInviteStatus}
          accepted={imChatAccepted}
          onSend={handleImChatSendMessage}
          onLeave={handleImChatLeave}
          onSendInvite={handleImChatSendInvite}
          onAcceptInvite={handleImChatAcceptInvite}
          onDeclineInvite={handleImChatDeclineInvite}
        />
      )}
    </div>
  );
}

// ─── Instant Match: Searching Modal ──────────────────────────────────────────
function InstantMatchSearchingModal({ seconds, onCancel }) {
  const mins = String(Math.floor(seconds / 60)).padStart(2, "0");
  const secs = String(seconds % 60).padStart(2, "0");

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-white rounded-3xl p-8 w-full max-w-sm text-center shadow-2xl">
        {/* Pulsing ring animation */}
        <div className="relative w-28 h-28 mx-auto mb-6">
          <div className="absolute inset-0 rounded-full bg-violet-100 animate-ping opacity-60" />
          <div className="absolute inset-2 rounded-full bg-violet-200 animate-ping opacity-40" style={{ animationDelay: "0.3s" }} />
          <div className="relative w-full h-full rounded-full bg-gradient-to-br from-violet-500 to-pink-500 flex items-center justify-center shadow-lg shadow-violet-300">
            <Zap size={40} className="text-white fill-white" />
          </div>
        </div>

        <h2 className="text-xl font-bold text-gray-900 mb-1">Finding Your Match ⚡</h2>
        <p className="text-sm text-gray-500 mb-5">
          Searching for someone compatible right now…
        </p>

        {/* Timer */}
        <div className="inline-flex items-center gap-2 px-4 py-2 bg-gray-50 rounded-full mb-6">
          <Clock size={14} className="text-gray-400" />
          <span className="text-sm font-mono font-semibold text-gray-700">{mins}:{secs}</span>
        </div>

        <button
          onClick={onCancel}
          className="w-full py-3 rounded-xl border-2 border-gray-200 text-gray-500 font-semibold text-sm hover:bg-gray-50 transition"
        >
          Cancel Search
        </button>
      </div>
    </div>
  );
}

// ─── Instant Match: Confirmation Modal (5-second countdown) ──────────────────
function InstantMatchFoundModal({ me, partner, countdown, onStartChat, onSkip }) {
  // Stroke-dasharray trick for the circular countdown ring
  const RADIUS = 28;
  const CIRC   = 2 * Math.PI * RADIUS;
  const progress = countdown / 5; // 0→1 as timer counts down
  const dash     = CIRC * progress;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-white rounded-3xl w-full max-w-sm shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-br from-violet-500 to-pink-500 px-6 pt-7 pb-10 text-center">
          <div className="text-3xl mb-1">⚡</div>
          <h2 className="text-2xl font-black text-white">Instant Match!</h2>
          <p className="text-white/80 text-sm mt-1">Starting chat in…</p>
        </div>

        {/* Avatars */}
        <div className="flex items-center justify-center gap-3 -mt-8 mb-4 px-6">
          <img
            src={me?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(me?.name || "Me")}&bg=ec4899&color=fff&size=80`}
            alt="You"
            className="w-16 h-16 rounded-full object-cover border-4 border-white shadow-lg"
          />
          {/* Circular countdown ring in the middle */}
          <div className="relative w-12 h-12 flex-shrink-0 flex items-center justify-center">
            <svg className="absolute inset-0 w-full h-full -rotate-90" viewBox="0 0 64 64">
              <circle cx="32" cy="32" r={RADIUS} fill="none" stroke="#e9d5ff" strokeWidth="5" />
              <circle cx="32" cy="32" r={RADIUS} fill="none" stroke="#7c3aed"
                strokeWidth="5" strokeLinecap="round"
                strokeDasharray={`${dash} ${CIRC}`}
                style={{ transition: "stroke-dasharray 0.9s linear" }} />
            </svg>
            <span className="relative text-lg font-black text-violet-700">{countdown}</span>
          </div>
          <img
            src={partner.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(partner.name || "?")}&bg=7c3aed&color=fff&size=80`}
            alt={partner.name}
            className="w-16 h-16 rounded-full object-cover border-4 border-white shadow-lg"
          />
        </div>

        {/* Partner info */}
        <div className="px-6 text-center space-y-0.5 mb-5">
          <p className="font-bold text-gray-900 text-lg">
            {partner.name}{partner.age ? `, ${partner.age}` : ""}
          </p>
          {partner.city && (
            <p className="text-sm text-gray-500 flex items-center justify-center gap-1">
              <MapPin size={12} /> {partner.city}
            </p>
          )}
        </div>

        {/* Action buttons */}
        <div className="px-6 pb-6 space-y-2.5">
          <button
            onClick={onStartChat}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-violet-500 to-pink-500 text-white font-bold text-sm hover:opacity-90 active:scale-95 transition shadow-md shadow-violet-200 flex items-center justify-center gap-2"
          >
            <MessageCircle size={16} /> Start Chatting Now
          </button>
          <button
            onClick={onSkip}
            className="w-full py-3 rounded-xl border-2 border-gray-200 text-gray-400 font-semibold text-sm hover:bg-gray-50 hover:text-red-400 hover:border-red-200 transition"
          >
            Skip — find someone else
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Instant Match: Live Chat Overlay ────────────────────────────────────────
function InstantMatchChatOverlay({
  me, partner, matchId, messages, ended, inviteStatus, accepted,
  onSend, onLeave, onSendInvite, onAcceptInvite, onDeclineInvite,
}) {
  const [text, setText] = useState("");
  const bottomRef = useRef(null);
  const myId = me?.id;

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  function handleKeyDown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }

  function submit() {
    const t = text.trim();
    if (!t) return;
    setText("");
    onSend(t);
  }

  // Has partner sent at least one message?
  const partnerHasMessaged = messages.some(m => m.sender_id !== myId);

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-white">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 bg-gradient-to-r from-violet-500 to-pink-500 text-white flex-shrink-0">
        <img
          src={partner.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(partner.name || "?")}&bg=7c3aed&color=fff&size=64`}
          alt={partner.name}
          className="w-10 h-10 rounded-full object-cover border-2 border-white/60 flex-shrink-0"
        />
        <div className="flex-1 min-w-0">
          <p className="font-bold text-sm leading-tight truncate">
            {partner.name}{partner.age ? `, ${partner.age}` : ""}
          </p>
          <p className="text-white/70 text-xs flex items-center gap-1">
            <Zap size={10} className="fill-white/70" />
            Instant Match · temporary chat
          </p>
        </div>
        {/* Friend invite button */}
        {!ended && !accepted && inviteStatus !== "received" && (
          <button
            onClick={onSendInvite}
            disabled={inviteStatus === "sent"}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition flex-shrink-0 ${
              inviteStatus === "sent"
                ? "bg-white/20 text-white/60 cursor-default"
                : "bg-white/20 hover:bg-white/30 text-white"
            }`}
            title={inviteStatus === "sent" ? "Friend invite sent — waiting for response" : "Add as friend"}
          >
            <UserPlus size={13} />
            {inviteStatus === "sent" ? "Invited" : "Add Friend"}
          </button>
        )}
        {/* Leave button */}
        <button
          onClick={onLeave}
          className="p-1.5 rounded-lg hover:bg-white/20 transition flex-shrink-0"
          title="Leave chat"
        >
          <X size={18} />
        </button>
      </div>

      {/* Friend invite received banner */}
      {inviteStatus === "received" && !accepted && (
        <div className="flex items-center gap-3 px-4 py-3 bg-violet-50 border-b border-violet-100 flex-shrink-0">
          <UserPlus size={18} className="text-violet-600 flex-shrink-0" />
          <p className="text-sm text-violet-900 flex-1 font-medium">
            <strong>{partner.name}</strong> sent you a friend request!
          </p>
          <button
            onClick={onAcceptInvite}
            className="px-3 py-1.5 rounded-lg bg-violet-600 text-white text-xs font-semibold hover:bg-violet-700 transition"
          >
            Accept
          </button>
          <button
            onClick={onDeclineInvite}
            className="px-3 py-1.5 rounded-lg border border-gray-300 text-gray-500 text-xs font-semibold hover:bg-gray-50 transition"
          >
            Decline
          </button>
        </div>
      )}

      {/* Accepted banner (brief celebration) */}
      {accepted && (
        <div className="flex items-center justify-center gap-2 px-4 py-3 bg-green-50 border-b border-green-100 flex-shrink-0">
          <span className="text-lg">🎉</span>
          <p className="text-sm text-green-800 font-semibold">
            You're now friends! Opening your chat…
          </p>
        </div>
      )}

      {/* Chat ended banner */}
      {ended && !accepted && (
        <div className="flex items-center justify-center gap-2 px-4 py-3 bg-gray-100 border-b border-gray-200 flex-shrink-0">
          <span className="text-sm text-gray-500 font-medium">
            This instant chat has ended
          </span>
        </div>
      )}

      {/* Info banner — temporary chat notice */}
      {!ended && !accepted && (
        <div className="flex items-center gap-2 px-4 py-2 bg-amber-50 border-b border-amber-100 flex-shrink-0">
          <AlertCircle size={13} className="text-amber-500 flex-shrink-0" />
          <p className="text-xs text-amber-700">
            This is a temporary chat. Add each other as friends to keep it.
          </p>
        </div>
      )}

      {/* Messages area */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {/* Waiting state — partner hasn't messaged yet */}
        {!partnerHasMessaged && messages.length === 0 && !ended && (
          <div className="flex flex-col items-center justify-center h-full gap-3 text-center py-10">
            <div className="relative w-16 h-16">
              <div className="absolute inset-0 rounded-full bg-violet-100 animate-ping opacity-50" />
              <img
                src={partner.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(partner.name || "?")}&bg=7c3aed&color=fff&size=64`}
                alt={partner.name}
                className="relative w-16 h-16 rounded-full object-cover border-2 border-violet-300"
              />
            </div>
            <div>
              <p className="font-semibold text-gray-800">Waiting for {partner.name}…</p>
              <p className="text-xs text-gray-500 mt-1">Say hello and break the ice! 👋</p>
            </div>
          </div>
        )}

        {messages.map((msg) => {
          const isMe = msg.sender_id === myId;
          // Detect call summary messages (prefixed with emoji)
          const isCallMsg = /^[📞🎥📵]/.test(msg.content || "");
          if (isCallMsg) {
            return (
              <div key={msg.id} className="flex justify-center">
                <span className="text-xs text-gray-400 bg-gray-100 px-3 py-1 rounded-full">
                  {msg.content}
                </span>
              </div>
            );
          }
          return (
            <div key={msg.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
              {!isMe && (
                <img
                  src={partner.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(partner.name || "?")}&bg=7c3aed&color=fff&size=40`}
                  alt=""
                  className="w-7 h-7 rounded-full object-cover mr-2 mt-auto flex-shrink-0"
                />
              )}
              <div className={`max-w-[72%] ${isMe ? "items-end" : "items-start"} flex flex-col gap-0.5`}>
                <div className={`px-4 py-2.5 rounded-2xl text-sm leading-snug whitespace-pre-wrap break-words ${
                  isMe
                    ? "bg-gradient-to-br from-violet-500 to-pink-500 text-white rounded-br-sm"
                    : "bg-gray-100 text-gray-900 rounded-bl-sm"
                }`}>
                  {msg.content}
                </div>
                <span className="text-[10px] text-gray-400 px-1">{formatMsgTime(msg.created_at)}</span>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      {!ended && !accepted && (
        <div className="flex items-end gap-2 px-4 py-3 border-t border-gray-100 bg-white flex-shrink-0">
          <textarea
            value={text}
            onChange={e => setText(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={`Message ${partner.name}…`}
            maxLength={2000}
            rows={1}
            className="flex-1 resize-none rounded-2xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-violet-300 focus:border-transparent max-h-32 overflow-y-auto"
            style={{ scrollbarWidth: "none" }}
          />
          <button
            onClick={submit}
            disabled={!text.trim()}
            className="w-10 h-10 rounded-full bg-gradient-to-br from-violet-500 to-pink-500 text-white flex items-center justify-center flex-shrink-0 disabled:opacity-40 hover:opacity-90 active:scale-95 transition"
          >
            <Send size={16} />
          </button>
        </div>
      )}

      {/* Closed state — only a close button */}
      {(ended || accepted) && (
        <div className="flex justify-center px-4 py-4 border-t border-gray-100 bg-white flex-shrink-0">
          <button
            onClick={onLeave}
            className="px-8 py-2.5 rounded-xl border-2 border-gray-200 text-gray-600 font-semibold text-sm hover:bg-gray-50 transition"
          >
            Close
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Marriage Paywall Modal ───────────────────────────────────────────────────
function MarriagePaywallModal({ kind, onClose, onUpgraded, showToast }) {
  const [loading, setLoading] = useState(false);

  async function handlePurchase() {
    setLoading(true);
    try {
      const order = await api.subscriptions.order("marriage_monthly");
      if (order.is_mock) {
        await api.subscriptions.verify(order.order_id, "mock_payment_id", "mock_signature", "marriage_monthly");
        onUpgraded?.();
        return;
      }
      const rzp = new window.Razorpay({
        key: order.key_id,
        amount: order.amount_paise,
        currency: order.currency,
        name: "Serious Matrimony",
        description: "₹499/month — Unlimited access",
        order_id: order.order_id,
        prefill: order.prefill || {},
        handler: async (resp) => {
          try {
            await api.subscriptions.verify(order.order_id, resp.razorpay_payment_id, resp.razorpay_signature, "marriage_monthly");
            onUpgraded?.();
          } catch (e) {
            showToast?.(e.message || "Payment verification failed", "error");
          }
        },
      });
      rzp.open();
    } catch (e) {
      showToast?.(e.message || "Could not initiate payment", "error");
    } finally {
      setLoading(false);
    }
  }

  const isLimitHit = kind === "heart" || kind === "pass";
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden">
        <div className="bg-gradient-to-br from-purple-600 to-indigo-600 p-6 text-center text-white">
          <div className="text-4xl mb-2">🕌</div>
          <h2 className="text-xl font-bold">
            {isLimitHit ? "Free trial used up for today" : "Unlock Serious Matrimony"}
          </h2>
          <p className="text-sm text-white/80 mt-1">
            {isLimitHit
              ? "You've used your 5 free invites / 10 free passes for today."
              : "Unlimited access to India's serious matrimony pool."}
          </p>
        </div>
        <div className="p-5 space-y-3">
          <div className="flex items-center gap-3 p-3.5 bg-purple-50 rounded-xl">
            <span className="text-2xl">💍</span>
            <div>
              <p className="font-bold text-gray-900">₹499 / month</p>
              <p className="text-xs text-gray-500">Unlimited invites · Unlimited passes · Priority listing</p>
            </div>
          </div>
          <div className="flex items-center gap-2 text-xs text-gray-500 px-1">
            <span>✅</span><span>Only serious matrimony seekers in your feed</span>
          </div>
          <div className="flex items-center gap-2 text-xs text-gray-500 px-1">
            <span>✅</span><span>Women get full access for free</span>
          </div>
          <div className="flex items-center gap-2 text-xs text-gray-500 px-1">
            <span>⭐</span><span>Buy Super Invites to appear at top of her feed</span>
          </div>
          <button
            onClick={handlePurchase}
            disabled={loading}
            className="w-full py-3 rounded-2xl bg-gradient-to-r from-purple-500 to-indigo-600 text-white font-bold text-sm shadow-lg shadow-purple-200 hover:opacity-90 transition disabled:opacity-50"
          >
            {loading ? "Please wait…" : "Get ₹499/month plan"}
          </button>
          <button onClick={onClose} className="w-full text-center text-sm text-gray-400 hover:text-gray-600 py-1">
            Maybe later
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Super Invite Purchase Modal ─────────────────────────────────────────────
function SuperInvitePurchaseModal({ onClose, onPurchased, showToast, profile }) {
  const [loading, setLoading] = useState(false);

  async function handlePurchase() {
    setLoading(true);
    try {
      const order = await api.superInvites.order();
      if (order.is_mock) {
        const res = await api.superInvites.verify(order.order_id, "mock_payment_id", "mock_signature");
        onPurchased?.(res.balance);
        return;
      }
      const rzp = new window.Razorpay({
        key: order.key_id,
        amount: order.amount_paise,
        currency: order.currency,
        name: "Super Invites",
        description: "5 Super Invites — ₹100",
        order_id: order.order_id,
        prefill: order.prefill || {},
        handler: async (resp) => {
          try {
            const res = await api.superInvites.verify(order.order_id, resp.razorpay_payment_id, resp.razorpay_signature);
            onPurchased?.(res.balance);
          } catch (e) {
            showToast?.(e.message || "Payment verification failed", "error");
          }
        },
      });
      rzp.open();
    } catch (e) {
      showToast?.(e.message || "Could not initiate payment", "error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden">
        <div className="bg-gradient-to-br from-amber-400 to-purple-600 p-6 text-center text-white">
          <div className="text-4xl mb-2">⭐</div>
          <h2 className="text-xl font-bold">Buy Super Invites</h2>
          <p className="text-sm text-white/80 mt-1">Your profile goes to the top of her feed instantly</p>
        </div>
        <div className="p-5 space-y-3">
          <div className="flex items-center gap-3 p-3.5 bg-amber-50 rounded-xl border border-amber-100">
            <span className="text-2xl">⭐</span>
            <div className="flex-1">
              <p className="font-bold text-gray-900">5 Super Invites</p>
              <p className="text-xs text-gray-500">Stand out — your profile pins to the top of her Discover</p>
            </div>
            <span className="font-black text-purple-700 text-lg">₹100</span>
          </div>
          <p className="text-xs text-gray-400 px-1">Super Invites don't expire — use them whenever you want.</p>
          <button
            onClick={handlePurchase}
            disabled={loading}
            className="w-full py-3 rounded-2xl bg-gradient-to-r from-amber-400 to-purple-600 text-white font-bold text-sm shadow-lg hover:opacity-90 transition disabled:opacity-50"
          >
            {loading ? "Please wait…" : "Buy 5 for ₹100"}
          </button>
          <button onClick={onClose} className="w-full text-center text-sm text-gray-400 hover:text-gray-600 py-1">
            Not now
          </button>
        </div>
      </div>
    </div>
  );
}

function GiftLikeModal({ name, onSend, onClose }) {
  const [msg, setMsg] = useState("");
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-br from-amber-400 to-orange-400 px-6 pt-8 pb-6 flex flex-col items-center text-center">
          <div className="w-16 h-16 rounded-full bg-white/30 flex items-center justify-center mb-3">
            <Gift size={32} className="text-white" />
          </div>
          <h3 className="text-xl font-bold text-white">Super Like ✨</h3>
          <p className="text-white/90 text-sm mt-1">
            {name} will see this highlighted in their notifications
          </p>
        </div>
        {/* Message */}
        <div className="px-6 py-5">
          <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
            Personal message (optional)
          </label>
          <textarea
            value={msg}
            onChange={e => setMsg(e.target.value)}
            maxLength={200}
            rows={3}
            placeholder={`Say something nice to ${name}…`}
            className="w-full resize-none rounded-xl border border-gray-200 px-4 py-3 text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent placeholder-gray-400"
          />
          <p className="text-right text-[11px] text-gray-400 mt-1">{msg.length}/200</p>
        </div>
        {/* Actions */}
        <div className="px-6 pb-6 flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50 active:scale-95 transition"
          >
            Cancel
          </button>
          <button
            onClick={() => onSend(msg.trim() || null)}
            className="flex-1 py-3 rounded-xl bg-gradient-to-r from-amber-400 to-orange-400 text-white text-sm font-bold shadow-lg shadow-amber-400/40 active:scale-95 transition"
          >
            Send Gift 🎁
          </button>
        </div>
      </div>
    </div>
  );
}


// ─── Messages View ────────────────────────────────────────────────────────────
function MessagesView({ userId, showToast, conversations, setConversations, convoLoading, sendTyping, typingMatchId, onStartCall, onlinePartners = new Set() }) {
  const [activeConvo, setActiveConvo]   = useState(null);
  const [messages, setMessages]         = useState([]);
  const [chatLoading, setChatLoading]   = useState(false);
  const [draft, setDraft]               = useState("");
  const [sending, setSending]           = useState(false);
  const [search, setSearch]             = useState("");
  const [openProfileId, setOpenProfileId] = useState(null);
  // Gift UI state — picker modal (send) + transient received overlay.
  // `giftPickerContext` is "chat" (in-composer) or "invite" (on the
  // match-again banner) so the picker knows which flow to trigger.
  const [giftPickerContext, setGiftPickerContext] = useState(null);
  const [incomingGift, setIncomingGift] = useState(null);
  const bottomRef = useRef();
  const inputRef  = useRef();
  const typingTimer = useRef();

  // Expose active conversation via window so parent can route socket events here
  useEffect(() => {
    window.__activeMatchId = activeConvo?.match_id || null;
    return () => { if (window.__activeMatchId === activeConvo?.match_id) window.__activeMatchId = null; };
  }, [activeConvo]);

  // Subscribe to real-time events from the parent-provided socket
  useEffect(() => {
    function onRealtime(e) {
      const { kind, payload } = e.detail;
      if (kind === "new_message") {
        const { match_id, message } = payload;
        if (activeConvo?.match_id === match_id) {
          setMessages(prev => prev.some(m => m.id === message.id) ? prev : [...prev, message]);
          if (message.sender_id !== userId) {
            api.messages.markRead(match_id).catch(() => {});
            // Chat-context gift just landed — pop the animated overlay.
            // Server enriches the ws payload with { gift, gift_send } so
            // we can render the reveal without a second fetch.
            if (message.gift_send_id && message.gift) {
              setIncomingGift({
                ...message.gift,
                receiver_share: message.gift_send?.receiver_share,
                _ts: message.id,
              });
            }
          }
        }
      } else if (kind === "messages_read") {
        const { match_id, reader_id } = payload;
        if (reader_id !== userId && activeConvo?.match_id === match_id) {
          setMessages(prev => prev.map(m => m.sender_id === userId ? { ...m, is_read: true } : m));
        }
      } else if (kind === "messages_delivered") {
        const { match_id, message_ids } = payload;
        if (activeConvo?.match_id === match_id) {
          const idSet = new Set(message_ids);
          setMessages(prev => prev.map(m => idSet.has(m.id) ? { ...m, is_delivered: true } : m));
        }
      } else if (kind === "match_removed") {
        const { match_id, removed_by } = payload;
        if (activeConvo?.match_id === match_id) {
          // Keep the chat open but flip it to read-only mode
          const nowIso = new Date().toISOString();
          setActiveConvo(curr => curr ? { ...curr, removed_at: nowIso, removed_by } : curr);
          // Close the profile detail modal if the partner just unfriended us
          if (removed_by && removed_by !== userId) {
            setOpenProfileId(null);
            showToast("This conversation has been ended");
          }
        }
      }
    }
    window.addEventListener("chat:event", onRealtime);
    return () => window.removeEventListener("chat:event", onRealtime);
  }, [activeConvo, userId]);

  // Let the notification bell open a conversation directly
  useEffect(() => {
    function onOpenConvo(e) {
      const matchId = e.detail?.match_id;
      if (!matchId) return;
      const target = conversations.find(c => c.match_id === matchId);
      if (target) setActiveConvo(target);
    }
    window.addEventListener("chat:openConversation", onOpenConvo);
    return () => window.removeEventListener("chat:openConversation", onOpenConvo);
  }, [conversations]);

  // Load messages for active conversation
  useEffect(() => {
    if (!activeConvo) return;
    setChatLoading(true);
    Promise.all([
      api.messages.history(activeConvo.match_id),
      // Pull gift sends for this chat so historical gift messages keep
      // their card appearance across sessions (the backend joins catalog
      // into the gift_sends row). Empty array on failure — not critical.
      api.gifts.forMatch(activeConvo.match_id).catch(() => []),
    ])
      .then(([msgs, gifts]) => {
        // Index gift sends by message_id, hydrate each message row with
        // { gift, gift_send } so rendering is a single pass.
        const byMsgId = new Map();
        for (const gs of gifts) {
          if (gs.message_id) byMsgId.set(gs.message_id, gs);
        }
        const hydrated = msgs.map(m => {
          const gs = byMsgId.get(m.id);
          if (!gs) return m;
          return { ...m, gift: gs.gift, gift_send: gs };
        });
        setMessages(hydrated);
        api.messages.markRead(activeConvo.match_id).catch(() => {});
        setConversations(prev => prev.map(c =>
          c.match_id === activeConvo.match_id ? { ...c, unread_count: 0 } : c
        ));
      })
      .catch(e => showToast(e.message, "error"))
      .finally(() => setChatLoading(false));
  }, [activeConvo, showToast, setConversations]);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function send() {
    if (!draft.trim() || !activeConvo || sending) return;
    setSending(true);
    const text = draft.trim();
    setDraft("");
    try {
      const msg = await api.messages.send(activeConvo.match_id, text);
      setMessages(prev => prev.some(m => m.id === msg.id) ? prev : [...prev, msg]);
      setConversations(prev => prev.map(c =>
        c.match_id === activeConvo.match_id
          ? { ...c, last_message: { content: text, sender_id: userId, created_at: msg.created_at } }
          : c
      ));
    } catch (e) {
      setDraft(text);
      showToast(e.message, "error");
    } finally {
      setSending(false);
      inputRef.current?.focus();
    }
  }

  function handleDraftChange(val) {
    setDraft(val);
    if (!activeConvo) return;
    clearTimeout(typingTimer.current);
    sendTyping?.(activeConvo.match_id);
    typingTimer.current = setTimeout(() => {}, 1500);
  }

  const filtered = conversations.filter(c =>
    c.partner?.name?.toLowerCase().includes(search.toLowerCase())
  );
  const partnerTyping = activeConvo && typingMatchId === activeConvo.match_id;

  return (
    <div className="flex h-full overflow-hidden">
      {/* ── Conversations Sidebar ── */}
      <div className={`w-full md:w-80 md:flex-shrink-0 border-r border-gray-100 flex-col bg-white ${activeConvo ? "hidden md:flex" : "flex"}`}>
        <div className="p-4 border-b border-gray-100">
          <h2 className="font-bold text-gray-800 mb-3">Messages</h2>
          <div className="relative">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search conversations…"
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-pink-400 focus:border-transparent" />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {convoLoading ? (
            <div className="p-4 space-y-3">
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="flex gap-3 animate-pulse">
                  <div className="w-12 h-12 rounded-full bg-gray-200 flex-shrink-0" />
                  <div className="flex-1 space-y-2 pt-1">
                    <div className="h-3 bg-gray-200 rounded w-2/3" />
                    <div className="h-2.5 bg-gray-200 rounded w-4/5" />
                  </div>
                </div>
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 px-6 text-center">
              <MessageCircle size={40} className="text-gray-200 mb-3" />
              <p className="text-sm font-semibold text-gray-500">No conversations yet</p>
              <p className="text-xs text-gray-400 mt-1">Match with someone to start chatting</p>
            </div>
          ) : (
            filtered.map(c => {
              const isActive = activeConvo?.match_id === c.match_id;
              const lastMsg = c.last_message;
              return (
                <button key={c.match_id} onClick={() => setActiveConvo(c)}
                  className={`w-full flex items-center gap-3 px-4 py-3 transition-all text-left ${
                    isActive ? "bg-pink-50 border-r-2 border-pink-500" : "hover:bg-gray-50"
                  }`}>
                  <div className="relative flex-shrink-0"
                    onClick={(e) => { e.stopPropagation(); c.partner?.id && setOpenProfileId(c.partner.id); }}
                    title="View profile"
                  >
                    <img src={avatar(c.partner)} alt={c.partner?.name}
                      className={`w-12 h-12 rounded-full object-cover ring-2 ring-transparent hover:ring-pink-400 transition ${c.removed_at ? "grayscale" : ""}`} />
                    {!c.removed_at && onlinePartners.has(c.partner?.id) && (
                      <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-400 rounded-full border-2 border-white" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <p className={`text-sm truncate ${isActive ? "text-pink-700 font-bold" : "text-gray-800 font-semibold"}`}>
                        {c.partner?.name}
                      </p>
                      <span className="text-[10px] text-gray-400 flex-shrink-0 ml-1">
                        {lastMsg ? timeAgo(lastMsg.created_at) : timeAgo(c.matched_at)}
                      </span>
                    </div>
                    <div className="flex items-center justify-between mt-0.5 gap-1">
                      <p className="text-xs text-gray-400 truncate max-w-[150px]">
                        {c.removed_at ? (
                          <span className="italic text-rose-500">Removed as friend</span>
                        ) : lastMsg ? (
                          lastMsg.sender_id === userId ? `You: ${lastMsg.content}` : lastMsg.content
                        ) : (
                          "Matched! Say hello 👋"
                        )}
                      </p>
                      {c.unread_count > 0 && (
                        <span className="ml-1 flex-shrink-0 bg-pink-500 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center">
                          {c.unread_count > 9 ? "9+" : c.unread_count}
                        </span>
                      )}
                    </div>
                  </div>
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* ── Chat Panel ── */}
      {activeConvo ? (
        <div className="flex-1 flex flex-col min-w-0 w-full">
          {/* Chat header */}
          <div
            onClick={() => activeConvo.partner?.id && setOpenProfileId(activeConvo.partner.id)}
            className="bg-white border-b border-gray-100 px-4 md:px-5 py-3 flex items-center gap-3 flex-shrink-0 cursor-pointer hover:bg-gray-50 transition"
            title="View profile"
          >
            <button
              onClick={(e) => { e.stopPropagation(); setActiveConvo(null); }}
              className="md:hidden p-1.5 -ml-1 rounded-lg hover:bg-gray-100 flex-shrink-0"
              aria-label="Back to conversations"
            >
              <ChevronLeft size={20} className="text-gray-600" />
            </button>
            <img src={avatar(activeConvo.partner)} alt={activeConvo.partner?.name}
              className="w-10 h-10 rounded-full object-cover" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <p className="font-semibold text-gray-800 text-sm hover:text-pink-600 transition truncate">{activeConvo.partner?.name}</p>
                {activeConvo.removed_at && (
                  <span className="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full bg-rose-50 text-rose-600 border border-rose-200 flex-shrink-0">
                    Removed as friend
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-400">
                {activeConvo.removed_at ? (
                  activeConvo.removed_by === userId
                    ? "You ended this conversation"
                    : "They ended this conversation"
                ) : partnerTyping ? (
                  <span className="text-pink-500 font-medium">typing…</span>
                ) : onlinePartners.has(activeConvo.partner?.id) ? (
                  <span className="text-green-500 font-medium">Online</span>
                ) : activeConvo.partner?.last_seen ? (
                  `Last seen ${timeAgo(activeConvo.partner.last_seen)} ago`
                ) : (
                  <>
                    {activeConvo.partner?.city && `${activeConvo.partner.city} · `}
                    Matched {timeAgo(activeConvo.matched_at)} ago
                  </>
                )}
              </p>
            </div>

            {/* Voice + video call buttons. Disabled for removed matches;
                the useCall hook gates tier permission server-side on
                call_invite so free/Plus users get a Pro paywall flash
                instead of a started call. */}
            {!activeConvo.removed_at && onStartCall && (
              <div className="flex items-center gap-1 flex-shrink-0">
                <button
                  onClick={(e) => { e.stopPropagation(); onStartCall(activeConvo.match_id, activeConvo.partner, "audio"); }}
                  className="p-2 rounded-full text-gray-600 hover:bg-pink-50 hover:text-pink-600 transition"
                  aria-label="Voice call"
                  title="Voice call"
                >
                  <Phone size={18} />
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); onStartCall(activeConvo.match_id, activeConvo.partner, "video"); }}
                  className="p-2 rounded-full text-gray-600 hover:bg-pink-50 hover:text-pink-600 transition"
                  aria-label="Video call"
                  title="Video call"
                >
                  <Video size={18} />
                </button>
              </div>
            )}
          </div>

          {/* Messages — tiled heart pattern + soft pink gradient so the
              chat feels warm rather than like a plain grey form. The
              SVG is inlined as a data-URL so there are zero extra HTTP
              hits and no asset pipeline dependency. */}
          <div
            className="flex-1 overflow-y-auto p-4 space-y-3 relative"
            style={{
              backgroundColor: "#fdf8fb",
              backgroundImage: `
                linear-gradient(180deg, rgba(253,232,240,0.55) 0%, rgba(253,248,251,0.35) 45%, rgba(243,232,255,0.35) 100%),
                url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 80 80'><path d='M40 62 C 40 62 16 46 16 30 C 16 22 22 16 29 16 C 34 16 38 19 40 23 C 42 19 46 16 51 16 C 58 16 64 22 64 30 C 64 46 40 62 40 62 Z' fill='%23f9a8c9' opacity='0.14'/></svg>")
              `,
              backgroundSize: "auto, 80px 80px",
            }}
          >
            {chatLoading ? (
              <div className="flex items-center justify-center h-full">
                <div className="w-6 h-6 border-2 border-pink-400 border-t-transparent rounded-full animate-spin" />
              </div>
            ) : messages.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full text-center">
                <div className="text-4xl mb-3">👋</div>
                <p className="text-sm font-semibold text-gray-600">You matched with {activeConvo.partner?.name}!</p>
                <p className="text-xs text-gray-400 mt-1">Be the first to say hello</p>
              </div>
            ) : (
              messages.map((msg, idx) => {
                const isMe = msg.sender_id === userId;
                const showDate = idx === 0 || (
                  new Date(msg.created_at).toDateString() !==
                  new Date(messages[idx - 1].created_at).toDateString()
                );
                // Server-formatted call summaries start with one of these
                // prefixes. Detect so we can render a centered system chip
                // instead of a user bubble. Anything that accidentally
                // matches (e.g. user typed "📞 hey") still falls through
                // to the normal bubble path because we also check the
                // trailing shape ("· duration" or "Missed …").
                const isCallSummary =
                  typeof msg.content === "string" &&
                  /^(📞|🎥|📵)\s/.test(msg.content) &&
                  (/·\s\d/.test(msg.content) || /^📵\s*Missed /.test(msg.content));
                return (
                  <div key={msg.id}>
                    {showDate && (
                      <div className="text-center my-2">
                        <span className="text-[10px] text-gray-400 bg-white px-3 py-1 rounded-full border border-gray-100">
                          {new Date(msg.created_at).toLocaleDateString([], { weekday: "long", month: "short", day: "numeric" })}
                        </span>
                      </div>
                    )}
                    {isCallSummary ? (
                      // Centered system chip — like WhatsApp's "📞 You
                      // called · 2m 15s". No bubble, no avatar, just the
                      // content + time on a neutral pill.
                      <div className="text-center my-2">
                        <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-medium border ${
                          msg.content.startsWith("📵")
                            ? "bg-rose-50 text-rose-600 border-rose-200"
                            : "bg-gray-50 text-gray-600 border-gray-200"
                        }`}>
                          {isMe ? msg.content.replace(/^(📞|🎥|📵)\s/, "$1 You: ")
                                : msg.content}
                          <span className="text-gray-400">· {formatMsgTime(msg.created_at)}</span>
                        </span>
                      </div>
                    ) : (
                    <div className={`flex items-end gap-2 ${isMe ? "justify-end" : "justify-start"}`}>
                      {!isMe && (
                        <img src={avatar(activeConvo.partner)} alt=""
                          className="w-7 h-7 rounded-full object-cover flex-shrink-0 mb-0.5" />
                      )}
                      <div className={`max-w-[65%] ${isMe ? "items-end" : "items-start"} flex flex-col`}>
                        {msg.gift_send_id && msg.gift ? (
                          // Gift messages replace the plain bubble with a
                          // highlighted gift card so they stand out
                          // permanently in chat history.
                          <GiftChatCard gift={msg.gift} cost={msg.gift_send?.cost} isMine={isMe} />
                        ) : (
                          <div className={`px-4 py-2.5 rounded-2xl text-sm leading-relaxed ${
                            isMe
                              ? "bg-gradient-to-br from-pink-500 to-pink-600 text-white rounded-br-sm"
                              : "bg-white text-gray-800 border border-gray-100 rounded-bl-sm shadow-sm"
                          }`}>
                            {msg.content}
                          </div>
                        )}
                        <div className={`flex items-center gap-1 mt-0.5 ${isMe ? "justify-end" : ""}`}>
                          <span className="text-[10px] text-gray-400">{formatMsgTime(msg.created_at)}</span>
                          {isMe && (
                            msg.is_read
                              ? <CheckCheck size={11} className="text-pink-400" />
                              : msg.is_delivered
                                ? <CheckCheck size={11} className="text-gray-300" />
                                : <Check size={11} className="text-gray-300" />
                          )}
                        </div>
                      </div>
                    </div>
                    )}
                  </div>
                );
              })
            )}
            <div ref={bottomRef} />
          </div>

          {/* Input bar — or read-only notice if this match has been unfriended */}
          {activeConvo.removed_at ? (
            <div className="bg-rose-50 border-t border-rose-200 px-4 py-3 flex items-center gap-3 flex-shrink-0">
              <UserMinus size={16} className="text-rose-500 flex-shrink-0" />
              <p className="text-xs text-rose-700 leading-snug flex-1 min-w-0">
                {activeConvo.removed_by === userId
                  ? "You've removed this friend. Messages are preserved but you can't send new ones."
                  : `${activeConvo.partner?.name || "This person"} has removed you as a friend. The conversation is read-only.`}
              </p>
              <GiftButton
                onClick={() => setGiftPickerContext("invite")}
                label="Invite + Gift"
              />
              <button
                type="button"
                onClick={async () => {
                  if (!activeConvo.partner?.id) return;
                  try {
                    const res = await api.matches.reinvite(activeConvo.partner.id);
                    if (res.restored) {
                      // Unilateral restore (we were the remover). Flip local state.
                      setActiveConvo(curr => curr ? { ...curr, removed_at: null, removed_by: null } : curr);
                      setConversations(prev => prev.map(c =>
                        c.match_id === activeConvo.match_id
                          ? { ...c, removed_at: null, removed_by: null }
                          : c
                      ));
                      showToast(`You're friends again with ${activeConvo.partner.name} 💕`);
                    } else if (res.already_pending) {
                      showToast("Invitation already sent — waiting for them to respond");
                    } else {
                      showToast(`Invite sent to ${activeConvo.partner.name}`);
                    }
                  } catch (e) {
                    showToast(e.message || "Could not send invite", "error");
                  }
                }}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gradient-to-r from-pink-500 to-pink-600 text-white text-xs font-semibold hover:opacity-90 transition flex-shrink-0 shadow-sm"
              >
                <UserPlus size={13} /> Match Again
              </button>
            </div>
          ) : (
            <div className="bg-white border-t border-gray-100 px-4 py-3 flex gap-2 items-end flex-shrink-0">
              <GiftButton onClick={() => setGiftPickerContext("chat")} />
              <textarea
                ref={inputRef}
                value={draft}
                onChange={e => handleDraftChange(e.target.value)}
                onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }}
                placeholder="Type a message… (Enter to send)"
                rows={1}
                className="flex-1 resize-none border border-gray-200 rounded-2xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-pink-400 focus:border-transparent transition max-h-32 overflow-y-auto"
                style={{ minHeight: "44px" }}
              />
              <button onClick={send} disabled={!draft.trim() || sending}
                className="w-11 h-11 rounded-2xl bg-gradient-to-br from-pink-500 to-pink-600 text-white flex items-center justify-center hover:opacity-90 active:scale-95 transition disabled:opacity-40 flex-shrink-0 shadow-md shadow-pink-200">
                {sending
                  ? <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                  : <Send size={16} />
                }
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="hidden md:flex flex-1 flex-col items-center justify-center bg-gray-50 text-center px-8">
          <div className="w-20 h-20 rounded-full bg-pink-50 flex items-center justify-center mb-4">
            <MessageCircle size={36} className="text-pink-300" />
          </div>
          <h3 className="text-lg font-bold text-gray-700 mb-1">Select a conversation</h3>
          <p className="text-sm text-gray-400">Choose a match from the left to start chatting</p>
        </div>
      )}

      {openProfileId && (
        <ProfileDetailModal
          userId={openProfileId}
          showToast={showToast}
          onClose={() => setOpenProfileId(null)}
          {...(activeConvo?.removed_at
            ? {} /* already unfriended — just a read-only profile view */
            : {
                onUnmatch: async (partnerId, partnerProfile) => {
                  try {
                    await api.matches.unmatch(partnerId);
                    // Soft-remove: keep the conversation, just mark it ended so
                    // both sides still have the history as a read-only archive.
                    const nowIso = new Date().toISOString();
                    setConversations(prev => prev.map(c =>
                      c.partner?.id === partnerId
                        ? { ...c, removed_at: nowIso, removed_by: userId }
                        : c
                    ));
                    setActiveConvo(curr =>
                      curr?.partner?.id === partnerId
                        ? { ...curr, removed_at: nowIso, removed_by: userId }
                        : curr
                    );
                    showToast(`Removed ${partnerProfile?.name || "friend"}. Chat is now read-only.`);
                  } catch (e) {
                    showToast(e.message || "Could not remove friend", "error");
                  }
                },
              })}
        />
      )}

      {/* Gift picker — shared by chat composer and invite banner. */}
      <GiftPickerModal
        open={!!giftPickerContext && !!activeConvo?.partner?.id}
        onClose={() => setGiftPickerContext(null)}
        context={giftPickerContext || "chat"}
        receiverId={activeConvo?.partner?.id}
        receiverName={activeConvo?.partner?.name || "them"}
        matchId={activeConvo?.match_id}
        showToast={showToast}
        onSent={(res) => {
          if (res?.context === "invite") {
            const r = res.reinvite;
            if (r?.restored) {
              setActiveConvo(curr => curr ? { ...curr, removed_at: null, removed_by: null } : curr);
              setConversations(prev => prev.map(c =>
                c.match_id === activeConvo.match_id
                  ? { ...c, removed_at: null, removed_by: null }
                  : c
              ));
            }
          } else if (res?.context === "chat" && res.server?.message) {
            // Server returns the companion message row with gift payload
            // — splice it in so the sender sees their gift card instantly.
            const m = res.server.message;
            setMessages(prev => prev.some(x => x.id === m.id) ? prev : [...prev, m]);
          }
        }}
      />

      {/* Transient received-gift overlay. */}
      <GiftReceivedOverlay
        gift={incomingGift}
        from={activeConvo?.partner?.name}
        onClose={() => setIncomingGift(null)}
      />
    </div>
  );
}

// ─── Likes View ───────────────────────────────────────────────────────────────
function LikesView({ showToast }) {
  const [tab, setTab] = useState("received"); // "received" | "sent" | "disliked"
  const [sentFilter, setSentFilter] = useState("all"); // all | pending | accepted | rejected
  const [likedMe, setLikedMe] = useState([]);
  const [sent, setSent] = useState([]);
  const [disliked, setDisliked] = useState([]); // people I passed on
  const [loading, setLoading] = useState(true);
  const [openProfileId, setOpenProfileId] = useState(null);
  const [openContext, setOpenContext] = useState("received"); // which tab opened the modal

  const loadAll = () => {
    setLoading(true);
    Promise.all([api.matches.likedMe(), api.matches.likesSent(), api.matches.dislikedByMe()])
      .then(([r, s, d]) => { setLikedMe(r); setSent(s); setDisliked(d); })
      .catch(e => showToast(e.message, "error"))
      .finally(() => setLoading(false));
  };

  useEffect(() => { loadAll(); /* eslint-disable-next-line */ }, []);

  const acceptLike = async (personOrId) => {
    const id = typeof personOrId === "string" ? personOrId : personOrId.id;
    try {
      const res = await api.matches.like(id);
      setLikedMe(prev => prev.filter(p => p.id !== id));
      showToast(res.matched ? "🎉 It's a match!" : "❤️ Accepted!");
      api.matches.likesSent().then(setSent).catch(() => {});
    } catch (e) { showToast(e.message, "error"); }
  };

  const rejectLike = async (personOrId) => {
    const id = typeof personOrId === "string" ? personOrId : personOrId.id;
    try {
      await api.matches.reject(id);
      setLikedMe(prev => prev.filter(p => p.id !== id));
      showToast("Rejected");
    } catch (e) { showToast(e.message, "error"); }
  };

  const openProfile = (id, ctx) => {
    setOpenContext(ctx);
    setOpenProfileId(id);
  };

  const sendRequest = async (personOrId) => {
    const id = typeof personOrId === "string" ? personOrId : personOrId.id;
    try {
      const res = await api.matches.like(id);
      setDisliked(prev => prev.filter(x => x.profile.id !== id));
      showToast(res.matched ? "🎉 It's a match!" : "❤️ Request sent");
      api.matches.likesSent().then(setSent).catch(() => {});
    } catch (e) { showToast(e.message, "error"); }
  };

  const filteredSent = sent.filter(x => sentFilter === "all" ? true : x.status === sentFilter);
  const counts = {
    all: sent.length,
    pending: sent.filter(x => x.status === "pending").length,
    accepted: sent.filter(x => x.status === "accepted").length,
    rejected: sent.filter(x => x.status === "rejected").length,
  };

  return (
    <div className="p-5">
      {/* Top tabs */}
      <div className="flex items-center gap-2 mb-5 border-b border-gray-200">
        <button
          onClick={() => setTab("received")}
          className={`px-4 py-2.5 text-sm font-semibold border-b-2 transition ${
            tab === "received"
              ? "border-pink-500 text-pink-600"
              : "border-transparent text-gray-500 hover:text-gray-700"
          }`}
        >
          Received {likedMe.length > 0 && <span className="ml-1 text-xs bg-pink-100 text-pink-600 px-2 py-0.5 rounded-full">{likedMe.length}</span>}
        </button>
        <button
          onClick={() => setTab("sent")}
          className={`px-4 py-2.5 text-sm font-semibold border-b-2 transition ${
            tab === "sent"
              ? "border-pink-500 text-pink-600"
              : "border-transparent text-gray-500 hover:text-gray-700"
          }`}
        >
          Sent {sent.length > 0 && <span className="ml-1 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">{sent.length}</span>}
        </button>
        <button
          onClick={() => setTab("disliked")}
          className={`px-4 py-2.5 text-sm font-semibold border-b-2 transition ${
            tab === "disliked"
              ? "border-pink-500 text-pink-600"
              : "border-transparent text-gray-500 hover:text-gray-700"
          }`}
        >
          Disliked by me {disliked.length > 0 && <span className="ml-1 text-xs bg-rose-100 text-rose-600 px-2 py-0.5 rounded-full">{disliked.length}</span>}
        </button>
      </div>

      {/* Filter chips (only on Sent) */}
      {tab === "sent" && (
        <div className="flex flex-wrap items-center gap-2 mb-5">
          {[
            { id: "all",      label: "All",       cls: "bg-gray-900 text-white" },
            { id: "pending",  label: "Pending",   cls: "bg-amber-500 text-white" },
            { id: "accepted", label: "Accepted",  cls: "bg-emerald-500 text-white" },
            { id: "rejected", label: "Rejected",  cls: "bg-rose-500 text-white" },
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setSentFilter(f.id)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition ${
                sentFilter === f.id
                  ? f.cls + " shadow"
                  : "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
              }`}
            >
              {f.label} <span className="opacity-70 ml-1">({counts[f.id]})</span>
            </button>
          ))}
        </div>
      )}

      {/* Loading skeleton */}
      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="aspect-[3/4] rounded-2xl bg-gray-200 animate-pulse" />
          ))}
        </div>
      ) : tab === "received" ? (
        likedMe.length === 0 ? (
          <EmptyState
            icon={<Heart size={36} className="text-pink-300" />}
            title="No likes yet"
            subtitle="Keep your profile complete and photos up to date to get more likes!"
          />
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
            {likedMe.map(person => (
              <div key={person.id} className="bg-white rounded-2xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-md transition">
                <div
                  className="relative aspect-[3/4] bg-pink-50 cursor-pointer"
                  onClick={() => openProfile(person.id, "received")}
                >
                  <img src={avatar(person)} alt={person.name} className="w-full h-full object-cover" />
                  <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/70 to-transparent p-3">
                    <p className="text-white font-bold text-sm">{person.name}, {person.age}</p>
                    {person.city && <p className="text-white/70 text-xs">{person.city}</p>}
                  </div>
                </div>
                <div className="p-3 space-y-2">
                  <p className="text-xs text-gray-400">Liked your profile ❤️</p>
                  <div className="flex gap-2">
                    <button
                      onClick={(e) => { e.stopPropagation(); rejectLike(person); }}
                      className="flex-1 py-2 rounded-xl border border-gray-200 text-gray-600 text-xs font-semibold hover:bg-gray-50 transition flex items-center justify-center gap-1"
                      title="Reject"
                    >
                      <X size={14} /> Reject
                    </button>
                    <button
                      onClick={(e) => { e.stopPropagation(); acceptLike(person); }}
                      className="flex-1 py-2 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white text-xs font-semibold hover:opacity-90 transition flex items-center justify-center gap-1"
                      title="Accept"
                    >
                      <Heart size={14} className="fill-white" /> Accept
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )
      ) : tab === "sent" ? (
        filteredSent.length === 0 ? (
          <EmptyState
            icon={<Heart size={36} className="text-pink-300" />}
            title={sent.length === 0 ? "No likes sent yet" : `No ${sentFilter} likes`}
            subtitle={sent.length === 0 ? "Browse Discover and send some likes!" : "Try a different filter."}
          />
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
            {filteredSent.map(({ profile: person, status, sent_at }) => (
              <div
                key={person.id}
                onClick={() => openProfile(person.id, "sent")}
                className="bg-white rounded-2xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-md transition cursor-pointer"
              >
                <div className="relative aspect-[3/4] bg-pink-50">
                  <img src={avatar(person)} alt={person.name} className="w-full h-full object-cover" />
                  <StatusBadge status={status} />
                  <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/70 to-transparent p-3">
                    <p className="text-white font-bold text-sm">{person.name}, {person.age}</p>
                    {person.city && <p className="text-white/70 text-xs">{person.city}</p>}
                  </div>
                </div>
                <div className="p-3">
                  <p className="text-[11px] text-gray-400">
                    Sent {sent_at ? new Date(sent_at).toLocaleDateString() : ""}
                  </p>
                  <p className="text-xs font-medium mt-1 text-gray-600">
                    {status === "pending"  && "⏳ Awaiting response"}
                    {status === "accepted" && "🎉 They liked you back"}
                    {status === "rejected" && "❌ They passed"}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        // Disliked by me tab
        disliked.length === 0 ? (
          <EmptyState
            icon={<X size={36} className="text-rose-300" />}
            title="You haven't passed on anyone"
            subtitle="Profiles you skip from Discover will appear here so you can reconsider."
          />
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
            {disliked.map(({ profile: person, passed_at }) => (
              <div key={person.id} className="bg-white rounded-2xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-md transition">
                <div
                  className="relative aspect-[3/4] bg-pink-50 cursor-pointer"
                  onClick={() => openProfile(person.id, "disliked")}
                >
                  <img src={avatar(person)} alt={person.name} className="w-full h-full object-cover" />
                  <span className="absolute top-2 right-2 bg-rose-500 text-white text-[10px] font-bold px-2 py-1 rounded-full shadow">
                    You passed
                  </span>
                  <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/70 to-transparent p-3">
                    <p className="text-white font-bold text-sm">{person.name}, {person.age}</p>
                    {person.city && <p className="text-white/70 text-xs">{person.city}</p>}
                  </div>
                </div>
                <div className="p-3 space-y-2">
                  <p className="text-[11px] text-gray-400">
                    Passed {passed_at ? new Date(passed_at).toLocaleDateString() : ""}
                  </p>
                  <button
                    onClick={(e) => { e.stopPropagation(); sendRequest(person); }}
                    className="w-full py-2 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white text-xs font-semibold hover:opacity-90 transition flex items-center justify-center gap-1"
                    title="Send a request after all"
                  >
                    <Heart size={14} className="fill-white" /> Send Request
                  </button>
                </div>
              </div>
            ))}
          </div>
        )
      )}

      {openProfileId && (() => {
        // Accepted-in-sent means we're already matched with this person — the
        // modal should offer "Remove friend" instead of like/pass.
        const sentEntry = openContext === "sent"
          ? sent.find(s => s.profile.id === openProfileId)
          : null;
        const isAccepted = sentEntry?.status === "accepted";

        return (
          <ProfileDetailModal
            userId={openProfileId}
            showToast={showToast}
            onClose={() => setOpenProfileId(null)}
            {...(isAccepted
              ? {
                  onUnmatch: async (partnerId, partnerProfile) => {
                    try {
                      await api.matches.unmatch(partnerId);
                      setSent(prev => prev.filter(s => s.profile.id !== partnerId));
                      showToast(`Removed ${partnerProfile?.name || "friend"}`);
                    } catch (e) {
                      showToast(e.message || "Could not remove friend", "error");
                    }
                  },
                }
              : {
                  onLike: async (id) => {
                    if (openContext === "received") {
                      await acceptLike(id);
                    } else if (openContext === "disliked") {
                      await sendRequest(id);
                    } else {
                      showToast("You've already liked this person");
                    }
                  },
                  onPass: async (id) => {
                    if (openContext === "received") {
                      await rejectLike(id);
                    }
                    // For sent / disliked: X just closes, no server action
                  },
                })}
          />
        );
      })()}
    </div>
  );
}

function StatusBadge({ status }) {
  const map = {
    pending:  { cls: "bg-amber-500",    label: "Pending"  },
    accepted: { cls: "bg-emerald-500",  label: "Accepted" },
    rejected: { cls: "bg-rose-500",     label: "Rejected" },
  };
  const s = map[status] || map.pending;
  return (
    <span className={`absolute top-2 right-2 ${s.cls} text-white text-[10px] font-bold px-2 py-1 rounded-full shadow`}>
      {s.label}
    </span>
  );
}

function EmptyState({ icon, title, subtitle }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center px-6">
      <div className="w-20 h-20 rounded-full bg-pink-50 flex items-center justify-center mb-4">
        {icon}
      </div>
      <h3 className="text-xl font-bold text-gray-800 mb-2">{title}</h3>
      <p className="text-gray-400 text-sm max-w-xs">{subtitle}</p>
    </div>
  );
}

// ─── Profile View ─────────────────────────────────────────────────────────────
// Kept in sync with the backend enum (app/profile/schemas.py → EducationLevel)
// and the filter dropdown at the top of Discover.
const EDIT_EDUCATION = [
  "less_than_high_school", "high_school", "some_college", "associates",
  "diploma", "trade_school", "bachelors", "postgraduate_diploma",
  "masters", "professional", "phd", "postdoc", "other",
];
const EDIT_GOALS = ["long_term", "short_term", "marriage", "friendship", "casual", "unsure"];
const EDIT_STATUS = ["single", "divorced", "widowed", "separated"];

// Lifestyle option sets — kept in sync with the backend enums in
// app/profile/schemas.py and the signup constants. Each entry has a display
// emoji so the non-editing view and the edit chips share the same labels.
const LIFESTYLE_OPTS = {
  drinking: [
    { value: "never", label: "Never", emoji: "🚫" },
    { value: "rarely", label: "Rarely", emoji: "🙂" },
    { value: "socially", label: "Socially", emoji: "🥂" },
    { value: "often", label: "Often", emoji: "🍸" },
    { value: "prefer_not_to_say", label: "Prefer not to say", emoji: "🤐" },
  ],
  smoking: [
    { value: "never", label: "Never", emoji: "🚭" },
    { value: "socially", label: "Socially", emoji: "💨" },
    { value: "regularly", label: "Regularly", emoji: "🚬" },
    { value: "trying_to_quit", label: "Trying to quit", emoji: "🤞" },
    { value: "prefer_not_to_say", label: "Prefer not to say", emoji: "🤐" },
  ],
  workout: [
    { value: "never", label: "Never", emoji: "😌" },
    { value: "sometimes", label: "Sometimes", emoji: "🚶" },
    { value: "regularly", label: "Regularly", emoji: "💪" },
    { value: "daily", label: "Daily", emoji: "🏋️" },
  ],
  pets: [
    { value: "dog", label: "Dog", emoji: "🐶" },
    { value: "cat", label: "Cat", emoji: "🐱" },
    { value: "both", label: "Both", emoji: "🐾" },
    { value: "other", label: "Other", emoji: "🦜" },
    { value: "none", label: "No pets", emoji: "🙅" },
    { value: "want_one", label: "Want one", emoji: "💖" },
  ],
  children: [
    { value: "have_and_want_more", label: "Have & want more" },
    { value: "have_and_dont_want_more", label: "Have & don't want more" },
    { value: "want", label: "Want kids" },
    { value: "dont_want", label: "Don't want kids" },
    { value: "unsure", label: "Not sure" },
  ],
  diet: [
    { value: "vegetarian", label: "Vegetarian" },
    { value: "vegan", label: "Vegan" },
    { value: "non_vegetarian", label: "Non-vegetarian" },
    { value: "eggetarian", label: "Eggetarian" },
    { value: "jain", label: "Jain" },
    { value: "other", label: "Other" },
  ],
};

function lifestyleLabel(kind, value) {
  if (!value) return null;
  const o = (LIFESTYLE_OPTS[kind] || []).find((x) => x.value === value);
  if (!o) return value.replace(/_/g, " ");
  return o.emoji ? `${o.emoji} ${o.label}` : o.label;
}

function ProfileView({ profile, onRefresh, showToast, conversations = [], setView, userId }) {
  const emptyForm = {
    name: "", age: "", date_of_birth: "",
    city: "", country: "", occupation: "", bio: "",
    education_level: "", relationship_goal: "", relationship_status: "",
    hobbies: "", vibes: "",
    // Tinder-style lifestyle
    drinking: "", smoking: "", workout: "",
    pets: "", children: "", diet: "",
    religion: "", languages: "", height_cm: "",
    first_date_idea: "",
  };
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [images, setImages] = useState(profile?.images || []);
  const [form, setForm] = useState(emptyForm);
  const fileRef = useRef();
  const [uploading, setUploading] = useState(false);
  const [showVerifyModal, setShowVerifyModal] = useState(false);

  useEffect(() => {
    setImages(profile?.images || []);
  }, [profile]);

  function startEdit() {
    setForm({
      name: profile?.name || "",
      age: profile?.age || "",
      date_of_birth: profile?.date_of_birth || "",
      city: profile?.city || "",
      country: profile?.country || "",
      occupation: profile?.occupation || "",
      bio: profile?.bio || "",
      education_level: profile?.education_level || "",
      relationship_goal: profile?.relationship_goal || "",
      relationship_status: profile?.relationship_status || "",
      hobbies: (profile?.hobbies || []).join(", "),
      vibes: (profile?.vibes || []).join(", "),
      drinking: profile?.drinking || "",
      smoking: profile?.smoking || "",
      workout: profile?.workout || "",
      pets: profile?.pets || "",
      children: profile?.children || "",
      diet: profile?.diet || "",
      religion: profile?.religion || "",
      languages: (profile?.languages || []).join(", "),
      height_cm: profile?.height_cm || "",
      first_date_idea: profile?.first_date_idea || "",
    });
    setEditing(true);
  }

  if (!profile) return (
    <div className="flex items-center justify-center h-full">
      <p className="text-gray-400 text-sm">Profile not loaded</p>
    </div>
  );

  async function handleSave() {
    setSaving(true);
    try {
      // When DOB is edited, let the backend re-derive age + zodiac — send age
      // only as a fallback so ProfileUpdateRequest still has a valid int if
      // the user typed into the age field directly.
      const payload = {
        name: form.name.trim() || undefined,
        age: form.age ? parseInt(form.age) : undefined,
        date_of_birth: form.date_of_birth || undefined,
        city: form.city.trim() || undefined,
        country: form.country.trim() || undefined,
        occupation: form.occupation.trim() || undefined,
        bio: form.bio.trim() || undefined,
        education_level: form.education_level || undefined,
        relationship_goal: form.relationship_goal || undefined,
        relationship_status: form.relationship_status || undefined,
        hobbies: form.hobbies.split(",").map(s => s.trim()).filter(Boolean),
        vibes: form.vibes.split(",").map(s => s.trim()).filter(Boolean),
        drinking: form.drinking || undefined,
        smoking: form.smoking || undefined,
        workout: form.workout || undefined,
        pets: form.pets || undefined,
        children: form.children || undefined,
        diet: form.diet || undefined,
        religion: form.religion.trim() || undefined,
        languages: form.languages.split(",").map(s => s.trim()).filter(Boolean),
        height_cm: form.height_cm ? parseInt(form.height_cm) : undefined,
        first_date_idea: form.first_date_idea.trim() || undefined,
      };
      await api.profile.update(payload);
      await onRefresh?.();
      setEditing(false);
      showToast?.("Profile updated");
    } catch (e) {
      showToast?.(e.message || "Update failed", "error");
    } finally {
      setSaving(false);
    }
  }

  async function handleUpload(files) {
    if (!files?.length) return;
    setUploading(true);
    try {
      for (const file of Array.from(files)) {
        await api.images.upload(file, false);
      }
      await onRefresh?.();
      showToast?.("Photo uploaded");
    } catch (e) {
      showToast?.(e.message || "Upload failed", "error");
    } finally {
      setUploading(false);
    }
  }

  async function handleSetMain(imageId) {
    try {
      await api.images.setMain(imageId);
      await onRefresh?.();
      showToast?.("Main photo updated");
    } catch (e) {
      showToast?.(e.message || "Failed to set main", "error");
    }
  }

  async function handleDeleteImage(imageId) {
    if (!confirm("Delete this photo?")) return;
    try {
      await api.images.delete(imageId);
      await onRefresh?.();
      showToast?.("Photo deleted");
    } catch (e) {
      showToast?.(e.message || "Delete failed", "error");
    }
  }

  // Combine vibes + hobbies into a single "interests" chip row shown in the
  // hero card, matching the reference layout where interests live right next
  // to the bio. Edit mode keeps them as separate comma-input fields so the
  // existing ProfileUpdateRequest payload is unchanged.
  const heroChips = [
    ...(profile.vibes || []),
    ...(profile.hobbies || []),
  ];

  // Read-only About rows. Two flat arrays keeps the two-column grid balanced
  // no matter which fields the user has filled in — empty ones fall through
  // to "Not set" via the shared <AboutRow> component.
  const aboutLeft = [
    ["Live in", [profile.city, profile.country].filter(Boolean).join(", ")],
    ["Work as", profile.occupation],
    ["Education", prettify(profile.education_level)],
    ["Languages", (profile.languages || []).join(", ")],
    ["Religion", profile.religion],
    ["Height", profile.height_cm ? `${profile.height_cm} cm` : ""],
    ["Zodiac", profile.zodiac_sign],
  ];
  const aboutRight = [
    ["Looking for", prettify(profile.relationship_goal)],
    ["Relationship", prettify(profile.relationship_status)],
    ["Family plans", prettify(profile.children)],
    ["Drink", prettify(profile.drinking)],
    ["Smoke", prettify(profile.smoking)],
    ["Workout", prettify(profile.workout)],
    ["Diet", prettify(profile.diet)],
    ["Pets", prettify(profile.pets)],
  ];

  return (
    <div className="min-h-full bg-gradient-to-br from-rose-50 via-pink-50/60 to-rose-50 p-3 sm:p-5 md:p-8">
      <div className="max-w-7xl mx-auto space-y-4 md:space-y-5">
        {/* Verification banner — three flavours depending on status:
            - 'none'     : amber, "verify now"
            - 'pending'  : blue, "waiting for admin review" (no CTA)
            - 'rejected' : red, shows admin's reject note + reupload CTA
            'approved'   : no banner rendered. */}
        {(() => {
          const s = (profile.verification_status || (profile.is_verified ? "approved" : "none")).toLowerCase();
          if (s === "approved") return null;
          if (s === "pending") {
            return (
              <div className="flex flex-col sm:flex-row sm:items-center gap-3 p-4 bg-white/80 backdrop-blur border border-blue-200 rounded-3xl shadow-sm">
                <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0">
                  <Clock size={18} className="text-blue-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 text-sm">Verification pending</p>
                  <p className="text-xs text-gray-600 mt-0.5">
                    Your selfie is with the admin team. You're partially verified and have full access in the meantime.
                  </p>
                </div>
              </div>
            );
          }
          if (s === "rejected") {
            return (
              <div className="flex flex-col sm:flex-row sm:items-center gap-3 p-4 bg-white/80 backdrop-blur border border-red-200 rounded-3xl shadow-sm">
                <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                  <AlertCircle size={18} className="text-red-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 text-sm">Verification rejected</p>
                  <p className="text-xs text-gray-600 mt-0.5">
                    {profile.verification_note || "Your selfie didn't match your profile photo. Please re-upload a clear selfie."}
                  </p>
                </div>
                <button
                  onClick={() => setShowVerifyModal(true)}
                  className="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-red-500 text-white font-semibold text-sm hover:bg-red-600 transition shadow-md"
                >
                  <Camera size={15} /> Re-upload
                </button>
              </div>
            );
          }
          // s === 'none' — the user skipped during signup
          return (
            <div className="flex flex-col sm:flex-row sm:items-center gap-3 p-4 bg-white/80 backdrop-blur border border-amber-200 rounded-3xl shadow-sm">
              <div className="w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center flex-shrink-0">
                <Camera size={18} className="text-amber-600" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-gray-900 text-sm">Verify your face to get matches</p>
                <p className="text-xs text-gray-600 mt-0.5">
                  Only verified profiles appear in Discover and can send requests. Takes 10 seconds.
                </p>
              </div>
              <button
                onClick={() => setShowVerifyModal(true)}
                className="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold text-sm hover:from-pink-600 hover:to-pink-700 transition shadow-md shadow-pink-100"
              >
                <Camera size={15} /> Verify now
              </button>
            </div>
          );
        })()}

        {showVerifyModal && (
          <VerifyFaceModal
            onClose={() => setShowVerifyModal(false)}
            onDone={async () => {
              setShowVerifyModal(false);
              await onRefresh?.();
              showToast?.("Face verified — you're live on Discover ✨");
            }}
            showToast={showToast}
          />
        )}

        {/* Two-column layout: main profile content on the left, a messages
            summary + online contacts rail on the right at lg+. On smaller
            screens the rail collapses below the main column. */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-5 items-start">
          <div className="lg:col-span-2 space-y-4 md:space-y-5 min-w-0">
        {/* ── HERO CARD ─────────────────────────────────────────────
            Portrait photo on the left, identity + bio + interest chips
            on the right. Edit toggles the info pane into a form. */}
        <section className="relative bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5 overflow-hidden">
          <div className="absolute top-3 right-3 md:top-4 md:right-4 flex items-center gap-2 z-10">
            {editing ? (
              <>
                <button
                  onClick={() => setEditing(false)}
                  disabled={saving}
                  className="px-3 py-1.5 rounded-full border border-gray-200 text-gray-600 text-xs font-semibold hover:bg-gray-50 transition disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-gradient-to-r from-pink-500 to-rose-500 text-white text-xs font-semibold hover:from-pink-600 hover:to-rose-600 transition shadow-sm disabled:opacity-50"
                >
                  <Save size={13} /> {saving ? "Saving…" : "Save"}
                </button>
              </>
            ) : (
              <button
                onClick={startEdit}
                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-white border border-rose-200 text-rose-600 text-xs font-semibold hover:bg-rose-50 transition shadow-sm"
              >
                <Edit2 size={13} /> Edit
              </button>
            )}
          </div>

          <div className="flex flex-col sm:flex-row gap-4 md:gap-5">
            {/* Portrait photo — tall aspect like the reference. Clicking opens
                the hidden file picker to change the main photo. */}
            <div className="flex-shrink-0 relative">
              <img
                src={avatar(profile)}
                alt={profile.name}
                className="w-full sm:w-48 md:w-52 aspect-[3/4] sm:aspect-[4/5] rounded-2xl object-cover bg-rose-100"
              />
              {editing && (
                <button
                  onClick={() => fileRef.current?.click()}
                  className="absolute bottom-2 right-2 bg-white/95 text-gray-700 rounded-full p-1.5 shadow-md hover:bg-white transition"
                  title="Upload photo"
                >
                  <Camera size={14} />
                </button>
              )}
            </div>

            {/* Identity + bio + chips */}
            <div className="flex-1 min-w-0 pt-1 pr-20">
              {editing ? (
                <div className="space-y-2.5">
                  <div className="grid grid-cols-3 gap-2">
                    <input
                      value={form.name}
                      onChange={(e) => setForm(f => ({ ...f, name: e.target.value }))}
                      placeholder="Name"
                      className="col-span-2 border border-gray-200 rounded-lg px-3 py-2 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-pink-500"
                    />
                    <input
                      type="number"
                      value={form.age}
                      onChange={(e) => setForm(f => ({ ...f, age: e.target.value }))}
                      placeholder="Age"
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
                    />
                  </div>
                  <textarea
                    value={form.bio}
                    onChange={(e) => setForm(f => ({ ...f, bio: e.target.value }))}
                    rows={3}
                    maxLength={300}
                    placeholder="Tell people a bit about yourself…"
                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500 resize-none"
                  />
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <input
                      value={form.vibes}
                      onChange={(e) => setForm(f => ({ ...f, vibes: e.target.value }))}
                      placeholder="Vibes: adventurous, romantic…"
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
                    />
                    <input
                      value={form.hobbies}
                      onChange={(e) => setForm(f => ({ ...f, hobbies: e.target.value }))}
                      placeholder="Hobbies: travel, music…"
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
                    />
                  </div>
                </div>
              ) : (
                <>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h2 className="text-xl sm:text-2xl md:text-3xl font-bold text-gray-900 tracking-tight">
                      {profile.name}{profile.age ? `, ${profile.age}` : ""}
                    </h2>
                    {profile.is_verified && (
                      <span
                        title="Face verified"
                        className="inline-flex items-center justify-center w-5 h-5 rounded-full bg-emerald-500 text-white shadow-sm"
                      >
                        <Check size={13} strokeWidth={3} />
                      </span>
                    )}
                  </div>
                  {(profile.city || profile.country) && (
                    <p className="mt-1 flex items-center gap-1 text-xs text-gray-500">
                      <MapPin size={12} /> {[profile.city, profile.country].filter(Boolean).join(", ")}
                    </p>
                  )}
                  <p className="mt-3 text-sm text-gray-700 leading-relaxed whitespace-pre-wrap">
                    {profile.bio || <span className="text-gray-400 italic">No bio yet — click "Edit" to add one.</span>}
                  </p>
                  {heroChips.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {heroChips.map((c, i) => (
                        <span
                          key={`${c}-${i}`}
                          className="text-[11px] font-medium px-2.5 py-1 rounded-full bg-rose-50 text-rose-700 border border-rose-100"
                        >
                          {c}
                        </span>
                      ))}
                    </div>
                  )}
                  {profile.first_date_idea && (
                    <p className="mt-3 text-xs text-gray-500 italic leading-relaxed">
                      <span className="font-semibold not-italic text-gray-600">Ideal first date: </span>
                      "{profile.first_date_idea}"
                    </p>
                  )}
                </>
              )}
            </div>
          </div>
        </section>

        {/* ── PHOTOS CARD ─────────────────────────────────────────── */}
        <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-bold text-gray-900 text-sm">Photos</h3>
            <div className="flex items-center gap-2">
              <button
                onClick={() => fileRef.current?.click()}
                disabled={uploading || images.length >= 6}
                title="Add photo"
                className="text-rose-500 hover:text-rose-600 disabled:opacity-40 text-xs font-semibold inline-flex items-center gap-1"
              >
                <Plus size={14} /> {uploading ? "Uploading…" : "Add"}
              </button>
            </div>
            <input
              ref={fileRef} type="file" accept="image/*" multiple className="hidden"
              onChange={(e) => { handleUpload(e.target.files); e.target.value = ""; }}
            />
          </div>
          {images.length === 0 ? (
            <button
              onClick={() => fileRef.current?.click()}
              className="w-full py-10 border-2 border-dashed border-rose-200 rounded-2xl flex flex-col items-center gap-2 text-gray-400 hover:border-rose-400 hover:text-rose-500 transition"
            >
              <Upload size={22} /> <span className="text-sm font-medium">Upload your first photo</span>
            </button>
          ) : (
            // Horizontal scroll matches the reference carousel. `snap-start`
            // keeps thumbnails aligned nicely as the user scrolls on touch.
            <div className="flex gap-2.5 overflow-x-auto snap-x snap-mandatory pb-1 -mx-1 px-1">
              {images.map((img) => {
                const url = img.image_url || img.url;
                const isMain = img.is_main || url === profile.main_image_url;
                return (
                  <div
                    key={img.id}
                    className="relative flex-shrink-0 snap-start w-32 h-24 sm:w-40 sm:h-28 md:w-44 md:h-32 rounded-xl overflow-hidden border border-gray-200 group bg-gray-100"
                  >
                    <img src={url} alt="" className="w-full h-full object-cover" />
                    {isMain && (
                      <div className="absolute top-1.5 left-1.5 bg-rose-500 text-white text-[9px] font-bold px-1.5 py-0.5 rounded shadow">MAIN</div>
                    )}
                    <div className="absolute inset-0 bg-black/55 opacity-0 group-hover:opacity-100 flex items-center justify-center gap-1.5 transition">
                      {!isMain && (
                        <button onClick={() => handleSetMain(img.id)} title="Set as main"
                          className="bg-white text-gray-800 rounded-full p-1.5 hover:bg-rose-500 hover:text-white transition">
                          <Star size={13} />
                        </button>
                      )}
                      <button onClick={() => handleDeleteImage(img.id)} title="Delete"
                        className="bg-white text-gray-800 rounded-full p-1.5 hover:bg-red-500 hover:text-white transition">
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* ── ABOUT CARD ──────────────────────────────────────────── */}
        <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5">
          <h3 className="font-bold text-gray-900 text-sm mb-4">About</h3>
          {editing ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3">
              <EditField label="City" value={form.city} onChange={(v) => setForm(f => ({ ...f, city: v }))} />
              <EditField label="Country" value={form.country} onChange={(v) => setForm(f => ({ ...f, country: v }))} />
              <EditField label="Date of birth" type="date" value={form.date_of_birth} onChange={(v) => setForm(f => ({ ...f, date_of_birth: v }))} />
              <EditField label="Occupation" value={form.occupation} onChange={(v) => setForm(f => ({ ...f, occupation: v }))} />
              <EditSelect label="Education" value={form.education_level} options={EDIT_EDUCATION} onChange={(v) => setForm(f => ({ ...f, education_level: v }))} />
              <EditField label="Languages (comma-separated)" value={form.languages} onChange={(v) => setForm(f => ({ ...f, languages: v }))} />
              <EditReligion value={form.religion} onChange={(v) => setForm(f => ({ ...f, religion: v }))} />
              <EditField label="Height (cm)" type="number" value={form.height_cm} onChange={(v) => setForm(f => ({ ...f, height_cm: v }))} />
              <EditSelect label="Looking for" value={form.relationship_goal} options={EDIT_GOALS} onChange={(v) => setForm(f => ({ ...f, relationship_goal: v }))} />
              <EditSelect label="Relationship" value={form.relationship_status} options={EDIT_STATUS} onChange={(v) => setForm(f => ({ ...f, relationship_status: v }))} />
              <EditSelect label="Family plans" value={form.children} options={LIFESTYLE_OPTS.children.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, children: v }))} />
              <EditSelect label="Drink" value={form.drinking} options={LIFESTYLE_OPTS.drinking.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, drinking: v }))} />
              <EditSelect label="Smoke" value={form.smoking} options={LIFESTYLE_OPTS.smoking.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, smoking: v }))} />
              <EditSelect label="Workout" value={form.workout} options={LIFESTYLE_OPTS.workout.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, workout: v }))} />
              <EditSelect label="Diet" value={form.diet} options={LIFESTYLE_OPTS.diet.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, diet: v }))} />
              <EditSelect label="Pets" value={form.pets} options={LIFESTYLE_OPTS.pets.map(o => ({ value: o.value, label: o.label }))} onChange={(v) => setForm(f => ({ ...f, pets: v }))} />
              <div className="md:col-span-2">
                <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Ideal first date</label>
                <textarea
                  value={form.first_date_idea}
                  onChange={(e) => setForm(f => ({ ...f, first_date_idea: e.target.value }))}
                  rows={2}
                  maxLength={200}
                  placeholder="Coffee and a long walk? A concert? Cooking together?"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500 resize-none"
                />
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-x-10 gap-y-2.5 text-sm">
              <div className="space-y-2.5">
                {aboutLeft.map(([label, value]) => (
                  <AboutRow key={label} label={label} value={value} />
                ))}
              </div>
              <div className="space-y-2.5">
                {aboutRight.map(([label, value]) => (
                  <AboutRow key={label} label={label} value={value} />
                ))}
              </div>
            </div>
          )}
        </section>

        {/* ── COMPATIBILITY / CONNECTION STYLE CARD ───────────────── */}
        <CompatibilitySection
          profile={profile}
          onSaved={(updatedAnswers) => {
            onRefresh();
          }}
        />
          </div>

          {/* ── RIGHT RAIL: Messages summary + online contacts ──────
              Mirrors the reference layout — at lg+ it sits beside the main
              profile column; below that breakpoint it stacks underneath. */}
          <aside className="space-y-4 md:space-y-5 lg:sticky lg:top-4">
            <MessagesSummaryCard
              conversations={conversations}
              userId={userId}
              setView={setView}
            />
            <ContactsOnlineCard
              conversations={conversations}
              setView={setView}
            />
          </aside>
        </div>
      </div>
    </div>
  );
}

// Compact messages card shown on the profile page. Lists the most recent
// conversations with unread badges, and a secondary "Requests" tab that
// hands off to the Likes view where match requests actually live.
function MessagesSummaryCard({ conversations, userId, setView }) {
  const [tab, setTab] = useState("chats");
  const sorted = [...(conversations || [])].sort((a, b) => {
    const ta = a.last_message?.created_at || a.matched_at || 0;
    const tb = b.last_message?.created_at || b.matched_at || 0;
    return new Date(tb) - new Date(ta);
  });
  const preview = sorted.slice(0, 5);

  function openConvo(c) {
    setView?.("messages");
    // Defer so MessagesView has mounted and registered its listener
    setTimeout(() => {
      window.dispatchEvent(new CustomEvent("chat:openConversation", {
        detail: { match_id: c.match_id },
      }));
    }, 50);
  }

  return (
    <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="font-bold text-gray-900 text-sm">Messages</h3>
        <button
          onClick={() => setView?.("messages")}
          className="text-[11px] font-semibold text-rose-500 hover:text-rose-600 transition"
        >
          See all
        </button>
      </div>

      <div className="grid grid-cols-2 gap-1 p-1 bg-rose-50/70 rounded-xl mb-3">
        <button
          onClick={() => setTab("chats")}
          className={`text-xs font-semibold py-1.5 rounded-lg transition ${
            tab === "chats"
              ? "bg-white text-rose-600 shadow-sm"
              : "text-gray-500 hover:text-gray-700"
          }`}
        >
          Chats
        </button>
        <button
          onClick={() => { setTab("requests"); setView?.("likes"); }}
          className={`text-xs font-semibold py-1.5 rounded-lg transition ${
            tab === "requests"
              ? "bg-white text-rose-600 shadow-sm"
              : "text-gray-500 hover:text-gray-700"
          }`}
        >
          Requests
        </button>
      </div>

      {preview.length === 0 ? (
        <div className="py-8 text-center">
          <MessageCircle size={28} className="text-gray-200 mx-auto mb-2" />
          <p className="text-xs font-semibold text-gray-500">No conversations yet</p>
          <p className="text-[11px] text-gray-400 mt-0.5">
            Match with someone to start chatting
          </p>
        </div>
      ) : (
        <ul className="space-y-0.5 -mx-1">
          {preview.map((c) => {
            const last = c.last_message;
            const preview = c.removed_at
              ? "Removed as friend"
              : last
              ? last.sender_id === userId
                ? `You: ${last.content}`
                : last.content
              : "Matched! Say hello 👋";
            return (
              <li key={c.match_id}>
                <button
                  onClick={() => openConvo(c)}
                  className="w-full flex items-center gap-3 px-2 py-2 rounded-xl hover:bg-rose-50/60 transition text-left"
                >
                  <div className="relative flex-shrink-0">
                    <img
                      src={avatar(c.partner)}
                      alt={c.partner?.name}
                      className={`w-9 h-9 rounded-full object-cover ${c.removed_at ? "grayscale" : ""}`}
                    />
                    {!c.removed_at && (
                      <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-emerald-400 rounded-full border-2 border-white" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-[13px] font-semibold text-gray-800 truncate">
                        {c.partner?.name}
                      </p>
                      <span className="text-[10px] text-gray-400 flex-shrink-0">
                        {last ? timeAgo(last.created_at) : timeAgo(c.matched_at)}
                      </span>
                    </div>
                    <div className="flex items-center justify-between gap-2 mt-0.5">
                      <p className="text-[11px] text-gray-500 truncate">
                        {preview}
                      </p>
                      {c.unread_count > 0 && (
                        <span className="flex-shrink-0 bg-rose-500 text-white text-[10px] font-bold w-4 h-4 rounded-full flex items-center justify-center">
                          {c.unread_count > 9 ? "9+" : c.unread_count}
                        </span>
                      )}
                    </div>
                  </div>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

// Grid of matched partners rendered as avatar chips with a live dot, matching
// the "My contacts online" card in the reference layout. Tapping a contact
// jumps to the corresponding conversation in Messages.
function ContactsOnlineCard({ conversations, setView }) {
  const contacts = (conversations || [])
    .filter((c) => !c.removed_at && c.partner)
    .slice(0, 10);

  function openConvo(c) {
    setView?.("messages");
    setTimeout(() => {
      window.dispatchEvent(new CustomEvent("chat:openConversation", {
        detail: { match_id: c.match_id },
      }));
    }, 50);
  }

  return (
    <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-4 md:p-5">
      <h3 className="font-bold text-gray-900 text-sm mb-3">My contacts online</h3>
      {contacts.length === 0 ? (
        <div className="py-6 text-center">
          <Heart size={24} className="text-gray-200 mx-auto mb-2" />
          <p className="text-xs font-semibold text-gray-500">No contacts yet</p>
          <p className="text-[11px] text-gray-400 mt-0.5">
            Your matches will show up here
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-4 sm:grid-cols-5 gap-3">
          {contacts.map((c) => {
            const firstName = (c.partner?.name || "").split(" ")[0] || "—";
            return (
              <button
                key={c.match_id}
                onClick={() => openConvo(c)}
                className="flex flex-col items-center gap-1.5 group"
                title={c.partner?.name}
              >
                <div className="relative">
                  <img
                    src={avatar(c.partner)}
                    alt={c.partner?.name}
                    className="w-11 h-11 rounded-full object-cover border-2 border-white shadow-sm group-hover:ring-2 group-hover:ring-rose-300 transition"
                  />
                  <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-emerald-400 rounded-full border-2 border-white" />
                </div>
                <span className="text-[11px] font-medium text-gray-700 truncate max-w-full">
                  {firstName}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
}

// Single about row — a right-aligned value with a soft label column, mirroring
// the "Live in: …" / "Relationship: …" pairs in the reference layout. Falls
// through to a muted "Not set" when the value is empty so the grid stays even.
function AboutRow({ label, value }) {
  return (
    <div className="flex items-baseline gap-3">
      <span className="text-gray-400 font-medium w-28 flex-shrink-0">{label}:</span>
      <span className="text-gray-800 font-medium truncate">
        {value ? value : <span className="text-gray-300 italic font-normal">Not set</span>}
      </span>
    </div>
  );
}

// Reusable section heading: a small gradient icon badge + bold title. Keeps
// every ProfileView section visually consistent without repeating the exact
// Tailwind chain on every <h3>. Pass `className="mb-0"` to override the
// default bottom margin when the section manages its own spacing.
function SectionHeader({ icon, title, gradient = "from-pink-500 to-rose-500", className = "mb-4" }) {
  return (
    <div className={`flex items-center gap-2.5 ${className}`}>
      <span
        className={`w-7 h-7 rounded-lg bg-gradient-to-br ${gradient} text-white flex items-center justify-center shadow-sm`}
      >
        {icon}
      </span>
      <h3 className="font-bold text-gray-900 tracking-tight">{title}</h3>
    </div>
  );
}

// Religion edit control: mirrors the Signup dropdown behaviour so users can
// pick from the curated list OR type a custom value. Off-list strings map to
// "Other" in the select, and a text fallback lets them refine the exact term.
function EditReligion({ value, onChange }) {
  const inList = !value || RELIGION_OPTIONS.includes(value);
  const selectValue = inList ? (value || "") : "Other";
  return (
    <div>
      <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Religion</label>
      <select
        value={selectValue}
        onChange={(e) => {
          const v = e.target.value;
          onChange(v === "Other" ? (inList ? "" : value) : v);
        }}
        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500 bg-white"
      >
        <option value="">—</option>
        {RELIGION_OPTIONS.map((r) => (
          <option key={r} value={r}>{r}</option>
        ))}
      </select>
      {selectValue === "Other" && (
        <input
          value={inList ? "" : value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Specify"
          className="mt-2 w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
        />
      )}
    </div>
  );
}

function EditField({ label, value, onChange, type = "text" }) {
  return (
    <div>
      <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">{label}</label>
      <input type={type} value={value} onChange={(e) => onChange(e.target.value)}
        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500" />
    </div>
  );
}

// A plain labeled <select>. Accepts either an array of raw enum values or an
// array of { value, label } option objects. Labels are prettified (first-letter
// capitalised, underscores stripped) so the dropdown reads naturally.
function EditSelect({ label, value, options, onChange, placeholder = "—" }) {
  return (
    <div>
      <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">{label}</label>
      <select
        value={value || ""}
        onChange={(e) => onChange(e.target.value)}
        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500 bg-white"
      >
        <option value="">{placeholder}</option>
        {options.map((o) => {
          const val = typeof o === "string" ? o : o.value;
          const lbl = typeof o === "string" ? prettify(o) : o.label;
          return <option key={val} value={val}>{lbl}</option>;
        })}
      </select>
    </div>
  );
}

function Detail({ label, value }) {
  return (
    <div className="flex items-start justify-between gap-3 py-2 border-b border-gray-50 last:border-0">
      <span className="text-gray-500 font-medium">{label}</span>
      <span className="text-gray-800 text-right font-medium">
        {value ? value : <span className="text-gray-300 italic font-normal">Not set</span>}
      </span>
    </div>
  );
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
// Responsive behavior:
//   - Mobile (< md): off-canvas drawer, toggled by the hamburger in the top bar.
//     Backdrop dismisses it; tapping a nav item also closes it.
//   - Desktop (md+): narrow 16-rem icon rail by default; expands to 60 rem on hover,
//     overlaying the content (no layout shift thanks to a fixed-width spacer).
function Sidebar({ profile, view, setView, unreadCount, onLogout, mobileOpen, closeMobile, showToast }) {
  // Subscription snapshot for the user card at the bottom of the nav.
  // We load it lazily once the sidebar mounts, refresh after a successful
  // upgrade, and also on a "subs:changed" window event so other screens
  // (e.g. Discover paywall) can notify us without prop drilling.
  const [sub, setSub] = useState(null);
  const [showPaywall, setShowPaywall] = useState(false);

  const loadSub = useCallback(() => {
    api.subscriptions.me().then(setSub).catch(() => {});
  }, []);
  useEffect(() => {
    loadSub();
    const onChanged = () => loadSub();
    window.addEventListener("subs:changed", onChanged);
    return () => window.removeEventListener("subs:changed", onChanged);
  }, [loadSub]);

  const nav = [
    { id: "discover",  Icon: Home,          label: "Discover"  },
    { id: "messages",  Icon: MessageCircle, label: "Messages",  badge: unreadCount },
    { id: "likes",     Icon: Heart,         label: "Likes"     },
    { id: "wallet",    Icon: Wallet,        label: "Wallet"    },
    { id: "profile",   Icon: User,          label: "My Profile" },
  ];

  const pick = (id) => { setView(id); closeMobile(); };

  // Tailwind utility that reveals a child when either the <aside> is hovered (desktop)
  // or the drawer is open (mobile). Using group-hover + a data attribute trick.
  // "revealed" = visible; "hidden-label" = collapsed.
  const labelCls =
    "whitespace-nowrap transition-opacity duration-200 " +
    "md:opacity-0 md:group-hover:opacity-100 " +
    "opacity-100";

  return (
    <>
      {/* Backdrop — mobile only */}
      {mobileOpen && (
        <div
          onClick={closeMobile}
          className="fixed inset-0 bg-black/40 backdrop-blur-sm z-30 md:hidden"
        />
      )}

      <aside
        className={[
          "group z-40 bg-white border-r border-gray-100 flex flex-col h-screen",
          // Mobile: off-canvas drawer (fixed). Desktop: in-flow column that pushes content when expanded.
          "fixed md:relative md:translate-x-0 md:flex-shrink-0 left-0 top-0",
          "transition-[width,transform] duration-200 ease-out overflow-hidden",
          "w-64 md:w-16 md:hover:w-60 md:shadow-none shadow-xl",
          mobileOpen ? "translate-x-0" : "-translate-x-full",
        ].join(" ")}
      >
        {/* Logo — badge always visible; wordmark hides when sidebar is collapsed */}
        <div className="flex items-center gap-2.5 px-4 py-5 border-b border-gray-100 flex-shrink-0">
          <BrandLogo variant="mark" size="md" />
          <span className={labelCls}>
            <BrandLogo variant="wordmark" size="md" tone="dark" />
          </span>
          {/* Close button on mobile */}
          <button
            onClick={closeMobile}
            className="ml-auto p-1.5 rounded-lg hover:bg-gray-100 md:hidden"
            aria-label="Close menu"
          >
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 py-4 px-3 space-y-0.5 overflow-hidden">
          {nav.map(({ id, Icon, label, badge }) => (
            <button
              key={id}
              onClick={() => pick(id)}
              title={label}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${
                view === id
                  ? "bg-pink-50 text-pink-600"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-800"
              }`}
            >
              <Icon size={18} className={`flex-shrink-0 ${view === id ? "text-pink-500" : "text-gray-400"}`} />
              <span className={labelCls}>{label}</span>
              {!!badge && (
                <span className={`ml-auto bg-pink-500 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 ${labelCls}`}>
                  {badge > 9 ? "9+" : badge}
                </span>
              )}
            </button>
          ))}

          <button
            onClick={onLogout}
            title="Log out"
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-red-50 hover:text-red-500 transition-all mt-2"
          >
            <LogOut size={18} className="text-gray-400 flex-shrink-0" />
            <span className={labelCls}>Log out</span>
          </button>
        </nav>

        {/* User card — only meaningful when the sidebar is expanded.
            Three variants based on subscription status:
              • Premium → gold badge + expiry date (no CTA)
              • Female  → warm "unlimited access" message (no CTA)
              • Free    → upgrade CTA that opens the paywall modal
        */}
        {profile && sub?.premium && sub?.tier === "pro" ? (
          // ── Pro subscriber ── gold badge + calls-included pitch
          <div
            className={`mx-3 mb-4 bg-gradient-to-br from-amber-50 via-orange-50 to-amber-100 rounded-2xl p-4 border border-amber-300 overflow-hidden ${labelCls}`}
          >
            <div className="flex items-center gap-2.5 mb-3">
              <div className="relative flex-shrink-0">
                <img
                  src={avatar(profile)}
                  alt={profile.name}
                  className="w-10 h-10 rounded-full object-cover border-2 border-white shadow"
                />
                <span className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 text-white text-[10px] flex items-center justify-center shadow ring-2 ring-white">
                  ⭐
                </span>
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-800 truncate">{profile.name}</p>
                <p className="text-[11px] font-bold text-amber-700 truncate">⭐ Pro Member</p>
              </div>
            </div>
            <div className="text-[11px] text-amber-800/80 bg-white/60 rounded-lg px-2.5 py-2 border border-amber-100">
              Unlimited swipes + voice & video calls
              {sub.expires_at && (
                <span className="block text-[10px] text-amber-700/70 mt-0.5">
                  Valid till {new Date(sub.expires_at).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })}
                </span>
              )}
            </div>
          </div>
        ) : profile && sub?.premium ? (
          // ── Plus subscriber ── rose badge + upsell to Pro for calls
          <div
            className={`mx-3 mb-4 bg-gradient-to-br from-rose-50 via-pink-50 to-amber-50 rounded-2xl p-4 border border-rose-200 overflow-hidden ${labelCls}`}
          >
            <div className="flex items-center gap-2.5 mb-3">
              <div className="relative flex-shrink-0">
                <img
                  src={avatar(profile)}
                  alt={profile.name}
                  className="w-10 h-10 rounded-full object-cover border-2 border-white shadow"
                />
                <span className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-gradient-to-br from-pink-400 to-rose-500 text-white flex items-center justify-center shadow ring-2 ring-white">
                  <Sparkles size={10} />
                </span>
              </div>
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-800 truncate">{profile.name}</p>
                <p className="text-[11px] font-bold text-rose-600 truncate">Plus Member</p>
              </div>
            </div>
            <div className="text-[11px] text-rose-800/80 bg-white/60 rounded-lg px-2.5 py-2 border border-rose-100 mb-2">
              Unlimited likes & passes
              {sub.expires_at && (
                <span className="block text-[10px] text-rose-700/70 mt-0.5">
                  Valid till {new Date(sub.expires_at).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })}
                </span>
              )}
            </div>
            <button
              onClick={() => setShowPaywall(true)}
              className="w-full py-1.5 rounded-lg bg-gradient-to-r from-amber-500 to-orange-600 text-white text-[11px] font-bold hover:from-amber-600 hover:to-orange-700 transition-all shadow-sm"
            >
              ⭐ Upgrade to Pro — unlock calls
            </button>
          </div>
        ) : profile && sub?.female ? (
          <div
            className={`mx-3 mb-4 bg-gradient-to-br from-rose-50 to-pink-50 rounded-2xl p-4 border border-rose-100 overflow-hidden ${labelCls}`}
          >
            <div className="flex items-center gap-2.5 mb-2.5">
              <img
                src={avatar(profile)}
                alt={profile.name}
                className="w-10 h-10 rounded-full object-cover border-2 border-white shadow flex-shrink-0"
              />
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-800 truncate">{profile.name}</p>
                <p className="text-xs text-rose-500 truncate font-semibold">Free unlimited access ❤</p>
              </div>
            </div>
            <div className="text-[11px] text-gray-500">
              Enjoy unlimited likes, passes, and calls on the house.
            </div>
          </div>
        ) : profile ? (
          <div
            className={`mx-3 mb-4 bg-gradient-to-br from-pink-50 to-purple-50 rounded-2xl p-4 border border-pink-100 overflow-hidden ${labelCls}`}
          >
            <div className="flex items-center gap-2.5 mb-3">
              <img
                src={avatar(profile)}
                alt={profile.name}
                className="w-10 h-10 rounded-full object-cover border-2 border-white shadow flex-shrink-0"
              />
              <div className="min-w-0">
                <p className="text-sm font-bold text-gray-800 truncate">{profile.name}</p>
                <p className="text-xs text-gray-400 truncate">{profile.city}</p>
              </div>
            </div>
            <div className="text-[11px] text-gray-500 mb-2.5">Unlimited swipes with Plus · Add calls with Pro</div>
            <button
              onClick={() => setShowPaywall(true)}
              className="w-full py-2 rounded-xl border-2 border-pink-400 text-pink-600 text-xs font-bold hover:bg-pink-500 hover:text-white transition-all whitespace-nowrap"
            >
              See plans
            </button>
          </div>
        ) : null}
      </aside>

      {showPaywall && (
        <SubscriptionModal
          trigger="upgrade"
          profile={profile}
          onClose={() => setShowPaywall(false)}
          onUpgraded={() => {
            setShowPaywall(false);
            showToast?.("You're Premium! Unlimited swipes ✨");
            // Reload this card AND broadcast so Discover (and anywhere else
            // watching) refreshes to reflect the new entitlement.
            loadSub();
            window.dispatchEvent(new CustomEvent("subs:changed"));
          }}
          showToast={showToast}
        />
      )}
    </>
  );
}

// ─── Notification Bell ────────────────────────────────────────────────────────
// Renders a bell with unread badge; clicking opens a dropdown with recent
// notifications. Invitations render inline Accept/Decline actions.
function NotificationBell({
  notifications,
  conversations,
  onAccept,
  onDecline,
  onLikeBack,
  onPass,
  onOpenChat,
  onMarkAllRead,
  onMarkRead,
}) {
  const [open, setOpen] = useState(false);
  const popRef = useRef(null);

  // Close on outside click / ESC
  useEffect(() => {
    if (!open) return;
    function onDoc(e) { if (popRef.current && !popRef.current.contains(e.target)) setOpen(false); }
    function onKey(e) { if (e.key === "Escape") setOpen(false); }
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const unreadMessages = conversations
    .filter(c => (c.unread_count || 0) > 0 && !c.removed_at)
    .reduce((n, c) => n + (c.unread_count || 0), 0);

  const unreadNotifs = notifications.filter(n => !n.is_read).length;
  const total = unreadMessages + unreadNotifs;

  // Build a unified feed: pending invitations first (actionable),
  // then unread message summaries, then recent non-message notifications.
  const pendingInvites = notifications.filter(
    n => n.type === "match_invitation" && !n.is_handled
  );
  const otherNotifs = notifications.filter(
    n => n.type !== "match_invitation" && (!n.is_handled || n.type !== "match_invitation")
  );
  const msgItems = conversations
    .filter(c => (c.unread_count || 0) > 0 && !c.removed_at && c.last_message)
    .slice(0, 5);

  function displayLine(n) {
    const who = n.actor?.name || "Someone";
    switch (n.type) {
      case "match_invitation":    return `${who} wants to reconnect`;
      case "match_restored":      return `${who} is your friend again 💕`;
      case "match_created":       return `You matched with ${who} 🎉`;
      case "like_received":       return `${who} liked you ❤️`;
      case "gift_like":           return `${who} super liked you 🎁`;
      case "invitation_declined": return `${who} declined your invite`;
      default: return n.type;
    }
  }

  function timeAgoMini(ts) {
    if (!ts) return "";
    const s = Math.max(0, Math.floor((Date.now() - new Date(ts).getTime()) / 1000));
    if (s < 60)   return `${s}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m`;
    if (s < 86400) return `${Math.floor(s / 3600)}h`;
    return `${Math.floor(s / 86400)}d`;
  }

  return (
    <div className="relative" ref={popRef}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="relative p-2 rounded-full hover:bg-gray-100 transition"
        aria-label="Notifications"
      >
        <Bell size={20} className="text-gray-600" />
        {total > 0 && (
          <span className="absolute top-1 right-1 min-w-[16px] h-4 px-1 rounded-full bg-pink-500 text-white text-[10px] font-bold flex items-center justify-center">
            {total > 9 ? "9+" : total}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-80 md:w-96 bg-white rounded-2xl shadow-xl border border-gray-100 overflow-hidden z-40">
          <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
            <div>
              <p className="font-bold text-gray-800 text-sm">Notifications</p>
              <p className="text-[11px] text-gray-400">{total > 0 ? `${total} new` : "You're all caught up"}</p>
            </div>
            {unreadNotifs > 0 && (
              <button
                type="button"
                onClick={onMarkAllRead}
                className="text-[11px] text-pink-600 font-semibold hover:text-pink-700"
              >
                Mark all read
              </button>
            )}
          </div>

          <div className="max-h-[60vh] overflow-y-auto divide-y divide-gray-50">
            {/* Pending invitations first */}
            {pendingInvites.map(n => (
              <div key={n.id} className="px-4 py-3 bg-pink-50/40">
                <div className="flex items-start gap-3">
                  <img
                    src={n.actor?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(n.actor?.name || "?")}&bg=ec4899&color=fff`}
                    alt=""
                    className="w-10 h-10 rounded-full object-cover flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-gray-800">
                      <span className="font-semibold">{n.actor?.name || "Someone"}</span>
                      <span className="text-gray-500"> wants to reconnect</span>
                    </p>
                    <p className="text-[11px] text-gray-400 mt-0.5">{timeAgoMini(n.created_at)} ago</p>
                    <div className="flex gap-2 mt-2">
                      <button
                        type="button"
                        onClick={() => onAccept(n)}
                        className="flex-1 py-1.5 rounded-lg bg-gradient-to-r from-pink-500 to-pink-600 text-white text-xs font-semibold hover:opacity-90 transition"
                      >
                        Accept
                      </button>
                      <button
                        type="button"
                        onClick={() => onDecline(n)}
                        className="flex-1 py-1.5 rounded-lg border border-gray-200 text-gray-600 text-xs font-semibold hover:bg-gray-50 transition"
                      >
                        Decline
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))}

            {/* Unread message summaries */}
            {msgItems.map(c => (
              <button
                key={`msg-${c.match_id}`}
                type="button"
                onClick={() => { onOpenChat(c); setOpen(false); }}
                className="w-full flex items-start gap-3 px-4 py-3 hover:bg-gray-50 transition text-left"
              >
                <img src={avatar(c.partner)} alt=""
                  className="w-10 h-10 rounded-full object-cover flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-gray-800 truncate">{c.partner?.name}</p>
                    <span className="text-[10px] text-gray-400 flex-shrink-0">{timeAgoMini(c.last_message?.created_at)}</span>
                  </div>
                  <p className="text-xs text-gray-500 truncate mt-0.5">{c.last_message?.content}</p>
                </div>
                <span className="bg-pink-500 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0">
                  {c.unread_count > 9 ? "9+" : c.unread_count}
                </span>
              </button>
            ))}

            {/* Other notifications (restores, likes, gift-likes, etc.) */}
            {otherNotifs.slice(0, 10).map(n => {
              const isGift   = n.type === "gift_like";
              const isLike   = n.type === "like_received" || isGift;
              const giftMsg  = isGift ? n.payload?.message : null;
              const handled  = n.is_handled;
              return (
                <div
                  key={n.id}
                  onClick={() => { if (!n.is_read) onMarkRead(n.id); }}
                  className={`flex items-start gap-3 px-4 py-3 transition cursor-default ${
                    isGift
                      ? n.is_read ? "bg-amber-50/60" : "bg-amber-50"
                      : n.is_read ? "hover:bg-gray-50" : "bg-pink-50/30 hover:bg-pink-50/60"
                  }`}
                >
                  <div className="relative flex-shrink-0">
                    <img
                      src={n.actor?.main_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(n.actor?.name || "?")}&bg=ec4899&color=fff`}
                      alt=""
                      className="w-9 h-9 rounded-full object-cover"
                    />
                    {isGift && (
                      <span className="absolute -bottom-1 -right-1 text-base leading-none">🎁</span>
                    )}
                    {!isGift && isLike && (
                      <span className="absolute -bottom-1 -right-1 text-sm leading-none">❤️</span>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm ${isGift ? "font-semibold text-amber-800" : "text-gray-700"}`}>
                      {displayLine(n)}
                    </p>
                    {giftMsg && (
                      <p className="text-xs text-amber-700/80 italic mt-0.5 truncate">"{giftMsg}"</p>
                    )}
                    <p className="text-[11px] text-gray-400 mt-0.5">{timeAgoMini(n.created_at)} ago</p>

                    {/* Accept / Decline for likes */}
                    {isLike && !handled && onLikeBack && (
                      <div className="flex gap-2 mt-2">
                        <button
                          type="button"
                          onClick={e => { e.stopPropagation(); onLikeBack(n); }}
                          className="flex-1 py-1.5 rounded-lg bg-gradient-to-r from-pink-500 to-rose-500 text-white text-xs font-semibold hover:opacity-90 transition"
                        >
                          ❤️ Like Back
                        </button>
                        <button
                          type="button"
                          onClick={e => { e.stopPropagation(); onPass(n); }}
                          className="flex-1 py-1.5 rounded-lg border border-gray-200 text-gray-500 text-xs font-semibold hover:bg-gray-50 transition"
                        >
                          Pass
                        </button>
                      </div>
                    )}
                    {isLike && handled && (
                      <p className="text-[11px] text-gray-400 mt-1 italic">Responded</p>
                    )}
                  </div>
                  {!n.is_read && !isLike && (
                    <span className={`w-2 h-2 rounded-full flex-shrink-0 mt-2 ${isGift ? "bg-amber-400" : "bg-pink-500"}`} />
                  )}
                </div>
              );
            })}

            {pendingInvites.length === 0 && msgItems.length === 0 && otherNotifs.length === 0 && (
              <div className="px-6 py-10 text-center">
                <Bell size={28} className="text-gray-200 mx-auto mb-2" />
                <p className="text-sm font-semibold text-gray-500">No notifications yet</p>
                <p className="text-xs text-gray-400 mt-1">We'll let you know when something happens</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Face Verification Modal ──────────────────────────────────────────────────
// Three-phase pop-up:
//   1. "intro"    — instructions: how to take the selfie + what gets rejected.
//   2. "live"     — camera feed with oval overlay + capture button.
//   3. "captured" — preview + retake / confirm.
//   4. "uploading"— spinner while /images/verification is called.
// `gated=true` means the user hit a 403 verify_required — the modal is less
// dismissible (no easy X) and the backdrop doesn't close it.
function VerifyFaceModal({ onClose, onDone, showToast, gated = false }) {
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const canvasRef = useRef(null);
  const [phase, setPhase] = useState("intro"); // intro | live | captured | uploading
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState("");

  // Start the camera only when we transition into the "live" phase — that way
  // the user isn't prompted for camera permissions until they actually want to
  // take the selfie (after reading the instructions).
  useEffect(() => {
    if (phase !== "live") return;
    let cancelled = false;
    (async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: "user", width: { ideal: 720 }, height: { ideal: 720 } },
          audio: false,
        });
        if (cancelled) { stream.getTracks().forEach(t => t.stop()); return; }
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          await videoRef.current.play().catch(() => {});
        }
      } catch {
        setError("Camera access denied. Please allow the camera and try again.");
      }
    })();
    return () => {
      cancelled = true;
      streamRef.current?.getTracks().forEach(t => t.stop());
      streamRef.current = null;
    };
  }, [phase]);

  // Safety: always stop any active stream when the modal unmounts.
  useEffect(() => () => {
    streamRef.current?.getTracks().forEach(t => t.stop());
    streamRef.current = null;
  }, []);

  function capture() {
    const video = videoRef.current;
    if (!video || video.readyState < 2) return;
    const canvas = canvasRef.current || document.createElement("canvas");
    const w = video.videoWidth || 640, h = video.videoHeight || 640;
    canvas.width = w; canvas.height = h;
    const ctx = canvas.getContext("2d");
    ctx.save(); ctx.translate(w, 0); ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0, w, h);
    ctx.restore();
    canvas.toBlob((blob) => {
      if (!blob) { setError("Capture failed. Please try again."); return; }
      setPreview({ blob, url: URL.createObjectURL(blob) });
      setPhase("captured");
      streamRef.current?.getTracks().forEach(t => t.stop());
      streamRef.current = null;
    }, "image/jpeg", 0.9);
  }

  async function confirm() {
    if (!preview?.blob) return;
    setPhase("uploading");
    setError("");
    try {
      const file = new File([preview.blob], "verification.jpg", { type: "image/jpeg" });
      await api.images.uploadVerification(file);
      onDone?.();
    } catch (e) {
      setError(e.message || "Verification failed");
      setPhase("captured");
    }
  }

  function retake() {
    if (preview?.url) URL.revokeObjectURL(preview.url);
    setPreview(null);
    setError("");
    // Transitioning back to "live" re-runs the useEffect and starts a fresh
    // camera stream — no manual getUserMedia call needed here.
    setPhase("live");
  }

  // On "gated" mode (hit the 403 wall), clicking the backdrop does nothing
  // and we don't render an X — only the explicit "Not now" button closes it.
  // On the soft banner path, both work.
  const closeIfAllowed = gated ? () => {} : onClose;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
      onClick={closeIfAllowed}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-white rounded-3xl overflow-hidden w-full max-w-md shadow-2xl max-h-[92vh] flex flex-col"
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 flex-shrink-0">
          <h3 className="font-bold text-gray-900">
            {phase === "intro" ? "Before you take a selfie" : "Verify your face"}
          </h3>
          {!gated && (
            <button
              onClick={onClose}
              className="w-8 h-8 rounded-full hover:bg-gray-100 flex items-center justify-center text-gray-500"
              aria-label="Close"
            >
              <X size={16} />
            </button>
          )}
        </div>

        <div className="p-6 space-y-4 overflow-y-auto">
          {error && (
            <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-xl text-red-600 text-xs">
              <span>⚠️</span> {error}
            </div>
          )}

          {/* ── Phase 1: Instructions ────────────────────────────── */}
          {phase === "intro" && (
            <>
              <div className="mx-auto w-16 h-16 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center shadow-lg">
                <Camera size={26} className="text-white" />
              </div>
              <p className="text-center text-sm text-gray-600 leading-relaxed">
                A quick selfie keeps MatchInMinutes real. Please follow these tips so
                your verification gets approved on the first try.
              </p>

              <div className="rounded-2xl border border-emerald-100 bg-emerald-50/50 p-4">
                <p className="text-xs font-bold text-emerald-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                  <Check size={13} /> Do this
                </p>
                <ul className="space-y-1.5 text-sm text-gray-700">
                  <li className="flex items-start gap-2">
                    <span className="text-emerald-500 mt-0.5">✓</span>
                    Face the camera straight-on, eyes looking at the lens
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-emerald-500 mt-0.5">✓</span>
                    Make sure your face fills the oval frame
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-emerald-500 mt-0.5">✓</span>
                    Use good, even lighting — daylight works best
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-emerald-500 mt-0.5">✓</span>
                    Keep a neutral expression, mouth closed
                  </li>
                </ul>
              </div>

              <div className="rounded-2xl border border-red-100 bg-red-50/50 p-4">
                <p className="text-xs font-bold text-red-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                  <X size={13} /> Will be rejected
                </p>
                <ul className="space-y-1.5 text-sm text-gray-700">
                  <li className="flex items-start gap-2">
                    <span className="text-red-500 mt-0.5">✗</span>
                    Sunglasses, masks, or anything covering your face
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-500 mt-0.5">✗</span>
                    Heavy filters, stickers, or edited photos
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-500 mt-0.5">✗</span>
                    Multiple faces or no face detected in the frame
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-500 mt-0.5">✗</span>
                    Very dark, blurry, or low-resolution captures
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-500 mt-0.5">✗</span>
                    Photos of photos (holding a phone, computer screen, etc.)
                  </li>
                </ul>
              </div>

              <p className="text-[11px] text-gray-400 text-center leading-relaxed">
                Your selfie is used only to confirm you're a real person. It's
                stored securely and never shown on your public profile.
              </p>

              <div className="grid grid-cols-2 gap-3 pt-1">
                <button
                  onClick={onClose}
                  className="py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm hover:bg-gray-50 transition"
                >
                  {gated ? "Not now" : "Cancel"}
                </button>
                <button
                  onClick={() => setPhase("live")}
                  className="py-2.5 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold text-sm hover:from-pink-600 hover:to-pink-700 shadow-md shadow-pink-100 transition flex items-center justify-center gap-2"
                >
                  <Camera size={15} /> I'm ready
                </button>
              </div>
            </>
          )}

          {/* ── Phase 2+: Camera / preview ───────────────────────── */}
          {phase !== "intro" && (
            <>
              <div className="relative mx-auto w-64 h-64 rounded-3xl overflow-hidden bg-gray-900">
                {phase === "captured" && preview ? (
                  <img src={preview.url} alt="Your selfie" className="w-full h-full object-cover" />
                ) : (
                  <video
                    ref={videoRef}
                    playsInline
                    muted
                    className="w-full h-full object-cover"
                    style={{ transform: "scaleX(-1)" }}
                  />
                )}
                {phase !== "captured" && (
                  <svg viewBox="0 0 100 100" className="absolute inset-0 w-full h-full pointer-events-none" preserveAspectRatio="none">
                    <defs>
                      <mask id="vmask">
                        <rect width="100" height="100" fill="white" />
                        <ellipse cx="50" cy="50" rx="32" ry="42" fill="black" />
                      </mask>
                    </defs>
                    <rect width="100" height="100" fill="rgba(0,0,0,0.45)" mask="url(#vmask)" />
                    <ellipse cx="50" cy="50" rx="32" ry="42" fill="none" stroke="white" strokeOpacity="0.85" strokeWidth="0.6" strokeDasharray="1.5 1.5" />
                  </svg>
                )}
              </div>
              <p className="text-center text-xs text-gray-500">
                {phase === "captured"
                  ? "Looks good? We'll save this to verify your identity."
                  : "Center your face inside the oval, then tap capture."}
              </p>

              {phase === "captured" ? (
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={retake}
                    disabled={phase === "uploading"}
                    className="py-2.5 rounded-xl border border-gray-200 text-gray-700 font-semibold text-sm hover:bg-gray-50 transition disabled:opacity-50"
                  >
                    Retake
                  </button>
                  <button
                    onClick={confirm}
                    disabled={phase === "uploading"}
                    className="py-2.5 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold text-sm hover:from-pink-600 hover:to-pink-700 transition disabled:opacity-50 flex items-center justify-center gap-2"
                  >
                    {phase === "uploading"
                      ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                      : <><Check size={15} /> Verify</>}
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  <button
                    onClick={capture}
                    className="w-full py-3 rounded-xl bg-gradient-to-r from-pink-500 to-pink-600 text-white font-semibold text-sm hover:from-pink-600 hover:to-pink-700 shadow-md shadow-pink-100 transition flex items-center justify-center gap-2"
                  >
                    <Camera size={16} /> Capture selfie
                  </button>
                  <button
                    onClick={() => setPhase("intro")}
                    className="w-full text-xs text-gray-400 hover:text-gray-600 transition py-1"
                  >
                    ← Back to instructions
                  </button>
                </div>
              )}
            </>
          )}
        </div>
        <canvas ref={canvasRef} className="hidden" />
      </div>
    </div>
  );
}

// ─── Main Dashboard ───────────────────────────────────────────────────────────
export default function Dashboard() {
  const { user, profile, logout, clearBan, refreshProfile, banInfo, activeAd } = useAuth();
  const navigate = useNavigate();
  const [view, setView] = useState("discover");
  const [toast, setToast] = useState(null);
  const [matchModal, setMatchModal] = useState(null);
  const [adOpen, setAdOpen] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  // Top-level paywall state. Opened by CallOverlay via the `paywall:open`
  // window event when a non-Pro user tries to start a call. DiscoverView
  // has its own local paywall for heart/pass quotas — these don't
  // conflict because only one is ever rendered at a time.
  const [topPaywall, setTopPaywall] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [convoLoading, setConvoLoading] = useState(true);
  const [typingMatchId, setTypingMatchId] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const [onlinePartners, setOnlinePartners] = useState(() => new Set());
  const toastTimer = useRef();
  const typingClearTimer = useRef();

  const token = useMemo(() => localStorage.getItem("access_token"), []);
  const userId = user?.id;

  const showToast = useCallback((msg, type = "success") => {
    clearTimeout(toastTimer.current);
    setToast({ msg, type });
    toastTimer.current = setTimeout(() => setToast(null), 3500);
  }, []);

  const loadConvos = useCallback(async () => {
    try {
      const res = await api.messages.conversations();
      setConversations(res);
    } catch (e) {
      /* silent — surfaces elsewhere */
    } finally {
      setConvoLoading(false);
    }
  }, []);

  useEffect(() => { loadConvos(); }, [loadConvos]);

  // Show ad popup once per session when user lands on dashboard
  useEffect(() => {
    if (!activeAd?.image_url) return;
    const key = `ad_seen_${activeAd.image_url}`;
    if (sessionStorage.getItem(key)) return;
    sessionStorage.setItem(key, "1");
    setAdOpen(true);
  }, [activeAd]);

  const loadNotifications = useCallback(async () => {
    try {
      const res = await api.notifications.list();
      setNotifications(res);
    } catch {
      /* table may not exist yet — fail silent */
    }
  }, []);
  useEffect(() => { loadNotifications(); }, [loadNotifications]);

  // Child views dispatch `dashboard:go` when they need the main layout to
  // switch tabs (e.g. the Discover "verify_required" card nudges to profile).
  useEffect(() => {
    function onGo(e) {
      const next = e?.detail;
      if (typeof next === "string") setView(next);
    }
    window.addEventListener("dashboard:go", onGo);
    return () => window.removeEventListener("dashboard:go", onGo);
  }, []);

  // The CallOverlay fires `paywall:open` when a non-Pro user tries to
  // start a call. Detail carries { kind, suggest } so we can pre-select
  // the Pro tier in the subscription modal.
  useEffect(() => {
    function onPaywall(e) {
      setTopPaywall({
        kind:    e?.detail?.kind    || "upgrade",
        suggest: e?.detail?.suggest || null,
      });
    }
    window.addEventListener("paywall:open", onPaywall);
    return () => window.removeEventListener("paywall:open", onPaywall);
  }, []);

  // Real-time chat socket — one connection for the whole app.
  // We use the same socket for call signaling (WebRTC offer/answer/ice),
  // so the `send` callback also drives useCall.
  const { send: wsSend, sendTyping } = useChatSocket({
    token,
    onNewMessage: (evt) => {
      const { match_id, message } = evt;
      // Forward to any listening view
      window.dispatchEvent(new CustomEvent("chat:event", { detail: { kind: "new_message", payload: evt } }));

      setConversations(prev => {
        const idx = prev.findIndex(c => c.match_id === match_id);
        const isActive = window.__activeMatchId === match_id;
        const senderIsMe = message.sender_id === userId;
        const isFromPartner = !senderIsMe;
        const last = {
          content: message.content,
          sender_id: message.sender_id,
          created_at: message.created_at,
        };
        if (idx === -1) {
          loadConvos();
          return prev;
        }
        const updated = { ...prev[idx],
          last_message: last,
          unread_count: isFromPartner && !isActive
            ? (prev[idx].unread_count || 0) + 1
            : prev[idx].unread_count,
        };
        const next = prev.slice();
        next.splice(idx, 1);
        return [updated, ...next];
      });
    },
    onMessagesRead: (evt) => {
      window.dispatchEvent(new CustomEvent("chat:event", { detail: { kind: "messages_read", payload: evt } }));
    },
    onTyping: (evt) => {
      setTypingMatchId(evt.match_id);
      clearTimeout(typingClearTimer.current);
      typingClearTimer.current = setTimeout(() => setTypingMatchId(null), 3000);
    },
    onMatchCreated: () => {
      loadConvos();
    },
    onMatchRemoved: (evt) => {
      const { match_id, removed_by } = evt;
      // Soft-remove: keep the conversation in the list but mark it ended so
      // both sides retain access to the history as a read-only archive.
      const nowIso = new Date().toISOString();
      setConversations(prev => prev.map(c =>
        c.match_id === match_id
          ? { ...c, removed_at: nowIso, removed_by }
          : c
      ));
      // Let MessagesView update the active conversation if it's currently open
      window.dispatchEvent(new CustomEvent("chat:event", { detail: { kind: "match_removed", payload: evt } }));
    },
    onNotification: ({ notification }) => {
      if (!notification) return;
      setNotifications(prev => {
        // Replace if we already have this id (server re-delivery), else prepend
        const idx = prev.findIndex(n => n.id === notification.id);
        if (idx === -1) return [notification, ...prev].slice(0, 50);
        const next = prev.slice();
        next[idx] = notification;
        return next;
      });
      // When a match is restored (we were invited and they accepted, or we
      // were re-added unilaterally), refresh convos so the chat re-opens.
      if (notification.type === "match_restored" || notification.type === "match_created") {
        loadConvos();
      }
    },
    onUserStatus: ({ user_id, online, last_seen }) => {
      setOnlinePartners(prev => {
        const next = new Set(prev);
        if (online) next.add(user_id);
        else next.delete(user_id);
        return next;
      });
      if (!online && last_seen) {
        // Update the partner's last_seen in conversations so the header shows it
        setConversations(prev => prev.map(c =>
          c.partner?.id === user_id
            ? { ...c, partner: { ...c.partner, last_seen } }
            : c
        ));
      }
    },
    onMessagesDelivered: (evt) => {
      window.dispatchEvent(new CustomEvent("chat:event", { detail: { kind: "messages_delivered", payload: evt } }));
    },
    onCallSignal: (msg) => {
      // Forward every call_* / call_error frame straight into the WebRTC
      // hook. The hook owns the state machine — Dashboard is just a pipe.
      callRef.current?.handleSignal(msg);
    },
  });

  // WebRTC voice/video hook. `wsSend` is the chat socket's raw sender —
  // call signaling rides the same connection as typing/messages, so we
  // don't need a second websocket.
  const call = useCall({ sendSignal: wsSend });
  // Stash in a ref so the onCallSignal closure above (defined *before*
  // useCall in source order) can reach the latest hook object without
  // re-subscribing on every render.
  const callRef = useRef(call);
  callRef.current = call;

  const unreadCount = conversations.reduce((n, c) => n + (c.unread_count || 0), 0);

  function handleLogout() {
    logout();
    navigate("/");
  }

  // Banned account — show full-screen ban page instead of the app
  if (banInfo) {
    return <BannedPage banInfo={banInfo} onLogout={() => { clearBan(); navigate("/"); }} />;
  }

  return (
    <div className="flex h-screen bg-[#f8f5ff] overflow-hidden">
      {/* ── Ad popup ───────────────────────────────────────────────── */}
      {adOpen && activeAd?.image_url && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          {/* Mobile: full-width capped at sm. Desktop: much larger poster */}
          <div className="relative w-full max-w-sm md:max-w-xl lg:max-w-2xl rounded-2xl overflow-hidden shadow-2xl">
            {/* X button */}
            <button
              onClick={() => setAdOpen(false)}
              className="absolute top-3 right-3 z-10 bg-black/60 hover:bg-black/80 text-white rounded-full p-1.5 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
            {/* Poster — max-h prevents very tall images from overflowing the viewport */}
            <img
              src={activeAd.image_url}
              alt="Advertisement"
              className="w-full block cursor-pointer max-h-[88vh] object-contain bg-black"
              onClick={() => {
                if (activeAd.link_url) window.open(activeAd.link_url, "_blank", "noopener,noreferrer");
                setAdOpen(false);
              }}
            />
          </div>
        </div>
      )}

      <Sidebar
        profile={profile}
        view={view}
        setView={setView}
        unreadCount={unreadCount}
        onLogout={handleLogout}
        mobileOpen={mobileNavOpen}
        closeMobile={() => setMobileNavOpen(false)}
        showToast={showToast}
      />

      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top bar */}
        <header className="bg-white border-b border-gray-100 px-4 md:px-6 h-14 flex items-center justify-between flex-shrink-0 gap-3">
          <div className="flex items-center gap-2 min-w-0">
            <button
              onClick={() => setMobileNavOpen(true)}
              className="md:hidden p-2 -ml-1 rounded-lg hover:bg-gray-100 flex-shrink-0"
              aria-label="Open menu"
            >
              <Menu size={20} className="text-gray-700" />
            </button>
            <h1 className="font-bold text-gray-800 capitalize truncate text-sm md:text-base">
              {view === "discover" ? "Discover People" : view === "messages" ? "Messages" : view === "likes" ? "People Who Liked You" : "My Profile"}
            </h1>
          </div>
          {profile && (
            <div className="flex items-center gap-1.5 md:gap-2.5 flex-shrink-0">
              <NotificationBell
                notifications={notifications}
                conversations={conversations}
                onAccept={async (n) => {
                  try {
                    await api.matches.acceptInvitation(n.id);
                    // Locally mark the invitation as handled so the buttons vanish
                    setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_handled: true, is_read: true } : x));
                    loadConvos();
                    showToast(`Reconnected with ${n.actor?.name || "friend"} 💕`);
                    setView("messages");
                  } catch (e) {
                    showToast(e.message || "Could not accept", "error");
                  }
                }}
                onDecline={async (n) => {
                  try {
                    await api.matches.declineInvitation(n.id);
                    setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_handled: true, is_read: true } : x));
                  } catch (e) {
                    showToast(e.message || "Could not decline", "error");
                  }
                }}
                onLikeBack={async (n) => {
                  try {
                    const actorId = n.actor?.id || n.actor_id;
                    const res = await api.matches.like(actorId);
                    setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_handled: true, is_read: true } : x));
                    // If they liked us back and we liked them → it's a match!
                    if (res?.match) {
                      setMatchModal(n.actor);
                      loadConvos();
                    } else {
                      showToast(`You liked ${n.actor?.name || "them"} back! ❤️`);
                    }
                  } catch (e) {
                    showToast(e.message || "Could not like", "error");
                  }
                }}
                onPass={async (n) => {
                  try {
                    const actorId = n.actor?.id || n.actor_id;
                    await api.matches.pass(actorId);
                    setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_handled: true, is_read: true } : x));
                  } catch (e) {
                    showToast(e.message || "Could not pass", "error");
                  }
                }}
                onOpenChat={(c) => {
                  // Route the user to Messages and let them pick up the chat.
                  setView("messages");
                  window.dispatchEvent(new CustomEvent("chat:openConversation", { detail: { match_id: c.match_id } }));
                }}
                onMarkAllRead={async () => {
                  try {
                    await api.notifications.readAll();
                    setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
                  } catch { /* non-fatal */ }
                }}
                onMarkRead={async (id) => {
                  try {
                    await api.notifications.read(id);
                    setNotifications(prev => prev.map(n => n.id === id ? { ...n, is_read: true } : n));
                  } catch { /* non-fatal */ }
                }}
              />
              <span className="text-sm text-gray-500 hidden md:block">
                Hey, <span className="font-semibold text-gray-800">{profile.name?.split(" ")[0]}</span> 👋
              </span>
              <img src={avatar(profile)} alt={profile.name}
                className="w-8 h-8 rounded-full object-cover border-2 border-pink-200 cursor-pointer"
                onClick={() => setView("profile")} />
            </div>
          )}
        </header>

        {/* View content */}
        <div className="flex-1 overflow-auto">
          {view === "discover"  && <DiscoverView  showToast={showToast} onMatch={p => setMatchModal(p)} profile={profile} />}
          {view === "messages"  && <MessagesView  showToast={showToast} userId={userId}
            conversations={conversations} setConversations={setConversations}
            convoLoading={convoLoading} sendTyping={sendTyping} typingMatchId={typingMatchId}
            onlinePartners={onlinePartners}
            onStartCall={(matchId, partner, media) => {
              // Enrich partner with the caller's own identity so the ring
              // card on the other side can show who's calling.
              call.startCall({
                matchId,
                partner: {
                  ...partner,
                  self_name:  profile?.name || "Someone",
                  self_photo: profile?.main_image_url || null,
                },
                media,
              });
            }} />}
          {view === "likes"     && <LikesView     showToast={showToast} />}
          {view === "wallet"    && <WalletView    profile={profile} showToast={showToast} />}
          {view === "profile"   && <ProfileView   profile={profile} onRefresh={refreshProfile} showToast={showToast} conversations={conversations} setView={setView} userId={userId} />}
        </div>
      </div>

      <Toast toast={toast} />
      {matchModal && (
        <MatchModal
          me={profile}
          partner={matchModal}
          onClose={() => setMatchModal(null)}
          onSayHello={() => { setMatchModal(null); setView("messages"); }}
        />
      )}
      {/* Full-screen overlay for any active call — caller ringing, callee
          incoming ring, or the live connected UI. Hidden when idle. */}
      <CallOverlay call={call} />
      {/* Top-level subscription modal — triggered from calling gate or
          any other flow that fires the `paywall:open` event. */}
      {topPaywall && (
        <SubscriptionModal
          trigger={topPaywall.kind}
          suggestTier={topPaywall.suggest}
          profile={profile}
          onClose={() => setTopPaywall(null)}
          onUpgraded={() => {
            setTopPaywall(null);
            showToast?.("You're a Pro! Unlimited calls ⭐");
            window.dispatchEvent(new CustomEvent("subs:changed"));
          }}
          showToast={showToast}
        />
      )}
    </div>
  );
}

// ─── Wallet ──────────────────────────────────────────────────────────────────
// Credits economy:
//   • 1 credit = ₹1 on purchase, minimum pack 50
//   • Bulk discount tiers: 100/5%, 200/10%, 500/20%, 1000/25%
//   • 1 credit = ₹0.70 on cash-out, minimum withdrawal 500 credits
//   • Receiver keeps 70% of gift cost; declined invite refunds 50% to sender
function WalletView({ profile, showToast }) {
  const [balance, setBalance] = useState(null);
  const [packs, setPacks] = useState([]);
  const [config, setConfig] = useState(null);
  const [tx, setTx] = useState([]);
  const [withdrawals, setWithdrawals] = useState([]);
  const [payoutDetails, setPayoutDetails] = useState(null);
  const [billingDetails, setBillingDetails] = useState(null);
  const [loading, setLoading] = useState(true);
  const [buying, setBuying] = useState(null);        // credits currently being purchased
  const [showPayoutModal, setShowPayoutModal] = useState(false);
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  // Billing modal is shown the first time a user checks out. `pendingCredits`
  // remembers what they were about to buy so we can resume the purchase right
  // after they save billing info.
  const [showBillingModal, setShowBillingModal] = useState(false);
  const [pendingCredits, setPendingCredits] = useState(null);
  // Custom top-up: user-entered credit amount. Kept as a string so the
  // input can be empty / mid-edit without snapping back to 0.
  const [customAmount, setCustomAmount] = useState("");
  const CUSTOM_MIN = 5;
  const CUSTOM_MAX = 100000;

  const loadAll = useCallback(async () => {
    // Fetch each resource independently with a timeout. One slow or
    // failing endpoint (e.g. migration not yet applied) must not block
    // the whole page — the UI should still render with safe defaults.
    const withTimeout = (p, ms = 6000, fallback) =>
      Promise.race([
        p.catch(() => fallback),
        new Promise((res) => setTimeout(() => res(fallback), ms)),
      ]);

    const [bal, pk, cfg, txns, pd, w, bd] = await Promise.all([
      withTimeout(api.wallet.balance(),          6000, { balance: 0, lifetime_earned: 0, lifetime_spent: 0, signup_bonus_granted: false }),
      withTimeout(api.wallet.packs(),            6000, []),
      withTimeout(api.wallet.config(),           6000, { is_mock: true, key_id: "mock" }),
      withTimeout(api.wallet.transactions(),     6000, []),
      withTimeout(api.wallet.getPayoutDetails(), 6000, null),
      withTimeout(api.wallet.withdrawals(),      6000, []),
      withTimeout(api.wallet.getBillingDetails(),6000, null),
    ]);
    setBalance(bal);
    setPacks(pk);
    setConfig(cfg);
    setTx(txns);
    setPayoutDetails(pd);
    setWithdrawals(w);
    setBillingDetails(bd);
    setLoading(false);
  }, []);

  useEffect(() => {
    track(EVENTS.CREDITS_VIEWED);
    loadAll();
  }, [loadAll]);

  // Kick off Razorpay Checkout for a pack. In mock mode the backend
  // reports is_mock=true and we skip opening the Razorpay modal — we
  // just call verify directly with a synthetic payment id so the UI
  // flow can be exercised without real keys.
  //
  // Real mode: the server refuses to create an order without billing
  // details on file, so we front-run that check here and show the
  // billing modal first. After save, `onSaved` replays buyPack(credits).
  async function buyPack(credits) {
    // First-time buyers: capture billing once. Mock mode bypasses this
    // since the backend doesn't enforce it for local dev.
    if (!billingDetails && !config?.is_mock) {
      setPendingCredits(credits);
      setShowBillingModal(true);
      return;
    }

    setBuying(credits);
    track(EVENTS.PAYMENT_STARTED, { kind: "credits", credits });
    try {
      const order = await api.wallet.createOrder(credits);

      if (order.is_mock) {
        const res = await api.wallet.verifyPayment({
          order_id: order.order_id,
          payment_id: `pay_mock_${Date.now()}`,
          signature: "mock",
          credits,
        });
        track(EVENTS.PAYMENT_SUCCESS, { kind: "credits", credits, order_id: order.order_id, mock: true });
        showToast?.(`+${res.credited} credits added (mock)`);
        await loadAll();
        return;
      }

      if (!window.Razorpay) {
        showToast?.("Payment SDK not loaded — refresh and retry", "error");
        return;
      }

      // Prefill comes from the server (sourced from billing_details) so
      // the Razorpay modal feels one-click on repeat purchases. Fall back
      // to the locally cached record / profile if the server didn't echo.
      const prefill = order.prefill || (billingDetails ? {
        name:    billingDetails.name,
        email:   billingDetails.email,
        contact: billingDetails.phone,
      } : {
        name:    profile?.name  || "",
        email:   profile?.email || "",
      });

      const rzp = new window.Razorpay({
        key:         order.key_id,
        amount:      order.amount_paise,
        currency:    order.currency,
        name:        "MatchInMinutes",
        description: `${credits} credits`,
        order_id:    order.order_id,
        prefill,
        notes: { user_id: profile?.id || "", credits: String(credits) },
        theme: { color: "#e11d48" },
        handler: async (resp) => {
          try {
            const verified = await api.wallet.verifyPayment({
              order_id:   resp.razorpay_order_id,
              payment_id: resp.razorpay_payment_id,
              signature:  resp.razorpay_signature,
              credits,
            });
            track(EVENTS.PAYMENT_SUCCESS, {
              kind: "credits", credits,
              order_id: resp.razorpay_order_id,
              payment_id: resp.razorpay_payment_id,
            });
            showToast?.(`+${verified.credited} credits added ✨`);
            await loadAll();
          } catch (e) {
            track(EVENTS.PAYMENT_FAILED, {
              kind: "credits", credits,
              order_id: resp.razorpay_order_id,
              reason: e.message || "verify_failed",
            });
            showToast?.(e.message || "Verification failed", "error");
          } finally {
            setBuying(null);
          }
        },
        modal: {
          ondismiss: () => setBuying(null),
        },
      });
      rzp.on("payment.failed", (resp) => {
        showToast?.(resp?.error?.description || "Payment failed", "error");
        setBuying(null);
      });
      rzp.open();
      // Note: we don't setBuying(null) in finally here — it's cleared on
      // dismiss / success / failure so the button stays in "Processing…"
      // state while the Razorpay modal is open.
      return;
    } catch (e) {
      showToast?.(e.message || "Could not start purchase", "error");
    }
    setBuying(null);
  }

  function openWithdraw() {
    if (!payoutDetails) {
      setShowPayoutModal(true);
      return;
    }
    setShowWithdrawModal(true);
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <Loader2 className="animate-spin text-rose-500" size={28} />
      </div>
    );
  }

  // Client-side fallback mirrors the server's PRICE_TIERS so the buy section
  // still renders if /wallet/packs is slow or unreachable. Kept in sync
  // manually — trivial array; not worth an abstraction.
  const FALLBACK_PACKS = [
    { credits: 50,   inr_paise: 5000,   inr: 50,   discount_pct: 0 },
    { credits: 100,  inr_paise: 9500,   inr: 95,   discount_pct: 5 },
    { credits: 200,  inr_paise: 18000,  inr: 180,  discount_pct: 10 },
    { credits: 500,  inr_paise: 40000,  inr: 400,  discount_pct: 20 },
    { credits: 1000, inr_paise: 75000,  inr: 750,  discount_pct: 25 },
  ];
  const displayPacks = packs.length ? packs : FALLBACK_PACKS;
  // Pick the biggest discount pack as "Best value" so the CTA grid has a clear anchor.
  const featuredPack = displayPacks.find(p => p.discount_pct === Math.max(...displayPacks.map(x => x.discount_pct))) || displayPacks[0];

  return (
    <div className="min-h-full bg-gradient-to-br from-rose-50 via-pink-50/60 to-rose-50 p-3 sm:p-5 md:p-8">
      <div className="max-w-5xl mx-auto space-y-4 md:space-y-5">

        {/* ── Page header ────────────────────────────────────────── */}
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div>
            <h2 className="text-xl md:text-2xl font-bold text-gray-900 tracking-tight">Wallet</h2>
            <p className="text-xs text-gray-500 mt-0.5">
              Credits power gifts, boosts and more on MatchInMinutes.
            </p>
          </div>
          {config?.is_mock && (
            <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wider bg-amber-50 text-amber-700 border border-amber-200 px-2.5 py-1 rounded-full">
              <AlertCircle size={11} /> Test mode
            </span>
          )}
        </div>

        {/* ── Balance card ───────────────────────────────────────── */}
        <section className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-rose-600 via-pink-500 to-rose-500 text-white p-6 md:p-8 shadow-xl shadow-rose-200/50">
          <div className="absolute -top-12 -right-12 w-52 h-52 rounded-full bg-white/10 blur-3xl pointer-events-none" />
          <div className="absolute -bottom-16 -left-12 w-64 h-64 rounded-full bg-white/5 blur-3xl pointer-events-none" />
          <div className="relative flex flex-col md:flex-row md:items-end md:justify-between gap-5">
            <div className="min-w-0">
              <p className="text-[11px] uppercase tracking-[0.2em] text-white/70 font-semibold">Available balance</p>
              <div className="mt-2 flex items-baseline gap-2.5">
                <Coins size={30} className="text-amber-200 drop-shadow" />
                <span className="text-5xl md:text-6xl font-black tracking-tight leading-none">
                  {(balance?.balance ?? 0).toLocaleString()}
                </span>
                <span className="text-sm font-semibold text-white/80">credits</span>
              </div>
              <div className="mt-4 flex items-center gap-5 text-xs text-white/80">
                <span className="inline-flex items-center gap-1.5">
                  <ArrowDownCircle size={13} className="text-emerald-200" />
                  <span className="font-semibold text-white">{(balance?.lifetime_earned ?? 0).toLocaleString()}</span>
                  <span className="text-white/60">earned</span>
                </span>
                <span className="h-3 w-px bg-white/20" />
                <span className="inline-flex items-center gap-1.5">
                  <Gift size={13} className="text-pink-200" />
                  <span className="font-semibold text-white">{(balance?.lifetime_spent ?? 0).toLocaleString()}</span>
                  <span className="text-white/60">spent on gifts</span>
                </span>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <button
                onClick={() => {
                  const el = document.getElementById("buy-credits");
                  el?.scrollIntoView({ behavior: "smooth", block: "start" });
                }}
                className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-white text-rose-600 text-sm font-bold hover:bg-rose-50 transition shadow-md"
              >
                <Plus size={15} /> Add credits
              </button>
              <button
                onClick={openWithdraw}
                className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-sm font-semibold border border-white/25 backdrop-blur transition"
              >
                <ArrowUpCircle size={15} /> Request payout
              </button>
            </div>
          </div>
        </section>

        {/* ── Buy credits ─────────────────────────────────────────── */}
        <section id="buy-credits" className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-5 md:p-6">
          <div className="flex items-start justify-between gap-4 mb-5">
            <div>
              <h3 className="font-bold text-gray-900 text-base md:text-lg tracking-tight">Buy credits</h3>
              <p className="text-xs text-gray-500 mt-0.5">
                Choose a pack — bigger packs include a bonus discount.
              </p>
            </div>
            <span className="flex-shrink-0 inline-flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wider text-gray-500 bg-gray-100 px-2.5 py-1 rounded-full">
              <svg width="10" height="10" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M10 2a4 4 0 00-4 4v2H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-1V6a4 4 0 00-4-4zm2 6H8V6a2 2 0 114 0v2z"/></svg>
              Secured by Razorpay
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5">
            {displayPacks.map((p) => {
              const isFeatured = featuredPack && p.credits === featuredPack.credits && p.discount_pct > 0;
              const isBuying = buying === p.credits;
              return (
                <button
                  key={p.credits}
                  onClick={() => buyPack(p.credits)}
                  disabled={buying !== null}
                  className={`group relative rounded-2xl p-5 text-left transition disabled:opacity-60 disabled:cursor-not-allowed ${
                    isFeatured
                      ? "bg-gradient-to-br from-rose-50 to-pink-50 border-2 border-rose-300 hover:border-rose-400 shadow-sm hover:shadow-lg"
                      : "bg-white border border-gray-200 hover:border-rose-300 hover:shadow-md"
                  }`}
                >
                  {isFeatured && (
                    <span className="absolute -top-2.5 left-5 inline-flex items-center gap-1 bg-gradient-to-r from-rose-500 to-pink-500 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow uppercase tracking-wider">
                      <Sparkles size={10} /> Best value
                    </span>
                  )}
                  {p.discount_pct > 0 && !isFeatured && (
                    <span className="absolute top-3 right-3 bg-emerald-50 text-emerald-700 text-[10px] font-bold px-2 py-0.5 rounded-full border border-emerald-200">
                      Save {p.discount_pct}%
                    </span>
                  )}

                  <div className="flex items-center gap-2.5">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-100 to-rose-100 flex items-center justify-center shadow-inner">
                      <Coins size={18} className="text-rose-500" />
                    </div>
                    <div>
                      <p className="text-2xl font-black text-gray-900 leading-none tracking-tight">
                        {p.credits.toLocaleString()}
                      </p>
                      <p className="text-[11px] text-gray-500 font-medium uppercase tracking-wider mt-0.5">
                        credits
                      </p>
                    </div>
                  </div>

                  <div className="mt-5 flex items-baseline gap-2">
                    <span className="text-xl font-bold text-gray-900">
                      ₹{(p.inr_paise / 100).toFixed(0)}
                    </span>
                    {p.discount_pct > 0 && (
                      <span className="text-xs text-gray-400 line-through font-medium">
                        ₹{p.credits}
                      </span>
                    )}
                  </div>

                  <div className={`mt-4 inline-flex items-center justify-center w-full gap-1.5 py-2 rounded-lg text-xs font-bold transition ${
                    isFeatured
                      ? "bg-rose-500 text-white group-hover:bg-rose-600"
                      : "bg-gray-50 text-gray-700 group-hover:bg-rose-500 group-hover:text-white"
                  }`}>
                    {isBuying ? (
                      <><Loader2 size={12} className="animate-spin" /> Processing…</>
                    ) : (
                      <>Buy now</>
                    )}
                  </div>
                </button>
              );
            })}

            {/* Custom-amount card — same footprint as a pack tile. No bulk
                discount applies here (1 credit = ₹1), minimum 5. Rendered
                last so it sits after the 1000-credit Best Value card. */}
            {(() => {
              const n = parseInt(customAmount, 10);
              const valid = Number.isFinite(n) && n >= CUSTOM_MIN && n <= CUSTOM_MAX;
              const isBuying = buying === n && valid;
              return (
                <div
                  className="relative rounded-2xl p-5 bg-gradient-to-br from-sky-50 via-indigo-50 to-violet-50 border border-indigo-200 hover:border-indigo-400 hover:shadow-md transition"
                >
                  <span className="absolute -top-2.5 left-5 inline-flex items-center gap-1 bg-gradient-to-r from-indigo-500 to-violet-500 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow uppercase tracking-wider">
                    <Sparkles size={10} /> Custom
                  </span>

                  <div className="flex items-center gap-2.5">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-100 to-violet-100 flex items-center justify-center shadow-inner">
                      <Coins size={18} className="text-indigo-500" />
                    </div>
                    <div>
                      <p className="text-sm font-bold text-gray-900 leading-tight">Any amount</p>
                      <p className="text-[11px] text-gray-500 font-medium uppercase tracking-wider mt-0.5">
                        min {CUSTOM_MIN} credits
                      </p>
                    </div>
                  </div>

                  <label className="mt-4 block">
                    <span className="sr-only">Credits to buy</span>
                    <div className="flex items-stretch rounded-lg border border-indigo-200 bg-white focus-within:border-indigo-400 focus-within:ring-2 focus-within:ring-indigo-200 transition overflow-hidden">
                      <input
                        type="number"
                        min={CUSTOM_MIN}
                        max={CUSTOM_MAX}
                        step={1}
                        inputMode="numeric"
                        placeholder="Enter credits"
                        value={customAmount}
                        onChange={(e) => setCustomAmount(e.target.value.replace(/[^0-9]/g, ""))}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" && valid && buying === null) buyPack(n);
                        }}
                        className="flex-1 min-w-0 px-3 py-2 text-sm font-semibold text-gray-900 bg-transparent outline-none"
                      />
                      <span className="px-2.5 py-2 text-xs font-semibold text-indigo-600 bg-indigo-50/70 border-l border-indigo-100 flex items-center">
                        credits
                      </span>
                    </div>
                  </label>

                  <div className="mt-2 flex items-baseline justify-between">
                    <span className="text-xs text-gray-500">You pay</span>
                    <span className="text-lg font-bold text-gray-900">
                      ₹{valid ? n : 0}
                    </span>
                  </div>

                  <button
                    type="button"
                    onClick={() => valid && buyPack(n)}
                    disabled={!valid || buying !== null}
                    className="mt-3 w-full inline-flex items-center justify-center gap-1.5 py-2 rounded-lg text-xs font-bold bg-gradient-to-br from-indigo-500 to-violet-500 text-white shadow hover:from-indigo-600 hover:to-violet-600 disabled:opacity-45 disabled:cursor-not-allowed transition"
                  >
                    {isBuying
                      ? <><Loader2 size={12} className="animate-spin" /> Processing…</>
                      : <>Buy custom</>}
                  </button>

                  {customAmount && !valid && (
                    <p className="mt-2 text-[11px] text-rose-600 font-medium">
                      Enter a whole number between {CUSTOM_MIN} and {CUSTOM_MAX.toLocaleString()}.
                    </p>
                  )}
                </div>
              );
            })()}
          </div>

          <p className="mt-5 text-[11px] text-gray-400 text-center">
            Payments are processed securely by Razorpay. Credits are added instantly after payment.
          </p>
        </section>

        {/* ── Activity ────────────────────────────────────────────── */}
        <section className="bg-white rounded-3xl shadow-sm border border-rose-100/60 p-5 md:p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold text-gray-900 text-base tracking-tight">Recent activity</h3>
            {tx.length > 0 && (
              <span className="text-[11px] text-gray-400">
                Last {Math.min(tx.length, 50)} entries
              </span>
            )}
          </div>
          {tx.length === 0 ? (
            <div className="py-12 text-center">
              <div className="w-12 h-12 rounded-2xl bg-rose-50 text-rose-400 mx-auto flex items-center justify-center mb-3">
                <Coins size={20} />
              </div>
              <p className="text-sm font-semibold text-gray-500">No activity yet</p>
              <p className="text-xs text-gray-400 mt-1">Your purchases, gifts and payouts will appear here.</p>
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {tx.map((t) => (
                <TxRow key={t.id} t={t} />
              ))}
            </ul>
          )}
        </section>
      </div>

      {showBillingModal && (
        <BillingDetailsModal
          current={billingDetails}
          profile={profile}
          onClose={() => {
            setShowBillingModal(false);
            setPendingCredits(null);
          }}
          onSaved={async (saved) => {
            setBillingDetails(saved);
            setShowBillingModal(false);
            const resumeCredits = pendingCredits;
            setPendingCredits(null);
            showToast?.("Billing details saved");
            if (resumeCredits) {
              // Resume the buy flow. The modal already set
              // billingDetails above so buyPack now has what it needs.
              setTimeout(() => buyPack(resumeCredits), 50);
            }
          }}
          showToast={showToast}
        />
      )}

      {showPayoutModal && (
        <PayoutDetailsModal
          current={payoutDetails}
          onClose={() => setShowPayoutModal(false)}
          onSaved={async () => {
            setShowPayoutModal(false);
            await loadAll();
            showToast?.("Payout details saved");
            setShowWithdrawModal(true);
          }}
          showToast={showToast}
        />
      )}

      {showWithdrawModal && (
        <WithdrawModal
          balance={balance}
          payoutDetails={payoutDetails}
          withdrawals={withdrawals}
          onChangeDetails={() => { setShowWithdrawModal(false); setShowPayoutModal(true); }}
          onClose={() => setShowWithdrawModal(false)}
          onDone={async () => {
            setShowWithdrawModal(false);
            await loadAll();
            showToast?.("Payout request submitted");
          }}
          showToast={showToast}
        />
      )}
    </div>
  );
}

// A single row in the transactions ledger. Maps the server `kind` enum to
// a human-readable label + icon + colour so the history is scannable.
function TxRow({ t }) {
  const meta = TX_KIND_META[t.kind] || { label: t.kind, icon: Coins, color: "gray" };
  const Icon = meta.icon;
  const positive = t.delta > 0;
  return (
    <li className="flex items-center gap-3 py-2.5">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${meta.bg}`}>
        <Icon size={15} className={meta.fg} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-gray-800 truncate">{meta.label}</p>
        <p className="text-[11px] text-gray-400">{timeAgo(t.created_at)}</p>
      </div>
      <div className={`text-sm font-bold ${positive ? "text-emerald-600" : "text-rose-600"}`}>
        {positive ? "+" : ""}{t.delta}
      </div>
    </li>
  );
}

const TX_KIND_META = {
  purchase:          { label: "Credits purchased",    icon: ArrowDownCircle, bg: "bg-emerald-50", fg: "text-emerald-600" },
  signup_bonus:      { label: "Welcome bonus",        icon: Sparkles,        bg: "bg-amber-50",   fg: "text-amber-600" },
  gift_sent:         { label: "Gift sent",            icon: Gift,            bg: "bg-rose-50",    fg: "text-rose-600" },
  gift_received:     { label: "Gift received",        icon: Gift,            bg: "bg-pink-50",    fg: "text-pink-600" },
  gift_refund:       { label: "Gift refund",          icon: Gift,            bg: "bg-gray-50",    fg: "text-gray-600" },
  withdrawal_hold:   { label: "Withdrawal requested", icon: ArrowUpCircle,   bg: "bg-blue-50",    fg: "text-blue-600" },
  withdrawal_refund: { label: "Withdrawal refunded",  icon: ArrowDownCircle, bg: "bg-gray-50",    fg: "text-gray-600" },
  admin_adjust:      { label: "Admin adjustment",     icon: Coins,           bg: "bg-gray-50",    fg: "text-gray-600" },
};

// Premium paywall. Shown when a free-tier man exhausts daily hearts /
// passes (backend raises 402 quota_exceeded) or when they tap the quota
// chip. Three plans — monthly / 3-month / 6-month — priced per-month but
// billed upfront via Razorpay. Reuses the billing_details flow we set up
// for the wallet so first-time checkouts collect name/phone/email/address
// exactly once.
function SubscriptionModal({ trigger, suggestTier, profile, onClose, onUpgraded, showToast }) {
  // Two-tier ladder: Plus (unlimited hearts/passes) and Pro (Plus + voice
  // & video calls). We render a tab row so the user can switch — the
  // tab is pre-selected based on what triggered the paywall.
  //
  // - trigger="calls" or suggestTier="pro" → default to Pro
  // - trigger="heart" / "pass" / "upgrade" → default to Plus
  const defaultTier =
    (suggestTier === "pro" || trigger === "calls") ? "pro" : "plus";
  const [tier, setTier] = useState(defaultTier);
  const [plans, setPlans]       = useState(null);
  // Per-tier selection; we preserve the user's picks independently so
  // tab-switching doesn't lose state.
  const [selectedByTier, setSelectedByTier] = useState({
    plus: "plus_quarterly",
    pro:  "pro_quarterly",
  });
  const selected = selectedByTier[tier];
  const [buying, setBuying]     = useState(false);
  const [billing, setBilling]   = useState(null);
  const [showBilling, setShowBilling] = useState(false);
  const [config, setConfig]     = useState(null);

  // Lazy-load plans, billing, razorpay config in parallel. Each is
  // independent — slow ones mustn't block the modal from appearing.
  useEffect(() => {
    track(EVENTS.PLANS_VIEWED, { trigger });
    Promise.all([
      api.subscriptions.plans().catch(() => null),
      api.wallet.getBillingDetails().catch(() => null),
      api.wallet.config().catch(() => ({ is_mock: true, key_id: "mock" })),
    ]).then(([p, b, c]) => {
      if (p) setPlans(p);
      setBilling(b);
      setConfig(c);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Filter down to the plans of the current tier. Backend returns all
  // six ordered; we slice by `tier` for rendering. The server-embedded
  // paywall plans (trigger="heart" / "pass") are already tier-filtered
  // so that case doesn't even need the toggle to matter.
  const plansForTier = plans?.plans?.filter((p) => p.tier === tier) || [];
  const activePlan = plansForTier.find(p => p.slug === selected) || plansForTier[0];

  async function startCheckout() {
    // Collect billing first-time (real mode only) — same rule as wallet.
    if (!billing && !config?.is_mock) {
      setShowBilling(true);
      return;
    }
    if (!selected) return; // plans not loaded yet
    setBuying(true);
    track(EVENTS.PAYMENT_STARTED, {
      kind:        "subscription",
      slug:        selected,
      tier,
      amount_inr:  activePlan?.total_inr,
    });
    try {
      const order = await api.subscriptions.createOrder(selected);

      if (order.is_mock) {
        const res = await api.subscriptions.verify({
          order_id:   order.order_id,
          payment_id: `pay_mock_${Date.now()}`,
          signature:  "mock",
          plan:       selected,
        });
        track(EVENTS.PAYMENT_SUCCESS, {
          kind: "subscription", slug: selected, tier,
          amount_inr: activePlan?.total_inr, order_id: order.order_id, mock: true,
        });
        const tierLabel = tier === "pro" ? "Pro" : "Plus";
        showToast?.(`${tierLabel} activated until ${new Date(res.expires_at).toLocaleDateString()} (mock)`);
        onUpgraded?.();
        return;
      }

      if (!window.Razorpay) {
        showToast?.("Payment SDK not loaded — refresh and retry", "error");
        return;
      }

      const prefill = order.prefill || (billing ? {
        name:    billing.name,
        email:   billing.email,
        contact: billing.phone,
      } : {
        name:  profile?.name  || "",
        email: profile?.email || "",
      });

      const rzp = new window.Razorpay({
        key:         order.key_id,
        amount:      order.amount_paise,
        currency:    order.currency,
        name:        `MatchInMinutes ${tier === "pro" ? "Pro" : "Plus"}`,
        description: `${activePlan?.label || selected} plan`,
        order_id:    order.order_id,
        prefill,
        theme:       { color: tier === "pro" ? "#d97706" : "#e11d48" },
        handler: async (resp) => {
          try {
            const res = await api.subscriptions.verify({
              order_id:   resp.razorpay_order_id,
              payment_id: resp.razorpay_payment_id,
              signature:  resp.razorpay_signature,
              plan:       selected,
            });
            track(EVENTS.PAYMENT_SUCCESS, {
              kind: "subscription", slug: selected, tier,
              amount_inr: activePlan?.total_inr,
              order_id: resp.razorpay_order_id,
              payment_id: resp.razorpay_payment_id,
            });
            const tierLabel = tier === "pro" ? "Pro" : "Plus";
            showToast?.(`${tierLabel} active until ${new Date(res.expires_at).toLocaleDateString()} ✨`);
            onUpgraded?.();
          } catch (e) {
            track(EVENTS.PAYMENT_FAILED, {
              kind: "subscription", slug: selected, tier,
              order_id: resp.razorpay_order_id, reason: e.message || "verify_failed",
            });
            showToast?.(e.message || "Verification failed", "error");
          } finally {
            setBuying(false);
          }
        },
        modal: { ondismiss: () => setBuying(false) },
      });
      rzp.on("payment.failed", (r) => {
        track(EVENTS.PAYMENT_FAILED, {
          kind: "subscription", slug: selected, tier,
          reason: r?.error?.description || "razorpay_failed",
          code:   r?.error?.code,
        });
        showToast?.(r?.error?.description || "Payment failed", "error");
        setBuying(false);
      });
      rzp.open();
      return; // don't clear buying — modal is now driving it
    } catch (e) {
      track(EVENTS.PAYMENT_FAILED, {
        kind: "subscription", slug: selected, tier,
        reason: e.message || "order_create_failed",
      });
      showToast?.(e.message || "Could not start checkout", "error");
    }
    setBuying(false);
  }

  const headline =
    trigger === "calls"         ? "Call your matches"
    : trigger === "heart"       ? "Free trial ended 💔"
    : trigger === "pass"        ? "Free trial ended 😕"
    : trigger === "instant_match" ? "Instant Match limit reached ⚡"
    : "Upgrade your experience";

  const subline =
    trigger === "calls"         ? "Voice & video calls are a Pro feature. Upgrade to start calling your matches."
    : trigger === "heart"       ? "You've used all your free likes. Upgrade to Plus for unlimited likes and never miss a match."
    : trigger === "pass"        ? "You've used all your free passes. Upgrade to Plus to swipe without limits."
    : trigger === "instant_match" ? "You've used your 2 free Instant Matches today. Upgrade to Pro for unlimited real-time connections."
    : "Unlock unlimited swipes — or go Pro for calls on top.";

  // Which tier headlines the header gradient. Pro is gold, Plus is rose.
  const isPro = tier === "pro";
  const headerGradient = isPro
    ? "from-amber-500 via-orange-500 to-amber-600"
    : "from-rose-500 via-pink-500 to-rose-500";

  return (
    <>
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
        <div className="bg-white rounded-3xl w-full max-w-xl shadow-2xl overflow-hidden my-6">
          {/* Header — gradient matches the selected tier */}
          <div className={`relative bg-gradient-to-br ${headerGradient} text-white p-6 pb-8 transition-colors`}>
            <button onClick={onClose}
              className="absolute top-4 right-4 w-8 h-8 rounded-full bg-white/15 hover:bg-white/25 flex items-center justify-center transition">
              <X size={16} />
            </button>
            <div className="inline-flex items-center gap-1.5 bg-white/15 text-white text-[10px] uppercase tracking-[0.18em] font-bold px-2.5 py-1 rounded-full mb-2.5">
              {isPro ? <>⭐ MatchInMinutes Pro</> : <><Sparkles size={11} /> MatchInMinutes Plus</>}
            </div>
            <h3 className="text-xl md:text-2xl font-black leading-tight">{headline}</h3>
            <p className="text-white/85 text-xs md:text-sm mt-1">{subline}</p>
          </div>

          {/* Plans */}
          <div className="p-5 -mt-4">
            {/* Tier toggle — Plus | Pro. Pro has a gold accent to match
                its "premium upgrade" positioning. */}
            <div className="mb-4 flex rounded-2xl bg-gray-100 p-1 relative">
              <button
                onClick={() => setTier("plus")}
                className={`flex-1 py-2 rounded-xl text-sm font-bold transition relative ${
                  !isPro ? "bg-white shadow text-gray-900" : "text-gray-500"
                }`}
              >
                Plus
                <span className="block text-[9px] font-normal text-gray-500 mt-0.5">Unlimited swipes</span>
              </button>
              <button
                onClick={() => setTier("pro")}
                className={`flex-1 py-2 rounded-xl text-sm font-bold transition relative ${
                  isPro ? "bg-white shadow text-amber-700" : "text-gray-500"
                }`}
              >
                Pro ⭐
                <span className="block text-[9px] font-normal text-gray-500 mt-0.5">+ Voice & video calls</span>
              </button>
            </div>

            {!plans ? (
              <div className="py-10 text-center">
                <Loader2 className={`animate-spin mx-auto ${isPro ? "text-amber-500" : "text-rose-500"}`} size={22} />
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {plansForTier.map((p) => {
                  const isActive = selected === p.slug;
                  const isBest = p.months === 6; // 6-month plan is always "best value"
                  const borderActive = isPro
                    ? "border-amber-500 bg-amber-50/70"
                    : "border-rose-500 bg-rose-50/70";
                  const borderHover = isPro
                    ? "border-gray-200 bg-white hover:border-amber-300"
                    : "border-gray-200 bg-white hover:border-rose-300";
                  const dotActive = isPro
                    ? "border-amber-500 bg-amber-500"
                    : "border-rose-500 bg-rose-500";
                  return (
                    <button
                      key={p.slug}
                      onClick={() => setSelectedByTier((s) => ({ ...s, [tier]: p.slug }))}
                      className={`relative rounded-2xl p-4 text-left transition border-2 ${
                        isActive ? `${borderActive} shadow-sm` : borderHover
                      }`}
                    >
                      {isBest && (
                        <span className={`absolute -top-2.5 left-1/2 -translate-x-1/2 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow uppercase tracking-wider whitespace-nowrap bg-gradient-to-r ${
                          isPro ? "from-amber-400 to-orange-500" : "from-amber-400 to-rose-500"
                        }`}>
                          Best value
                        </span>
                      )}
                      <div className="flex items-start justify-between gap-2">
                        {/* Drop the "Plus ·" / "Pro ·" prefix here since
                            the tier is already signalled by the toggle above. */}
                        <p className="text-sm font-bold text-gray-900">
                          {p.label.replace(/^(Plus|Pro)\s·\s/, "")}
                        </p>
                        <div className={`w-4 h-4 rounded-full border-2 flex-shrink-0 flex items-center justify-center ${
                          isActive ? dotActive : "border-gray-300"
                        }`}>
                          {isActive && <span className="w-1.5 h-1.5 rounded-full bg-white" />}
                        </div>
                      </div>
                      <div className="mt-2.5 flex items-baseline gap-1">
                        <span className="text-xl font-black text-gray-900">₹{p.monthly_inr}</span>
                        <span className="text-[11px] text-gray-500 font-semibold">/mo</span>
                      </div>
                      <p className="text-[11px] text-gray-500 mt-0.5">
                        Billed ₹{p.total_inr.toLocaleString()} {p.months > 1 && <>• {p.months} mo</>}
                      </p>
                      {p.months === 3 && (
                        <p className="text-[10px] text-emerald-600 font-semibold mt-1">Save 10%</p>
                      )}
                      {p.months === 6 && (
                        <p className="text-[10px] text-emerald-600 font-semibold mt-1">Save 25%</p>
                      )}
                    </button>
                  );
                })}
              </div>
            )}

            {/* Perks — tier-specific. Pro extends Plus, so Pro shows the
                Plus line-items too (hierarchy is important for the
                "why pay more" story). */}
            <ul className="mt-5 space-y-2">
              {(isPro
                ? [
                    "Unlimited voice & video calls with your matches",
                    "Everything in Plus — unlimited hearts + passes",
                    "Priority support",
                    "Cancel anytime, no auto-renewal",
                  ]
                : [
                    "Unlimited likes every day",
                    "Unlimited passes — never run out of swipes",
                    "Cancel anytime, no auto-renewal",
                    "Secure checkout by Razorpay",
                  ]
              ).map((t, i) => (
                <li key={i} className="flex items-start gap-2 text-xs text-gray-700">
                  <div className={`w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${
                    isPro ? "bg-amber-50 text-amber-600" : "bg-emerald-50 text-emerald-600"
                  }`}>
                    <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
                      <path d="M2 6.5L5 9.5L10 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                  {t}
                </li>
              ))}
            </ul>

            <button
              onClick={startCheckout}
              disabled={buying || !activePlan}
              className={`mt-5 w-full inline-flex items-center justify-center gap-2 py-3 rounded-xl text-white font-bold text-sm disabled:opacity-50 shadow-md transition ${
                isPro
                  ? "bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 shadow-amber-200/50"
                  : "bg-gradient-to-r from-rose-500 to-pink-500 hover:from-rose-600 hover:to-pink-600 shadow-rose-200/50"
              }`}
            >
              {buying
                ? <><Loader2 size={14} className="animate-spin" /> Processing…</>
                : <>Continue — ₹{activePlan?.total_inr?.toLocaleString()}</>}
            </button>
            <p className="mt-2.5 text-[10px] text-gray-400 text-center">
              {config?.is_mock ? "Test mode — no real charge." : "One-time upfront payment. No auto-renew."}
            </p>
          </div>
        </div>
      </div>

      {showBilling && (
        <BillingDetailsModal
          current={billing}
          profile={profile}
          onClose={() => setShowBilling(false)}
          onSaved={(saved) => {
            setBilling(saved);
            setShowBilling(false);
            // Resume checkout right after billing is captured.
            setTimeout(() => startCheckout(), 50);
          }}
          showToast={showToast}
        />
      )}
    </>
  );
}


// Billing details modal. Shown the first time a user checks out in real
// (non-mock) mode — Razorpay needs a name/email/phone/address for GST
// receipts and dispute handling. Stored server-side and reused for every
// subsequent purchase so the flow is one-click.
function BillingDetailsModal({ current, profile, onClose, onSaved, showToast }) {
  const [form, setForm] = useState({
    name:          current?.name          || profile?.name  || "",
    email:         current?.email         || profile?.email || "",
    phone:         current?.phone         || "",
    address_line1: current?.address_line1 || "",
    address_line2: current?.address_line2 || "",
    city:          current?.city          || "",
    state:         current?.state         || "",
    pincode:       current?.pincode       || "",
    country:       current?.country       || "IN",
  });
  const [saving, setSaving] = useState(false);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  // Lightweight client-side validation so we don't round-trip just to
  // tell the user their pincode is 5 digits. Server re-validates.
  function validate() {
    if (!form.name.trim())          return "Full name is required";
    if (!/.+@.+\..+/.test(form.email)) return "Enter a valid email";
    const digits = form.phone.replace(/\D/g, "");
    if (digits.length < 10)         return "Phone must have at least 10 digits";
    if (!form.address_line1.trim()) return "Address line 1 is required";
    if (!form.city.trim())          return "City is required";
    if (!form.state.trim())         return "State is required";
    if (!/^\d{6}$/.test(form.pincode)) return "Pincode must be 6 digits";
    return null;
  }

  async function save() {
    const err = validate();
    if (err) { showToast?.(err, "error"); return; }
    setSaving(true);
    try {
      const saved = await api.wallet.setBillingDetails(form);
      onSaved(saved);
    } catch (e) {
      showToast?.(e.message || "Save failed", "error");
    } finally {
      setSaving(false);
    }
  }

  const inputCls =
    "w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400 focus:border-rose-400";
  const labelCls =
    "block text-[11px] font-semibold text-gray-500 mb-1 uppercase tracking-wide";

  return (
    <div className="fixed inset-0 bg-black/55 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl w-full max-w-lg shadow-xl overflow-hidden my-6">
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-bold text-gray-900">Billing details</h3>
            <p className="text-[11px] text-gray-500 mt-0.5">
              We save this once and reuse it for every purchase. Required by Razorpay for receipts.
            </p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 flex-shrink-0">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 space-y-3 max-h-[70vh] overflow-y-auto">
          <div>
            <label className={labelCls}>Full name</label>
            <input className={inputCls} value={form.name}
              onChange={(e) => set("name", e.target.value)} placeholder="As on your ID" />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Email</label>
              <input className={inputCls} type="email" value={form.email}
                onChange={(e) => set("email", e.target.value)} placeholder="you@example.com" />
            </div>
            <div>
              <label className={labelCls}>Phone</label>
              <input className={inputCls} inputMode="tel" value={form.phone}
                onChange={(e) => set("phone", e.target.value)} placeholder="+91 9xxxxxxxxx" />
            </div>
          </div>

          <div>
            <label className={labelCls}>Address line 1</label>
            <input className={inputCls} value={form.address_line1}
              onChange={(e) => set("address_line1", e.target.value)}
              placeholder="Flat / Street / Landmark" />
          </div>

          <div>
            <label className={labelCls}>Address line 2 <span className="text-gray-300">(optional)</span></label>
            <input className={inputCls} value={form.address_line2}
              onChange={(e) => set("address_line2", e.target.value)}
              placeholder="Apartment / Building" />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>City</label>
              <input className={inputCls} value={form.city}
                onChange={(e) => set("city", e.target.value)} />
            </div>
            <div>
              <label className={labelCls}>State</label>
              <input className={inputCls} value={form.state}
                onChange={(e) => set("state", e.target.value)} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={labelCls}>Pincode</label>
              <input className={inputCls} inputMode="numeric" maxLength={6} value={form.pincode}
                onChange={(e) => set("pincode", e.target.value.replace(/\D/g, ""))} />
            </div>
            <div>
              <label className={labelCls}>Country</label>
              <input className={inputCls} value={form.country}
                onChange={(e) => set("country", e.target.value.toUpperCase())} />
            </div>
          </div>

          <p className="text-[11px] text-gray-400 pt-1">
            Your details are stored securely on our servers and passed to Razorpay only at checkout.
          </p>
        </div>

        <div className="px-5 py-4 bg-gray-50 flex items-center justify-end gap-2">
          <button onClick={onClose}
            className="px-4 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 rounded-lg">
            Cancel
          </button>
          <button onClick={save} disabled={saving}
            className="inline-flex items-center gap-1.5 px-5 py-2 rounded-lg bg-gradient-to-r from-rose-500 to-pink-500 text-white text-sm font-semibold hover:from-rose-600 hover:to-pink-600 disabled:opacity-50">
            {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
            Save & continue
          </button>
        </div>
      </div>
    </div>
  );
}


// UPI / bank details modal. Razorpay X needs one of these before a
// payout can be issued; we capture it lazily the first time the user
// tries to withdraw so new users aren't forced through the form early.
function PayoutDetailsModal({ current, onClose, onSaved, showToast }) {
  const [method, setMethod] = useState(current?.method || "upi");
  const [upi, setUpi] = useState(current?.upi_id || "");
  const [name, setName] = useState(current?.account_name || "");
  const [acct, setAcct] = useState("");
  const [ifsc, setIfsc] = useState(current?.ifsc || "");
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      const payload = method === "upi"
        ? { method, upi_id: upi.trim() }
        : { method, account_name: name.trim(), account_number: acct.trim(), ifsc: ifsc.trim().toUpperCase() };
      await api.wallet.setPayoutDetails(payload);
      onSaved();
    } catch (e) {
      showToast?.(e.message || "Save failed", "error");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl w-full max-w-md shadow-xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <h3 className="font-bold text-gray-900">Payout details</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X size={18} />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-2 p-1 bg-rose-50/70 rounded-xl">
            <button
              onClick={() => setMethod("upi")}
              className={`flex items-center justify-center gap-1.5 text-xs font-semibold py-2 rounded-lg transition ${
                method === "upi" ? "bg-white text-rose-600 shadow-sm" : "text-gray-500"
              }`}
            >
              <Smartphone size={14} /> UPI
            </button>
            <button
              onClick={() => setMethod("bank")}
              className={`flex items-center justify-center gap-1.5 text-xs font-semibold py-2 rounded-lg transition ${
                method === "bank" ? "bg-white text-rose-600 shadow-sm" : "text-gray-500"
              }`}
            >
              <Landmark size={14} /> Bank
            </button>
          </div>

          {method === "upi" ? (
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">UPI ID</label>
              <input
                value={upi} onChange={(e) => setUpi(e.target.value)}
                placeholder="name@bankupi"
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500"
              />
            </div>
          ) : (
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Account holder name</label>
                <input value={name} onChange={(e) => setName(e.target.value)}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">Account number</label>
                <input value={acct} onChange={(e) => setAcct(e.target.value)}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wide">IFSC</label>
                <input value={ifsc} onChange={(e) => setIfsc(e.target.value.toUpperCase())}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-pink-500" />
              </div>
            </div>
          )}
        </div>
        <div className="px-5 py-4 bg-gray-50 flex items-center justify-end gap-2">
          <button onClick={onClose}
            className="px-4 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 rounded-lg">
            Cancel
          </button>
          <button onClick={save} disabled={saving}
            className="inline-flex items-center gap-1.5 px-5 py-2 rounded-lg bg-gradient-to-r from-pink-500 to-rose-500 text-white text-sm font-semibold hover:from-pink-600 hover:to-rose-600 disabled:opacity-50">
            {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

// Payout request modal. Credits → INR conversion lives here only (we keep
// the main wallet page focused on buying). Shows saved payout destination
// up front and the exact amount the user will receive after the request
// is processed.
function WithdrawModal({ balance, payoutDetails, withdrawals, onChangeDetails, onClose, onDone, showToast }) {
  const [credits, setCredits] = useState(500);
  const [submitting, setSubmitting] = useState(false);
  const rate = balance?.withdrawal_rate_paise ?? 70;
  const inr = (credits * rate) / 100;
  const max = balance?.balance ?? 0;

  async function submit() {
    if (credits < 500) {
      showToast?.("Minimum 500 credits per request", "error");
      return;
    }
    if (credits > max) {
      showToast?.("Not enough credits", "error");
      return;
    }
    setSubmitting(true);
    try {
      await api.wallet.withdraw(credits);
      onDone();
    } catch (e) {
      showToast?.(e.message || "Could not submit request", "error");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/55 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl w-full max-w-md shadow-xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-pink-500 to-rose-500 text-white flex items-center justify-center">
              <ArrowUpCircle size={16} />
            </div>
            <h3 className="font-bold text-gray-900">Request payout</h3>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Payout destination */}
          <div className="flex items-center justify-between gap-3 bg-rose-50/60 rounded-xl px-3 py-2.5 border border-rose-100">
            <div className="flex items-center gap-2 min-w-0">
              {payoutDetails?.method === "upi"
                ? <Smartphone size={15} className="text-rose-500 flex-shrink-0" />
                : <Landmark size={15} className="text-rose-500 flex-shrink-0" />}
              <div className="min-w-0">
                <p className="text-[10px] uppercase tracking-wider text-gray-500 font-semibold">
                  Paying to {payoutDetails?.method === "bank" ? "bank" : "UPI"}
                </p>
                <p className="text-xs font-semibold text-gray-800 truncate">
                  {payoutDetails?.method === "upi"
                    ? payoutDetails?.upi_id
                    : `${payoutDetails?.account_name} · ••••${payoutDetails?.account_number_last4}`}
                </p>
              </div>
            </div>
            <button
              onClick={onChangeDetails}
              className="text-[11px] font-semibold text-rose-500 hover:text-rose-600 flex-shrink-0"
            >
              Change
            </button>
          </div>

          {/* Amount picker */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-[11px] font-semibold text-gray-500 uppercase tracking-wider">
                Credits to withdraw
              </label>
              <span className="text-[10px] text-gray-400">
                Available: <span className="font-semibold text-gray-700">{max.toLocaleString()}</span>
              </span>
            </div>
            <div className="flex items-center border border-gray-200 rounded-xl px-3 py-2.5 focus-within:ring-2 focus-within:ring-rose-400 focus-within:border-rose-300">
              <Coins size={16} className="text-rose-400 mr-2" />
              <input
                type="number"
                min={500}
                max={max || undefined}
                step={50}
                value={credits}
                onChange={(e) => setCredits(parseInt(e.target.value) || 0)}
                className="flex-1 outline-none text-base font-semibold text-gray-900"
              />
            </div>
            <p className="text-[11px] text-gray-400 mt-1.5">
              Minimum 500 credits per request.
            </p>
          </div>

          {/* Payout summary */}
          <div className="rounded-xl bg-gradient-to-br from-rose-50 to-pink-50 border border-rose-100 p-4">
            <div className="flex items-center justify-between">
              <span className="text-xs text-gray-600 font-medium">You'll receive</span>
              <span className="text-2xl font-black text-rose-600 tracking-tight">
                ₹{inr.toFixed(2)}
              </span>
            </div>
            <p className="text-[10px] text-gray-400 mt-1">
              Payouts are typically credited within 1–2 business days.
            </p>
          </div>

          {withdrawals.length > 0 && (
            <details className="text-xs">
              <summary className="cursor-pointer text-[11px] font-semibold text-gray-500 hover:text-gray-700">
                Recent requests ({withdrawals.length})
              </summary>
              <ul className="mt-2 space-y-1 max-h-40 overflow-y-auto">
                {withdrawals.slice(0, 10).map((w) => (
                  <li key={w.id} className="flex items-center justify-between py-1.5 border-b border-gray-50 last:border-0">
                    <span className="text-gray-600">{w.credits.toLocaleString()} credits</span>
                    <span className={`font-semibold px-2 py-0.5 rounded-full text-[10px] uppercase ${
                      w.status === "paid" ? "bg-emerald-100 text-emerald-700"
                      : w.status === "rejected" ? "bg-red-100 text-red-700"
                      : w.status === "processing" ? "bg-blue-100 text-blue-700"
                      : "bg-amber-100 text-amber-700"
                    }`}>
                      {w.status}
                    </span>
                  </li>
                ))}
              </ul>
            </details>
          )}
        </div>

        <div className="px-5 py-4 bg-gray-50 flex items-center justify-end gap-2">
          <button onClick={onClose}
            className="px-4 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 rounded-lg">
            Cancel
          </button>
          <button onClick={submit} disabled={submitting || credits < 500 || credits > max}
            className="inline-flex items-center gap-1.5 px-5 py-2 rounded-lg bg-gradient-to-r from-pink-500 to-rose-500 text-white text-sm font-semibold hover:from-pink-600 hover:to-rose-600 disabled:opacity-50">
            {submitting ? <Loader2 size={14} className="animate-spin" /> : <ArrowUpCircle size={14} />}
            Request payout
          </button>
        </div>
      </div>
    </div>
  );
}
