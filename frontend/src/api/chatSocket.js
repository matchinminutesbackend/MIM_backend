import { useEffect, useRef, useCallback } from "react";
import { WS_URL } from "./client";

/**
 * Persistent WebSocket for real-time chat events.
 *
 * Usage:
 *   useChatSocket({
 *     token,                       // JWT access token
 *     onNewMessage:   (evt) => ...  // { match_id, message }
 *     onMessagesRead: (evt) => ...  // { match_id, reader_id }
 *     onTyping:       (evt) => ...  // { match_id, user_id }
 *     onMatchCreated: (evt) => ...  // { match_id, partner }
 *     onMatchRemoved: (evt) => ...  // { match_id, removed_by, partner_id }
 *   });
 *
 * Returns:
 *   { send, sendTyping }
 *
 * Reconnects with exponential backoff on drop. Sends ping every 25 s.
 */
export function useChatSocket({
  token,
  onNewMessage,
  onMessagesRead,
  onMessagesDelivered,   // ({ match_id, message_ids }) => void
  onTyping,
  onMatchCreated,
  onMatchRemoved,
  onNotification,
  onUserStatus,          // ({ user_id, online, last_seen? }) => void
  onCallSignal,          // (msg) => void — fires for every call_* frame
} = {}) {
  const wsRef     = useRef(null);
  const pingRef   = useRef(null);
  const retryRef  = useRef(0);
  const reconnectRef = useRef(null);
  const closedRef = useRef(false);

  // Keep latest handlers in refs so we don't tear the socket down on re-renders
  const handlers = useRef({});
  handlers.current = { onNewMessage, onMessagesRead, onMessagesDelivered, onTyping, onMatchCreated, onMatchRemoved, onNotification, onUserStatus, onCallSignal };

  const connect = useCallback(() => {
    if (!token) return;
    closedRef.current = false;

    let ws;
    try {
      ws = new WebSocket(`${WS_URL}/ws/chat?token=${encodeURIComponent(token)}`);
    } catch (e) {
      console.warn("[chat-ws] construct failed", e);
      scheduleReconnect();
      return;
    }
    wsRef.current = ws;

    ws.onopen = () => {
      retryRef.current = 0;
      clearInterval(pingRef.current);
      pingRef.current = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "ping" }));
        }
      }, 25_000);
    };

    ws.onmessage = (ev) => {
      let msg;
      try { msg = JSON.parse(ev.data); }
      catch { return; }

      const h = handlers.current;
      switch (msg.type) {
        case "new_message":         h.onNewMessage?.(msg);          break;
        case "messages_read":       h.onMessagesRead?.(msg);        break;
        case "messages_delivered":  h.onMessagesDelivered?.(msg);   break;
        case "typing":              h.onTyping?.(msg);              break;
        case "match_created":       h.onMatchCreated?.(msg);        break;
        case "match_removed":       h.onMatchRemoved?.(msg);        break;
        case "notification":        h.onNotification?.(msg);        break;
        case "user_status":         h.onUserStatus?.(msg);          break;
        // WebRTC signaling — all call_* frames go through a single
        // handler. The useCall hook decides what to do based on type.
        case "call_invite":
        case "call_accept":
        case "call_decline":
        case "call_hangup":
        case "call_offer":
        case "call_answer":
        case "call_ice":
        case "call_error":     h.onCallSignal?.(msg);    break;
        case "connected":
        case "pong":
        case "error":
        default: break;
      }
    };

    ws.onclose = (ev) => {
      clearInterval(pingRef.current);
      if (closedRef.current) return;
      if (ev.code === 4401) return;
      scheduleReconnect();
    };

    ws.onerror = () => { /* onclose will handle cleanup */ };
  }, [token]);

  const scheduleReconnect = useCallback(() => {
    clearTimeout(reconnectRef.current);
    const attempt = Math.min(retryRef.current + 1, 6);
    retryRef.current = attempt;
    const delay = Math.min(1000 * 2 ** (attempt - 1), 15_000);
    reconnectRef.current = setTimeout(() => connect(), delay);
  }, [connect]);

  useEffect(() => {
    connect();
    return () => {
      closedRef.current = true;
      clearInterval(pingRef.current);
      clearTimeout(reconnectRef.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [connect]);

  const send = useCallback((payload) => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(payload));
    }
  }, []);

  const sendTyping = useCallback((matchId) => {
    send({ type: "typing", match_id: matchId });
  }, [send]);

  return { send, sendTyping };
}
