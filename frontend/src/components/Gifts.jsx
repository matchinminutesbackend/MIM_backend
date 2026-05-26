/**
 * Gift system UI — picker, received-gift animated overlay, and in-chat
 * gift card. Uses 3D-feel icons built from CSS perspective + framer-motion
 * transforms; an optional Lottie animation layer is picked up automatically
 * if a matching JSON exists under `/public/lottie/<slug>.json` so product
 * can drop premium animations later without touching this file.
 *
 * Gift economics (server-enforced — we just show them):
 *   • Sender pays full cost
 *   • Chat-context: receiver instantly gets 70% credited
 *   • Invite-context: held until accept (→ 70%) / decline (→ 50% refund)
 */
import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Gift, Loader2, Sparkles, Coins, X, Check, WalletCards, ArrowRight } from "lucide-react";
import Lottie from "lottie-react";
import { api } from "../api/client";


// ── Tier visual language ─────────────────────────────────────────
// One consistent gradient per tier so the receiver overlay and the chat
// gift card feel like the same visual system.
const TIER_STYLE = {
  common:    { ring: "ring-pink-300",   bg: "from-rose-100 to-pink-100",      chip: "bg-rose-100 text-rose-700",       glow: "shadow-rose-200" },
  rare:      { ring: "ring-fuchsia-300",bg: "from-fuchsia-100 to-purple-100", chip: "bg-fuchsia-100 text-fuchsia-700", glow: "shadow-fuchsia-200" },
  epic:      { ring: "ring-amber-300",  bg: "from-amber-100 to-orange-100",   chip: "bg-amber-100 text-amber-700",     glow: "shadow-amber-200" },
  legendary: { ring: "ring-sky-300",    bg: "from-cyan-100 to-sky-100",       chip: "bg-sky-100 text-sky-700",         glow: "shadow-sky-200" },
};

function tier(t) { return TIER_STYLE[t] || TIER_STYLE.common; }


// ── 3D animated icon ─────────────────────────────────────────────
// Default renderer: the gift's emoji, styled big with perspective +
// continuous gentle float/rotate + inner glow. Looks 3D without WebGL.
// If a Lottie JSON lives at /lottie/<slug>.json we swap it in instead.
function GiftIcon3D({ gift, size = 96, autoplay = true, speed = 1 }) {
  const [lottieData, setLottieData] = useState(null);
  const [lottieTried, setLottieTried] = useState(false);

  useEffect(() => {
    // Look up bundled Lottie JSON once per slug. A 404 is expected and
    // fine — we fall back to the emoji renderer.
    let cancelled = false;
    fetch(`/lottie/${gift.slug}.json`, { cache: "force-cache" })
      .then(r => (r.ok ? r.json() : null))
      .then(json => { if (!cancelled && json) setLottieData(json); })
      .catch(() => {})
      .finally(() => { if (!cancelled) setLottieTried(true); });
    return () => { cancelled = true; };
  }, [gift.slug]);

  if (lottieData) {
    return (
      <div style={{ width: size, height: size }} className="select-none">
        <Lottie
          animationData={lottieData}
          loop={autoplay}
          autoplay={autoplay}
          // Lottie respects speed via setSpeed internally; leave default.
          style={{ width: size, height: size }}
        />
      </div>
    );
  }

  // Emoji 3D fallback — perspective wrapper + continuous float/spin gives
  // a tactile depth. `scale` + `rotateY` creates the turning feel, drop
  // shadow adds lift.
  const fontSize = Math.round(size * 0.72);
  return (
    <div
      className="relative flex items-center justify-center select-none"
      style={{ width: size, height: size, perspective: 600 }}
      aria-hidden="true"
    >
      {/* Soft halo behind the icon */}
      <div
        className="absolute inset-2 rounded-full blur-2xl opacity-60 pointer-events-none"
        style={{
          background:
            "radial-gradient(circle at 40% 35%, rgba(255,255,255,0.9), rgba(255,192,203,0.35) 60%, transparent 75%)",
        }}
      />
      <motion.div
        initial={{ scale: 0.9, rotateY: -15, y: 4 }}
        animate={
          autoplay
            ? {
                scale: [0.95, 1.02, 0.97, 1.02, 0.95],
                rotateY: [-12, 12, -12],
                y: [3, -3, 3],
              }
            : { scale: 1 }
        }
        transition={{
          duration: 4 / Math.max(0.1, speed),
          repeat: autoplay ? Infinity : 0,
          ease: "easeInOut",
        }}
        style={{
          fontSize,
          lineHeight: 1,
          filter:
            "drop-shadow(0 10px 18px rgba(225,29,72,0.22)) drop-shadow(0 3px 6px rgba(0,0,0,0.18))",
          transformStyle: "preserve-3d",
        }}
      >
        {gift.icon || "🎁"}
      </motion.div>
      {lottieTried && !lottieData && (
        // Subtle sparkle pops — visual cue that the icon is animated,
        // even without a Lottie asset. Purely decorative.
        <motion.span
          className="absolute -top-1 right-3 text-amber-300"
          initial={{ opacity: 0, scale: 0.4 }}
          animate={{ opacity: [0, 1, 0], scale: [0.5, 1, 0.6] }}
          transition={{ duration: 1.8, repeat: Infinity, delay: 0.4 }}
        >
          ✦
        </motion.span>
      )}
    </div>
  );
}


