/**
 * CallOverlay — the full-screen UI above everything else while a call is
 * in flight. One component renders all four useCall states:
 *
 *   calling   → "Calling <name>…" with cancel
 *   ringing   → incoming modal with Accept/Decline + peer avatar
 *   connected → video tiles (or avatar-only for audio) + controls
 *   ended     → flashes briefly then self-dismisses via dismissEnded()
 *
 * The hook owns all the business logic. This file just paints state and
 * wires buttons back to hook actions. Keep it dumb.
 */
import { useEffect, useRef, useState } from "react";
import { Phone, PhoneOff, Video, VideoOff, Mic, MicOff, PhoneIncoming } from "lucide-react";

// Live ticker for the in-call duration badge. Format like 0:34 or 12:05
// or 1:03:22 — same shape WhatsApp uses, so users recognise it instantly.
function useCallTimer(startedAt) {
  // The timer state value itself isn't read — its mutation just forces
  // the host component to re-render once a second so `Date.now()` below
  // recomputes a fresh HH:MM:SS.
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!startedAt) return;
    const id = setInterval(() => setTick((t) => t + 1), 1000);
    return () => clearInterval(id);
  }, [startedAt]);
  if (!startedAt) return "";
  const secs = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  return h
    ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
    : `${m}:${String(s).padStart(2, "0")}`;
}

// Bind a MediaStream to a <video>/<audio> element imperatively. Setting
// srcObject directly (vs. URL.createObjectURL which is deprecated) is
// the modern, leak-free way. We re-bind whenever the stream identity
// changes — the hook reuses the same MediaStream across track adds so
// this fires rarely.
function useMediaElement(stream, ref) {
  useEffect(() => {
    if (!ref.current) return;
    ref.current.srcObject = stream || null;
  }, [stream, ref]);
}

