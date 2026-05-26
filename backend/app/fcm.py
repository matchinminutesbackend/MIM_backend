"""
Firebase Cloud Messaging helper.

Sends out-of-app push notifications to users who are not currently connected
via WebSocket (i.e. the app is in the background or closed).

Setup:
  1. Go to Firebase Console → Project Settings → Service Accounts.
  2. Click "Generate new private key" → save the JSON file.
  3. Set the environment variable:
       FIREBASE_SERVICE_ACCOUNT_JSON=/path/to/serviceAccountKey.json
     OR paste the entire JSON into:
       FIREBASE_SERVICE_ACCOUNT_JSON_CONTENT={"type":"service_account",...}
  4. Add `fcm_token` column to the profiles table:
       alter table profiles add column if not exists fcm_token text;

The module gracefully no-ops when Firebase credentials are not configured.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Optional

log = logging.getLogger("fcm")

_app = None  # firebase_admin App singleton


def _get_app():
    global _app
    if _app is not None:
        return _app
    try:
        import firebase_admin  # type: ignore
        from firebase_admin import credentials  # type: ignore

        # Option 1: explicit path via env var
        sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        # Option 2: JSON content itself (useful for secrets managers / env vars)
        sa_content = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_CONTENT")
        # Option 3: default location — backend/firebase-service-account.json
        default_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)),  # backend/
            "firebase-service-account.json",
        )

        if sa_path and os.path.isfile(sa_path):
            cred = credentials.Certificate(sa_path)
        elif sa_content:
            cred = credentials.Certificate(json.loads(sa_content))
        elif os.path.isfile(default_path):
            cred = credentials.Certificate(default_path)
        else:
            log.debug("FCM: no Firebase credentials configured — push disabled")
            return None

        _app = firebase_admin.initialize_app(cred)
        log.info("FCM: Firebase Admin SDK initialised")
        return _app
    except Exception as e:
        log.warning("FCM: init failed (%s) — push disabled", e)
        return None


def _get_token(user_id: str) -> Optional[str]:
    """Look up the stored FCM token for the user."""
    try:
        from app.supabase_client import supabase_admin
        res = (
            supabase_admin.table("profiles")
            .select("fcm_token")
            .eq("id", user_id)
            .single()
            .execute()
        )
        return (res.data or {}).get("fcm_token")
    except Exception:
        return None


def send_push(
    user_id: str,
    *,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> None:
    """Send a push notification to *user_id*'s device.

    Silently no-ops if:
    - Firebase Admin SDK is not initialised (credentials not set up).
    - The user has no registered FCM token.
    - Sending fails for any reason.

    This is always best-effort — the caller must never block on this.
    """
    try:
        app = _get_app()
        if app is None:
            return

        token = _get_token(user_id)
        if not token:
            return

        from firebase_admin import messaging  # type: ignore

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="mim_high_importance",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
            token=token,
        )
        messaging.send(message, app=app)
    except Exception as e:
        log.debug("FCM send_push failed for %s: %s", user_id, e)
