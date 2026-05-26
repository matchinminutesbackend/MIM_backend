import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/notifications/notifications_screen.dart';
import 'api_service.dart';
import 'navigation_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService._showFcmNotification(message);
}

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localReady = false;
  static int _badgeCount = 0;

  /// Call when the user opens the notifications screen or clears all alerts.
  static Future<void> clearBadge() async {
    _badgeCount = 0;
    try { await FlutterAppBadger.removeBadge(); } catch (_) {}
  }

  static const _androidChannel = AndroidNotificationChannel(
    'mim_high_importance',
    'MatchInMinutes Notifications',
    description: 'Messages, matches and activity alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialise local notifications (always) + Firebase (best-effort).
  /// Call once from [main] before [runApp].
  static Future<void> init() async {
    // ── Step 1: Local notifications — no Firebase needed ─────────────────────
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _localReady = true;

    // Request POST_NOTIFICATIONS permission on Android 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ── Step 2: Firebase — graceful fail if not configured ───────────────────
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[FCM] Firebase init skipped: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show local notification for FCM messages that arrive while app is open.
    FirebaseMessaging.onMessage.listen(_showFcmNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleNotificationTap(msg.data);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial.data);
    }
  }

  /// Register the FCM device token with the backend.
  /// Call after the user has logged in.
  static Future<void> registerToken() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      debugPrint('[FCM] token: $token');
      await ApiService.registerFcmToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        ApiService.registerFcmToken(t).catchError((_) {});
      });
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  /// Show a notification triggered by a WebSocket message (no FCM needed).
  /// Safe to call from any isolate once [init] has run.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    if (!_localReady || body.trim().isEmpty) return;
    _badgeCount++;
    try { await FlutterAppBadger.updateBadgeCount(_badgeCount); } catch (_) {}
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<void> _showFcmNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] as String? ?? 'MatchInMinutes';
    final body  = notification?.body  ?? data['body']  as String? ?? '';
    if (body.isEmpty) return;
    await showLocalNotification(
      title: title,
      body: body,
      payload: data.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNotificationTap(data);
    } catch (_) {}
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[FCM] notification tapped: $data');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx == null) return;
      Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    });
  }
}