export default function CallOverlay({ call }) {
  const {
    status, media, peer, startedAt, error, paywall,
    micMuted, camOff,
    localStream, remoteStream,
    acceptIncoming, declineIncoming, endCall,
    toggleMic, toggleCam, dismissEnded,
  } = call;

  const timerText = useCallTimer(startedAt);
  const localVideoRef  = useRef(null);
  const remoteVideoRef = useRef(null);
  const remoteAudioRef = useRef(null);

  useMediaElement(localStream,  localVideoRef);
  useMediaElement(remoteStream, media === "video" ? remoteVideoRef : remoteAudioRef);

  // Auto-dismiss the "call ended" flash after 1.8s so the overlay
  // disappears without the user clicking. If they hit the screen sooner
  // the dismissEnded call on the close button also works.
  useEffect(() => {
    if (status !== "ended") return;
    const id = setTimeout(() => dismissEnded(), 1800);
    return () => clearTimeout(id);
  }, [status, dismissEnded]);

  if (status === "idle") return null;

  // ── Incoming call: compact top banner, NOT fullscreen ────────────
  // When someone is ringing you, we don't want to take over the whole
  // screen — the user should be able to keep scrolling/reading while
  // deciding. Shows a small card at the top with avatar + name + two
  // big action buttons (green accept, red decline). Once accepted, the
  // hook transitions status → "connected" and we fall through to the
  // fullscreen in-call UI.
  if (status === "ringing") {
    const isVideo = media === "video";
    const avatarUrl = peer?.photo || peer?.main_image_url;
    return (
      <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[9999] w-[min(92vw,26rem)] pointer-events-auto">
        <div className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-gray-200 p-3 flex items-center gap-3">
          {/* Avatar w/ pulsing ring */}
          <div className="relative flex-shrink-0">
            {avatarUrl ? (
              <img
                src={avatarUrl}
                alt=""
                className="w-12 h-12 rounded-full object-cover"
              />
            ) : (
              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center text-lg font-bold text-white">
                {peer?.name?.[0]?.toUpperCase() || "?"}
              </div>
            )}
            <span className="absolute inset-0 rounded-full ring-2 ring-green-400/60 animate-ping" />
          </div>

          {/* Name + subtext */}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-gray-900 truncate">
              {peer?.name || "Unknown"}
            </p>
            <p className="text-xs text-gray-500 flex items-center gap-1">
              {isVideo ? (
                <Video className="w-3 h-3 text-pink-500" />
              ) : (
                <PhoneIncoming className="w-3 h-3 text-green-500" />
              )}
              Incoming {isVideo ? "video" : "voice"} call…
            </p>
          </div>

          {/* Decline */}
          <button
            onClick={declineIncoming}
            className="w-11 h-11 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center shadow-md transition flex-shrink-0"
            aria-label="Decline"
          >
            <PhoneOff className="w-5 h-5 text-white" />
          </button>

          {/* Accept */}
          <button
            onClick={acceptIncoming}
            className="w-11 h-11 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center shadow-md transition flex-shrink-0 animate-pulse"
            aria-label="Accept"
          >
            <Phone className="w-5 h-5 text-white" />
          </button>
        </div>
      </div>
    );
  }

  // ── End-of-call flash or paywall state ──────────────────────────
  if (status === "ended") {
    return (
      <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm">
        <div className="bg-white rounded-2xl p-6 max-w-sm mx-4 text-center shadow-2xl">
          {paywall ? (
            <>
              <div className="w-14 h-14 mx-auto mb-3 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-white text-2xl">⭐</div>
              <h3 className="text-lg font-bold text-gray-900 mb-1">Upgrade to Pro</h3>
              <p className="text-sm text-gray-600 mb-4">{paywall.message}</p>
              <button
                onClick={() => {
                  dismissEnded();
                  // Ask the dashboard to open the subscription modal
                  // pre-focused on the Pro tier.
                  window.dispatchEvent(new CustomEvent("paywall:open", {
                    detail: { kind: "calls", suggest: "pro" },
                  }));
                }}
                className="w-full py-2.5 rounded-xl bg-gradient-to-r from-amber-500 to-orange-600 text-white font-semibold"
              >
                See Pro plans
              </button>
              <button onClick={dismissEnded} className="mt-2 text-sm text-gray-500">Not now</button>
            </>
          ) : error ? (
            <>
              <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-red-100 flex items-center justify-center text-red-500 text-xl">⚠️</div>
              <p className="text-sm text-gray-700">{error}</p>
            </>
          ) : (
            <>
              <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 text-xl">📞</div>
              <p className="text-sm text-gray-600">Call ended</p>
            </>
          )}
        </div>
      </div>
    );
  }

  const isVideo = media === "video";
  const avatarUrl = peer?.photo || peer?.main_image_url;

  return (
    <div className="fixed inset-0 z-[9999] flex flex-col bg-gradient-to-br from-gray-900 via-gray-950 to-black text-white overflow-hidden">
      {/* Remote media fills the viewport on video; on audio we show a
          giant avatar instead. */}
      {isVideo ? (
        <video
          ref={remoteVideoRef}
          autoPlay playsInline
          className={`absolute inset-0 w-full h-full object-cover ${status === "connected" ? "opacity-100" : "opacity-0"}`}
        />
      ) : (
        <audio ref={remoteAudioRef} autoPlay playsInline className="hidden" />
      )}

      {/* Gradient veil so text/controls stay legible over any remote image */}
      <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-transparent to-black/80 pointer-events-none" />

      {/* Header — peer name + status/timer. At this point status is
          either "calling" (outgoing, ringing) or "connected" — the
          "ringing" state returned the compact banner above. */}
      <div className="relative z-10 pt-10 px-6 text-center">
        <p className="text-xs uppercase tracking-widest text-white/60">
          {status === "calling"   && "Calling…"}
          {status === "connected" && (isVideo ? "Video call" : "Voice call")}
        </p>
        <h2 className="text-3xl font-bold mt-1">{peer?.name || "Unknown"}</h2>
        {status === "connected" && (
          <p className="text-base text-white/70 mt-1 tabular-nums">{timerText}</p>
        )}
      </div>

      {/* Big centered avatar for calling / audio. Hidden during
          connected video calls so the remote feed shows full-bleed. */}
      {(!isVideo || status !== "connected") && (
        <div className="relative z-10 flex-1 flex items-center justify-center">
          <div className="relative">
            {avatarUrl ? (
              <img
                src={avatarUrl}
                alt=""
                className="w-44 h-44 md:w-52 md:h-52 rounded-full object-cover ring-4 ring-white/20 shadow-2xl"
              />
            ) : (
              <div className="w-44 h-44 md:w-52 md:h-52 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center text-6xl font-bold">
                {peer?.name?.[0]?.toUpperCase() || "?"}
              </div>
            )}
            {status === "calling" && (
              // Pulsing ring to signal "this is live" while we wait
              <div className="absolute inset-0 rounded-full ring-4 ring-white/30 animate-ping" />
            )}
          </div>
        </div>
      )}

      {/* Local self-view — PiP bottom-right during video calls */}
      {isVideo && status === "connected" && (
        <video
          ref={localVideoRef}
          autoPlay playsInline muted
          className="absolute bottom-28 right-4 w-28 h-40 md:w-36 md:h-48 rounded-xl object-cover ring-2 ring-white/30 shadow-2xl bg-black z-20"
        />
      )}

      {/* ── Control bar — calling or connected: mute/cam + hangup ── */}
      <div className="relative z-10 pb-10 px-6">
        <div className="flex items-center justify-center gap-5">
          <button
            onClick={toggleMic}
            className={`w-14 h-14 rounded-full flex items-center justify-center transition ${micMuted ? "bg-white text-gray-900" : "bg-white/10 hover:bg-white/20"}`}
            aria-label={micMuted ? "Unmute" : "Mute"}
          >
            {micMuted ? <MicOff className="w-6 h-6" /> : <Mic className="w-6 h-6" />}
          </button>

          {isVideo && (
            <button
              onClick={toggleCam}
              className={`w-14 h-14 rounded-full flex items-center justify-center transition ${camOff ? "bg-white text-gray-900" : "bg-white/10 hover:bg-white/20"}`}
              aria-label={camOff ? "Camera on" : "Camera off"}
            >
              {camOff ? <VideoOff className="w-6 h-6" /> : <Video className="w-6 h-6" />}
            </button>
          )}

          <button
            onClick={() => endCall({ reason: "hangup" })}
            className="w-16 h-16 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center shadow-lg transition"
            aria-label="Hang up"
          >
            <PhoneOff className="w-7 h-7" />
          </button>
        </div>
      </div>
    </div>
  );
}