// ── Gift picker (modal) ──────────────────────────────────────────
// Used both from the invite flow and the chat composer. Caller passes
// `context` ("invite" | "chat"), the picker handles:
//   – loading the catalog
//   – balance gating (disabling items the sender can't afford)
//   – calling the right send endpoint
// onSent(result) bubbles the server response up so the caller can
// update their local UI (close modal, append gift row, etc).
export function GiftPickerModal({
  open,
  onClose,
  context,             // "invite" | "chat"
  receiverId,
  receiverName = "them",
  matchId = null,
  onSent,
  showToast,
}) {
  const [loading, setLoading]   = useState(true);
  const [catalog, setCatalog]   = useState([]);
  const [balance, setBalance]   = useState(null);
  const [lowBalModal, setLowBalModal] = useState(false);
  const [selected, setSelected] = useState(null);
  const [sending, setSending]   = useState(false);

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    setSelected(null);
    Promise.all([
      api.gifts.catalog().catch(() => []),
      api.wallet.balance().catch(() => ({ balance: 0 })),
    ]).then(([cat, bal]) => {
      setCatalog(cat);
      setBalance(bal);
      setLoading(false);
    });
  }, [open]);

  async function handleSend() {
    if (!selected) return;
    setSending(true);
    try {
      if (context === "invite") {
        // In invite context we don't call /gifts/send directly — the
        // gift is attached to the reinvite call, which creates the
        // pending gift_send server-side.
        const res = await api.matches.reinvite(receiverId, selected.slug);
        showToast?.(`Invite sent with ${selected.name} 🎁`);
        onSent?.({ context, gift: selected, reinvite: res });
      } else {
        const res = await api.gifts.send({
          receiverId,
          giftSlug: selected.slug,
          context: "chat",
          matchId,
        });
        showToast?.(`Sent ${selected.name} ${selected.icon || "🎁"}`);
        onSent?.({ context, gift: selected, server: res });
      }
      onClose?.();
    } catch (e) {
      const msg = (e.message || "").toLowerCase();
      if (
        e.status === 402 ||
        msg.includes("insufficient") ||
        msg.includes("low balance") ||
        msg.includes("not enough") ||
        msg.includes("credit")
      ) {
        setLowBalModal(true);
      } else {
        showToast?.(e.message || "Couldn't send gift", "error");
      }
    } finally {
      setSending(false);
    }
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[60] bg-black/55 backdrop-blur-sm flex items-end sm:items-center justify-center p-3 sm:p-6" onClick={onClose}>
      <motion.div
        onClick={(e) => e.stopPropagation()}
        initial={{ y: 40, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        className="w-full max-w-xl bg-white rounded-t-3xl sm:rounded-3xl shadow-2xl overflow-hidden"
      >
        {/* Header */}
        <div className="relative p-5 bg-gradient-to-br from-rose-500 via-pink-500 to-fuchsia-500 text-white">
          <button
            onClick={onClose}
            aria-label="Close"
            className="absolute top-3 right-3 w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white"
          >
            <X size={16} />
          </button>
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-white/20 grid place-items-center">
              <Gift size={22} />
            </div>
            <div>
              <h3 className="font-bold text-lg leading-tight">Send a gift</h3>
              <p className="text-xs text-white/85 mt-0.5">
                {context === "invite"
                  ? `Attach a gift to your invite to ${receiverName}.`
                  : `Surprise ${receiverName} right in the chat.`}
              </p>
            </div>
          </div>
          <div className="mt-3 inline-flex items-center gap-1.5 text-xs font-semibold bg-white/15 rounded-full px-2.5 py-1 border border-white/20 backdrop-blur">
            <Coins size={12} className="text-amber-200" />
            Balance: <span className="text-amber-100">{(balance?.balance ?? 0).toLocaleString()}</span> credits
          </div>
        </div>

        {/* Body */}
        <div className="p-4 sm:p-5 bg-gradient-to-b from-rose-50/50 to-white">
          {loading ? (
            <div className="py-12 flex items-center justify-center">
              <Loader2 className="animate-spin text-rose-500" size={22} />
            </div>
          ) : catalog.length === 0 ? (
            <p className="text-center text-sm text-gray-500 py-10">
              Gift catalog unavailable right now. Please try again later.
            </p>
          ) : (
            <>
              <div className="grid grid-cols-3 sm:grid-cols-3 gap-3">
                {catalog.map((g) => {
                  const afford = (balance?.balance ?? 0) >= g.cost;
                  const isSel = selected?.slug === g.slug;
                  const st = tier(g.tier);
                  return (
                    <button
                      key={g.slug}
                      onClick={() => afford && setSelected(g)}
                      disabled={!afford}
                      className={`relative rounded-2xl p-3 text-center transition group bg-gradient-to-b ${st.bg} ${
                        isSel
                          ? `ring-2 ${st.ring} shadow-lg ${st.glow}`
                          : "ring-1 ring-transparent hover:ring-gray-200"
                      } ${!afford ? "opacity-45 grayscale cursor-not-allowed" : "hover:-translate-y-0.5"}`}
                    >
                      {isSel && (
                        <span className="absolute top-1.5 right-1.5 w-5 h-5 rounded-full bg-rose-500 text-white grid place-items-center shadow">
                          <Check size={12} />
                        </span>
                      )}
                      <div className="mx-auto">
                        <GiftIcon3D gift={g} size={72} autoplay={isSel} />
                      </div>
                      <div className="mt-1.5 font-bold text-sm text-gray-900">{g.name}</div>
                      <div className={`inline-flex items-center gap-1 mt-1 text-[11px] font-bold px-2 py-0.5 rounded-full ${st.chip}`}>
                        <Coins size={10} />
                        {g.cost}
                      </div>
                    </button>
                  );
                })}
              </div>

              {selected && context === "invite" && (
                <p className="mt-4 text-[11px] text-gray-500 leading-snug">
                  If {receiverName} declines, 50% of the gift cost is refunded to you —
                  the rest is kept by the platform.
                </p>
              )}

              <div className="mt-4 flex items-center justify-between gap-3">
                <div className="text-xs text-gray-500">
                  {selected
                    ? <>Sending <span className="font-semibold text-gray-900">{selected.name}</span> {selected.icon} costs <span className="font-semibold text-rose-600">{selected.cost}</span> credits.</>
                    : "Pick a gift to continue."}
                </div>
                <button
                  onClick={handleSend}
                  disabled={!selected || sending || (balance?.balance ?? 0) < (selected?.cost ?? 0)}
                  className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-gradient-to-br from-rose-500 to-pink-500 text-white text-sm font-bold shadow hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  {sending ? <Loader2 size={15} className="animate-spin" /> : <Sparkles size={15} />}
                  {context === "invite" ? "Send invite + gift" : "Send gift"}
                </button>
              </div>
            </>
          )}
        </div>
      </motion.div>

      {/* Low balance professional modal */}
      <AnimatePresence>
        {lowBalModal && (
          <LowBalanceModal
            needed={selected?.cost ?? 0}
            have={balance?.balance ?? 0}
            onClose={() => setLowBalModal(false)}
            onBuy={() => {
              setLowBalModal(false);
              onClose?.();
              // Navigate to wallet tab, then scroll to buy-credits
              window.dispatchEvent(new CustomEvent("dashboard:go", { detail: "wallet" }));
              setTimeout(() => {
                const el = document.getElementById("buy-credits");
                if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
              }, 350);
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

// ── Low balance modal ────────────────────────────────────────────
function LowBalanceModal({ needed, have, onClose, onBuy }) {
  const deficit = Math.max(0, needed - have);
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[70] bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center p-4"
      onClick={onClose}
    >
      <motion.div
        initial={{ y: 60, opacity: 0, scale: 0.97 }}
        animate={{ y: 0, opacity: 1, scale: 1 }}
        exit={{ y: 40, opacity: 0 }}
        transition={{ type: "spring", damping: 22, stiffness: 260 }}
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-sm bg-white rounded-3xl shadow-2xl overflow-hidden"
      >
        {/* Top gradient bar */}
        <div className="h-1.5 w-full bg-gradient-to-r from-amber-400 via-rose-500 to-fuchsia-500" />

        <div className="p-7">
          {/* Icon */}
          <div className="mx-auto w-16 h-16 rounded-2xl bg-amber-50 border border-amber-100 flex items-center justify-center mb-5">
            <WalletCards size={30} className="text-amber-500" />
          </div>

          <h2 className="text-center text-xl font-bold text-gray-900 mb-2">
            Not Enough Credits
          </h2>
          <p className="text-center text-sm text-gray-500 leading-relaxed mb-5">
            This gift costs{" "}
            <span className="font-semibold text-rose-600">{needed} credits</span>. You
            have <span className="font-semibold text-gray-700">{have}</span> — top up{" "}
            <span className="font-semibold text-amber-600">{deficit} more</span> to
            send it.
          </p>

          {/* Balance bar */}
          <div className="mb-6">
            <div className="flex justify-between text-xs text-gray-400 mb-1.5">
              <span>Your balance</span>
              <span>{have} / {needed}</span>
            </div>
            <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-amber-400 to-rose-500 rounded-full transition-all"
                style={{ width: `${Math.min(100, (have / needed) * 100)}%` }}
              />
            </div>
          </div>

          {/* CTA */}
          <button
            onClick={onBuy}
            className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl bg-gradient-to-r from-amber-500 to-rose-500 text-white font-bold text-base shadow-lg shadow-rose-200 hover:shadow-rose-300 hover:-translate-y-0.5 transition-all"
          >
            <Coins size={18} />
            Buy Credits
            <ArrowRight size={16} />
          </button>

          <button
            onClick={onClose}
            className="w-full mt-3 py-2.5 text-sm text-gray-400 hover:text-gray-600 transition-colors"
          >
            Maybe later
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
}

// ── Received-gift overlay ────────────────────────────────────────
// Big animated reveal the receiver sees when a chat-context gift lands
// on their screen. Dismisses on click or after a short timeout so it
// doesn't block the chat. The persistent chat history card (`GiftChatCard`)
// remains visible afterwards.
export function GiftReceivedOverlay({ gift, from, onClose }) {
  // Auto-dismiss after ~3.5s so the overlay feels like a flourish, not
  // a modal the user has to manage.
  useEffect(() => {
    if (!gift) return;
    const t = setTimeout(() => onClose?.(), 3500);
    return () => clearTimeout(t);
  }, [gift, onClose]);

  return (
    <AnimatePresence>
      {gift && (
        <motion.div
          key={gift.slug + "-" + (gift._ts || "")}
          className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm cursor-pointer"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={() => onClose?.()}
        >
          {/* Confetti-ish floating sparkles */}
          {Array.from({ length: 10 }).map((_, i) => (
            <motion.span
              key={i}
              className="absolute text-amber-300 text-2xl select-none"
              initial={{ opacity: 0, x: 0, y: 0, scale: 0.4 }}
              animate={{
                opacity: [0, 1, 0],
                x: (i % 2 ? 1 : -1) * (60 + i * 18),
                y: -120 - i * 12,
                scale: [0.5, 1.2, 0.5],
                rotate: i * 40,
              }}
              transition={{ duration: 2.2, delay: i * 0.05, ease: "easeOut" }}
              style={{ top: "50%", left: "50%" }}
            >
              ✦
            </motion.span>
          ))}

          <motion.div
            initial={{ scale: 0.5, rotate: -10, opacity: 0 }}
            animate={{ scale: 1, rotate: 0, opacity: 1 }}
            exit={{ scale: 0.7, opacity: 0 }}
            transition={{ type: "spring", stiffness: 240, damping: 18 }}
            className="relative text-center"
          >
            <div className="mx-auto w-56 h-56">
              <GiftIcon3D gift={gift} size={224} autoplay speed={1.3} />
            </div>
            <div className="mt-3">
              <div className="text-xs uppercase tracking-[0.25em] text-white/80 font-semibold">
                {from ? `${from} sent you` : "You received"}
              </div>
              <div className="mt-1.5 text-3xl font-black text-white drop-shadow">
                {gift.name} {gift.icon}
              </div>
              {gift.receiver_share != null && (
                <div className="mt-2 inline-flex items-center gap-1.5 text-sm font-semibold bg-white/15 text-white border border-white/20 backdrop-blur rounded-full px-3 py-1">
                  <Coins size={13} className="text-amber-200" />
                  +{gift.receiver_share} credits added to your wallet
                </div>
              )}
              <div className="mt-3 text-[11px] text-white/60">Tap anywhere to dismiss</div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}


// ── Persistent in-chat gift card ─────────────────────────────────
// Replaces the plain text bubble when a message has `gift_send_id` /
// `gift`. Highlighted with the tier gradient so it stands out from
// normal chat bubbles.
export function GiftChatCard({ gift, cost, isMine }) {
  const st = tier(gift?.tier || "common");
  return (
    <div
      className={`relative overflow-hidden rounded-2xl p-3 sm:p-4 bg-gradient-to-br ${st.bg} ${st.ring} ring-2 shadow-sm ${isMine ? "ml-auto" : ""}`}
      style={{ maxWidth: 280 }}
    >
      <div className="flex items-center gap-3">
        <div className="shrink-0">
          <GiftIcon3D gift={gift} size={60} autoplay />
        </div>
        <div className="min-w-0">
          <div className="text-[10px] uppercase tracking-wider font-semibold text-gray-500">
            {isMine ? "You sent" : "You received"}
          </div>
          <div className="font-bold text-gray-900 leading-tight truncate">
            {gift?.name} {gift?.icon}
          </div>
          <div className={`inline-flex items-center gap-1 mt-1 text-[11px] font-bold px-2 py-0.5 rounded-full ${st.chip}`}>
            <Coins size={10} />
            {cost ?? gift?.cost ?? "—"}
          </div>
        </div>
      </div>
    </div>
  );
}


// ── Tiny button for composer bars ────────────────────────────────
export function GiftButton({ onClick, label = "Gift", className = "" }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-600 text-sm font-semibold border border-rose-200 transition ${className}`}
      title="Send a gift"
    >
      <Gift size={15} />
      <span className="hidden sm:inline">{label}</span>
    </button>
  );
}


export default GiftPickerModal;
