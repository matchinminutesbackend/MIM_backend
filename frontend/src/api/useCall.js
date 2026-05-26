/**
 * useCall — WebRTC 1:1 voice/video hook driven by our existing /ws/chat.
 *
 * Design
 * ──────
 * We do NOT own a WebSocket here. The parent (Dashboard) already has the
 * chat socket open and passes us a `sendSignal(payload)` callback plus
 * the stream of inbound `call_*` frames via `handleSignal(msg)`. This
 * means the hook is the only place touching RTCPeerConnection / media
 * streams, and the socket stays single-owner.
 *
 * State machine
 * ─────────────
 *   idle → calling  (outgoing, ringing)        → connected → ended
 *   idle → ringing  (incoming, user must ack)  → connected → ended
 *
 * All 4 states expose the peer (`{ id, name, photo }`), media type
 * (`audio|video`), timestamp of state entry, and a `callId` for
 * correlating signaling frames.
 *
 * Signaling protocol (client ↔ client, server just forwards):
 *   call_invite   — A → B: "I want to call you"
 *   call_accept   — B → A: "yes, go ahead and send offer"
 *   call_decline  — B → A: "no / busy"
 *   call_hangup   — either → either: "end the session"
 *   call_offer    — A → B: RTCSessionDescription(offer)
 *   call_answer   — B → A: RTCSessionDescription(answer)
 *   call_ice      — either → either: RTCIceCandidate
 *   call_error    — server → client: "you're not allowed to start this
 *                   call" (Pro gate). Hook surfaces it as a paywall.
 *
 * NAT traversal: we rely on public STUN only. Corporate / symmetric-NAT
 * users will fail to connect — adding a TURN server is a one-line env
 * change (ICE_SERVERS below) when we decide that failure rate matters.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "./client";

// Google's public STUN servers — free, reliable for most home networks.
// Swap / extend with TURN creds once we decide we need symmetric-NAT
// traversal.
const ICE_SERVERS = [
  { urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"] },
];

// Ring timeout — callers hang up automatically if the callee hasn't
// accepted within this many seconds. Matches WhatsApp's ~30s feel.
const RING_TIMEOUT_MS = 35_000;

// Cryptographically unique-ish call ids without a library. We never
// verify these server-side — they only correlate frames end-to-end.
function newCallId() {
  return (
    Date.now().toString(36) +
    "-" +
    Math.random().toString(36).slice(2, 10)
  );
}

export function useCall({ sendSignal }) {
  // ── Public state (read by the UI) ──────────────────────────────
  // status: 'idle' | 'calling' | 'ringing' | 'connected' | 'ended'
  const [status, setStatus]           = useState("idle");
  const [media, setMedia]             = useState(null); // 'audio' | 'video'
  const [peer, setPeer]               = useState(null); // { id, name, photo }
  const [matchId, setMatchId]         = useState(null);
  const [startedAt, setStartedAt]     = useState(null); // ms when `connected`
  const [paywall, setPaywall]         = useState(null); // { message, plans }
  const [error, setError]             = useState("");
  const [micMuted, setMicMuted]       = useState(false);
  const [camOff, setCamOff]           = useState(false);

  // Separate refs so we can always reach the raw objects in async
  // callbacks without stale-closure bugs.
  const pcRef         = useRef(null);    // RTCPeerConnection
  const localStream   = useRef(null);    // MediaStream (mic [+ cam])
  const remoteStream  = useRef(null);    // MediaStream assembled from tracks
  const callIdRef     = useRef(null);
  const pendingIce    = useRef([]);      // ICE queued before remoteDesc set
  const ringTimerRef  = useRef(null);
  const endedRef      = useRef(false);   // guards double-cleanup

  // ── Full teardown — always safe to call more than once ─────────
  const resetState = useCallback(() => {
    if (endedRef.current) return;
    endedRef.current = true;
    clearTimeout(ringTimerRef.current);

    try { pcRef.current?.getSenders()?.forEach((s) => s.track && s.track.stop()); } catch {}
    try { pcRef.current?.close(); } catch {}
    pcRef.current = null;

    localStream.current?.getTracks().forEach((t) => t.stop());
    localStream.current = null;
    remoteStream.current = null;
    pendingIce.current = [];
  }, []);

  // ── Outbound signaling sugar — attaches match + call id ────────
  const emit = useCallback((type, extra = {}) => {
    if (!sendSignal) return;
    sendSignal({
      type,
      match_id: matchId,
      call_id:  callIdRef.current,
      ...extra,
    });
  }, [matchId, sendSignal]);

  // ── Build the peer connection + wire events ────────────────────
  const buildPc = useCallback(() => {
    const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });

    // Fresh remote stream collects inbound tracks. Using a single
    // MediaStream keeps the <video>/<audio> element stable across
    // track adds (safer than swapping srcObject on each track).
    const remote = new MediaStream();
    remoteStream.current = remote;
    pc.ontrack = (ev) => {
      ev.streams?.[0]?.getTracks().forEach((t) => remote.addTrack(t));
      if (!ev.streams?.length) remote.addTrack(ev.track);
    };

    pc.onicecandidate = (ev) => {
      if (ev.candidate) emit("call_ice", { candidate: ev.candidate.toJSON() });
    };

    // Watch for drop-off. If the ICE side fails the call is toast —
    // trigger the same path as an explicit hangup so UI updates.
    pc.onconnectionstatechange = () => {
      const s = pc.connectionState;
      if (s === "failed" || s === "disconnected" || s === "closed") {
        endCall({ reason: "connection_lost", silent: true });
      }
    };

    pcRef.current = pc;
    return pc;
  }, [emit]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Media capture ──────────────────────────────────────────────
  const getLocalMedia = useCallback(async (wantsVideo) => {
    const constraints = {
      audio: true,
      video: wantsVideo ? { width: 640, height: 480, facingMode: "user" } : false,
    };
    const stream = await navigator.mediaDevices.getUserMedia(constraints);
    localStream.current = stream;
    return stream;
  }, []);

  // ── OUTBOUND CALL ──────────────────────────────────────────────
  const startCall = useCallback(async ({ matchId: mId, partner, media: m }) => {
    if (status !== "idle" && status !== "ended") return;
    endedRef.current = false;
    setError("");
    setPaywall(null);
    callIdRef.current = newCallId();
    setMatchId(mId);
    setPeer(partner);
    setMedia(m);
    setStatus("calling");

    // Send the ring frame *before* asking for camera permission — the
    // permission prompt can take seconds and we want the callee to see
    // the ring immediately.
    sendSignal({
      type:      "call_invite",
      match_id:  mId,
      call_id:   callIdRef.current,
      media:     m,
      // Caller card shown on the callee's ringing screen.
      caller:    { name: partner.self_name, photo: partner.self_photo },
    });

    // Auto-hangup if not picked up
    ringTimerRef.current = setTimeout(() => {
      // Log as missed on the caller's side too so their thread shows it.
      api.messages.logCall(mId, { media: m, missed: true }).catch(() => {});
      emit("call_hangup", { duration: 0, reason: "timeout" });
      resetState();
      setStatus("ended");
    }, RING_TIMEOUT_MS);

    // Pre-flight media permission so once the callee accepts we're ready.
    try {
      await getLocalMedia(m === "video");
    } catch (e) {
      // Mic/cam blocked — bail before any WebRTC state exists
      clearTimeout(ringTimerRef.current);
      emit("call_hangup", { duration: 0, reason: "permission_denied" });
      setError(e?.message || "Couldn't access microphone/camera");
      resetState();
      setStatus("ended");
    }
  }, [status, sendSignal, emit, getLocalMedia, resetState]);

  // ── INBOUND CALL (callee side) ─────────────────────────────────
  const acceptIncoming = useCallback(async () => {
    if (status !== "ringing") return;
    try {
      await getLocalMedia(media === "video");
    } catch (e) {
      emit("call_decline", { reason: "permission_denied" });
      api.messages.logCall(matchId, { media, missed: true }).catch(() => {});
      setError(e?.message || "Mic/camera blocked");
      resetState();
      setStatus("ended");
      return;
    }
    // Tell caller to send the SDP offer. We build the PC up front so
    // we're ready to handle it the moment it arrives.
    buildPc();
    localStream.current.getTracks().forEach((t) =>
      pcRef.current.addTrack(t, localStream.current)
    );
    emit("call_accept");
    // status stays "ringing" until offer/answer dance lands "connected".
  }, [status, media, matchId, emit, getLocalMedia, buildPc, resetState]);

  const declineIncoming = useCallback(() => {
    if (status !== "ringing") return;
    emit("call_decline", { reason: "declined" });
    // Log missed on our own thread (caller already logs theirs on timeout/decline).
    api.messages.logCall(matchId, { media, missed: true }).catch(() => {});
    resetState();
    setStatus("ended");
  }, [status, media, matchId, emit, resetState]);

  // ── Hang up (either side) ──────────────────────────────────────
  const endCall = useCallback(({ reason = "hangup", silent = false } = {}) => {
    if (status === "idle") return;
    const duration = startedAt ? Math.round((Date.now() - startedAt) / 1000) : 0;

    if (!silent) emit("call_hangup", { duration, reason });

    // Log one of two kinds of summary into the chat thread:
    //   • connected → a proper "📞 Voice call · 2m 15s" message
    //   • calling / ringing → a "📵 Missed call" (caller cancelled or
    //     callee is about to hang up on an uninvited ring).
    // Previously this branch only fired for `connected`, so if you
    // tapped cancel during the outgoing ring nothing showed in chat.
    if (matchId && media) {
      if (status === "connected") {
        api.messages.logCall(matchId, { media, durationSeconds: duration }).catch(() => {});
      } else if (status === "calling" || status === "ringing") {
        api.messages.logCall(matchId, { media, missed: true }).catch(() => {});
      }
    }

    resetState();
    setStatus("ended");
  }, [status, startedAt, matchId, media, emit, resetState]);

  // ── Inbound signaling frames (from chatSocket onCallSignal) ────
  const handleSignal = useCallback(async (msg) => {
    const { type, call_id, from_user_id } = msg;

    // 402 paywall surfaced by the server because the caller isn't Pro.
    // Only the caller ever receives this, so status === 'calling'.
    //
    // UX: hold the "Calling…" screen for ~1.8s before popping the
    // paywall. An instant upgrade prompt the moment you tap call feels
    // aggressive — this small delay makes the system look like it
    // genuinely tried to reach the other side before revealing the
    // gate. Reuses ringTimerRef so that if the user hits hang-up during
    // the wait (resetState clears the timer), the paywall never fires.
    if (type === "call_error" && msg.code === "calls_locked") {
      clearTimeout(ringTimerRef.current);
      const paywallPayload = {
        message: msg.detail || "Voice & video calls are a Pro feature.",
        kind:    "calls",
      };
      ringTimerRef.current = setTimeout(() => {
        resetState();
        setStatus("ended");
        setPaywall(paywallPayload);
      }, 1800);
      return;
    }

    // Ignore frames that belong to a different call (race on re-rings)
    if (callIdRef.current && call_id && callIdRef.current !== call_id) {
      // Exception: a brand-new invite while idle — that's OK, adopt it.
      if (type !== "call_invite") return;
    }

    switch (type) {
      case "call_invite": {
        // Reject if already busy in another call.
        if (status !== "idle" && status !== "ended") {
          sendSignal({
            type:     "call_decline",
            match_id: msg.match_id,
            call_id:  msg.call_id,
            reason:   "busy",
          });
          return;
        }
        endedRef.current = false;
        callIdRef.current = msg.call_id;
        setMatchId(msg.match_id);
        setPeer({
          id:    from_user_id,
          name:  msg.caller?.name  || "Someone",
          photo: msg.caller?.photo || null,
        });
        setMedia(msg.media === "video" ? "video" : "audio");
        setStatus("ringing");
        setError("");
        setPaywall(null);

        // Auto-miss if ignored
        ringTimerRef.current = setTimeout(() => {
          // Log missed from our side; caller logged theirs on timeout too.
          api.messages.logCall(msg.match_id, { media: msg.media, missed: true }).catch(() => {});
          sendSignal({
            type:     "call_decline",
            match_id: msg.match_id,
            call_id:  msg.call_id,
            reason:   "timeout",
          });
          resetState();
          setStatus("ended");
        }, RING_TIMEOUT_MS);
        break;
      }

      case "call_accept": {
        // Callee picked up — start the offer-answer dance. We (the
        // caller) build the PC now and send the offer.
        clearTimeout(ringTimerRef.current);
        if (!pcRef.current) buildPc();
        localStream.current?.getTracks().forEach((t) =>
          pcRef.current.addTrack(t, localStream.current)
        );
        const offer = await pcRef.current.createOffer();
        await pcRef.current.setLocalDescription(offer);
        emit("call_offer", { sdp: offer });
        break;
      }

      case "call_offer": {
        // We're the callee — apply the remote offer, answer back.
        if (!pcRef.current) return; // shouldn't happen; safety
        await pcRef.current.setRemoteDescription(new RTCSessionDescription(msg.sdp));
        // Flush any ICE that arrived before the remote desc landed.
        for (const c of pendingIce.current) {
          try { await pcRef.current.addIceCandidate(new RTCIceCandidate(c)); } catch {}
        }
        pendingIce.current = [];
        const answer = await pcRef.current.createAnswer();
        await pcRef.current.setLocalDescription(answer);
        emit("call_answer", { sdp: answer });
        setStartedAt(Date.now());
        setStatus("connected");
        break;
      }

      case "call_answer": {
        // Caller side — finalize with remote answer.
        if (!pcRef.current) return;
        await pcRef.current.setRemoteDescription(new RTCSessionDescription(msg.sdp));
        for (const c of pendingIce.current) {
          try { await pcRef.current.addIceCandidate(new RTCIceCandidate(c)); } catch {}
        }
        pendingIce.current = [];
        setStartedAt(Date.now());
        setStatus("connected");
        break;
      }

      case "call_ice": {
        if (!pcRef.current || !pcRef.current.remoteDescription) {
          pendingIce.current.push(msg.candidate);
          return;
        }
        try {
          await pcRef.current.addIceCandidate(new RTCIceCandidate(msg.candidate));
        } catch { /* ignore malformed candidates */ }
        break;
      }

      case "call_decline": {
        clearTimeout(ringTimerRef.current);
        // Partner declined our call — log missed on our side too so the
        // thread has a clear record.
        if (status === "calling" && matchId && media) {
          api.messages.logCall(matchId, { media, missed: true }).catch(() => {});
        }
        resetState();
        setStatus("ended");
        break;
      }

      case "call_hangup": {
        clearTimeout(ringTimerRef.current);
        // Partner hung up — if we weren't yet connected, it's a miss.
        if (status === "calling" && matchId && media) {
          api.messages.logCall(matchId, { media, missed: true }).catch(() => {});
        }
        resetState();
        setStatus("ended");
        break;
      }

      default: break;
    }
  }, [status, matchId, media, emit, buildPc, sendSignal, resetState]);

  // ── Local controls ─────────────────────────────────────────────
  // Mute/cam toggle uses React state as the source of truth — previously
  // we derived "next" from `tracks.every(t => t.enabled)` and then did
  // `t.enabled = !next ? true : false`, which always resolved to `true`
  // (so pressing mute did nothing). Flip off `micMuted` state and
  // reflect it into the track. `setMicMuted(prev => !prev)` avoids a
  // stale-closure bug if the button is mashed quickly.
  const toggleMic = useCallback(() => {
    setMicMuted((prev) => {
      const next = !prev;
      const tracks = localStream.current?.getAudioTracks() || [];
      tracks.forEach((t) => {
        t.enabled = !next; // muted == !enabled
      });
      return next;
    });
  }, []);

  const toggleCam = useCallback(() => {
    setCamOff((prev) => {
      const next = !prev;
      const tracks = localStream.current?.getVideoTracks() || [];
      if (!tracks.length) return prev; // no camera → no-op
      tracks.forEach((t) => {
        t.enabled = !next;
      });
      return next;
    });
  }, []);

  const dismissEnded = useCallback(() => {
    if (status === "ended") setStatus("idle");
    setError("");
    setPaywall(null);
    setStartedAt(null);
    setMatchId(null);
    setPeer(null);
    setMedia(null);
    callIdRef.current = null;
  }, [status]);

  // Make sure tracks die if the component unmounts mid-call.
  useEffect(() => () => resetState(), [resetState]);

  return {
    status, media, peer, matchId, startedAt, paywall, error,
    micMuted, camOff,
    localStream: localStream.current,
    remoteStream: remoteStream.current,
    startCall, acceptIncoming, declineIncoming, endCall,
    toggleMic, toggleCam, dismissEnded,
    handleSignal,
  };
}
