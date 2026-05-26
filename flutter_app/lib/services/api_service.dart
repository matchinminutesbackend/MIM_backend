import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException({required this.message, this.statusCode, this.code});

  @override
  String toString() => message;
}

class BannedException implements Exception {
  final String message;
  final String? expiresAt;
  BannedException({required this.message, this.expiresAt});

  DateTime? get expiresAtDateTime {
    if (expiresAt == null) return null;
    try { return DateTime.parse(expiresAt!).toUtc(); } catch (_) { return null; }
  }

  @override
  String toString() => message;
}

class ApiService {
  static final _client = http.Client();

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await StorageService.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode == 401) {
      await StorageService.clearAll();
      throw ApiException(message: 'Session expired. Please log in again.', statusCode: 401);
    }
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final detail = body['detail'];
    String msg = 'An error occurred';
    String? code;
    String? banExpiresAt;
    if (detail is String) {
      msg = detail;
    } else if (detail is Map) {
      msg = detail['message']?.toString() ?? msg;
      code = detail['code']?.toString();
      banExpiresAt = detail['ban_expires_at']?.toString();
    }
    if (code == 'account_banned') {
      throw BannedException(message: msg, expiresAt: banExpiresAt);
    }
    throw ApiException(message: msg, statusCode: res.statusCode, code: code);
  }

  // ─── AUTH ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
      }),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> googleAuth(String idToken) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/google'),
      headers: await _headers(auth: false),
      body: jsonEncode({'id_token': idToken}),
    );
    return await _handle(res);
  }

  static Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: await _headers(),
      );
    } catch (_) {}
  }

  // ─── FCM TOKEN ───────────────────────────────────────────────────────────────

  /// Register (or refresh) the device's FCM push token with the backend so
  /// the server can send out-of-app push notifications for messages and other
  /// events. Safe to call multiple times — backend upserts the token.
  static Future<void> registerFcmToken(String token) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/profile/fcm-token'),
        headers: await _headers(),
        body: jsonEncode({'token': token}),
      );
    } catch (_) {
      // Non-fatal — push notifications simply won't arrive until next token
      // registration succeeds.
    }
  }

  // ─── PROFILE ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMyProfile() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/me'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getProfileById(String userId) async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/$userId'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> completeProfile(Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/profile/complete'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/profile/me'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return await _handle(res);
  }

  // ─── IMAGES ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadImage(File file, {bool isMain = false}) async {
    final token = await StorageService.getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/images/upload?is_main=$isMain'),
    );
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    
    final path = file.path.toLowerCase();
    MediaType contentType = MediaType('image', 'jpeg');
    if (path.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (path.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    }

    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: contentType,
    ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> uploadImageBytes(
      Uint8List bytes, String filename, {bool isMain = false}) async {
    final token = await StorageService.getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/images/upload?is_main=$isMain'),
    );
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes(
      'file', bytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> uploadVerificationSelfie(File file) async {
    final token = await StorageService.getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/images/verification'),
    );
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final path = file.path.toLowerCase();
    MediaType contentType = MediaType('image', 'jpeg');
    if (path.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (path.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    }

    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: contentType,
    ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return await _handle(res);
  }

  static Future<List<dynamic>> getImages() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/images/'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> setMainPhoto(String imageId) async {
    // Backend uses PATCH, not PUT
    final res = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/images/$imageId/set-main'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> deletePhoto(String imageId) async {
    final res = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/images/$imageId'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> uploadCoverPhoto(
      Uint8List bytes, String filename) async {
    final token = await StorageService.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}/images/cover'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: filename, contentType: MediaType('image', 'jpeg')));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return await _handle(res);
  }

  static Future<void> deleteCoverPhoto() async {
    final res = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/images/cover'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  // ─── DISCOVER / MATCHES ─────────────────────────────────────────────────────

  static Future<List<dynamic>> discover({
    int page = 1,
    Map<String, String>? filters,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '10'};
    if (filters != null) params.addAll(filters);
    final uri = Uri.parse('${ApiConfig.baseUrl}/matches/discover')
        .replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers());
    final body = await _handle(res);
    // Backend returns {matches: [...], total, page, limit}
    if (body is Map) return List<dynamic>.from(body['matches'] ?? []);
    return List<dynamic>.from(body ?? []);
  }

  static Future<Map<String, dynamic>> likeUser(String userId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$userId/like'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> giftLikeUser(
      String userId, {String? message, String? giftSlug}) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$userId/gift-like'),
      headers: await _headers(),
      body: jsonEncode({
        if (message != null && message.isNotEmpty) 'message': message,
        if (giftSlug != null) 'gift_slug': giftSlug,
      }),
    );
    return await _handle(res);
  }

  static Future<void> passUser(String userId) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$userId/pass'),
      headers: await _headers(),
    );
  }

  static Future<List<dynamic>> getMyMatches() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/matches/my-matches'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getLikedMe() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/matches/liked-me'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getLikesSent() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/matches/likes-sent'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getDislikedByMe() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/matches/disliked-by-me'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> unmatch(String partnerId) async {
    await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/matches/$partnerId/unmatch'),
      headers: await _headers(),
    );
  }

  static Future<void> blockUser(String userId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$userId/block'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> rejectLiker(String likerId) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$likerId/reject'),
      headers: await _headers(),
    );
  }

  static Future<Map<String, dynamic>> reinviteUser(String partnerId, {String? giftSlug}) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$partnerId/reinvite'),
      headers: await _headers(),
      body: jsonEncode({if (giftSlug != null) 'gift_slug': giftSlug}),
    );
    return await _handle(res);
  }

  static Future<void> acceptInvitation(String notificationId) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/invitations/$notificationId/accept'),
      headers: await _headers(),
    );
  }

  static Future<void> declineInvitation(String notificationId) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/invitations/$notificationId/decline'),
      headers: await _headers(),
    );
  }

  /// Returns {is_active, removed_at} for one match.
  static Future<Map<String, dynamic>> getMatchStatus(String matchId) async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/matches/$matchId/status'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  // ─── SUPER INVITES ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendSuperInvite(String userId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/matches/$userId/super-invite'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getSuperInviteBalance() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/super-invites/balance'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getPendingInstantInvites() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/invites/pending'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  // ─── MESSAGES ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getConversations() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/messages/conversations'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getMessageHistory(String matchId) async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/messages/$matchId'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> sendMessage(String matchId, String text) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/messages/$matchId'),
      headers: await _headers(),
      body: jsonEncode({'content': text}),
    );
    return await _handle(res);
  }

  static Future<void> markMessagesRead(String matchId) async {
    await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/messages/$matchId/read'),
      headers: await _headers(),
    );
  }

  static Future<void> logCallSummary(String matchId, {
    required String media, // 'audio' | 'video'
    required int durationSeconds,
    bool missed = false,
  }) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/messages/$matchId/call-summary'),
        headers: await _headers(),
        body: jsonEncode({
          'media': media,
          'duration_seconds': durationSeconds,
          'missed': missed,
        }),
      );
    } catch (_) {} // fire-and-forget; don't crash on failure
  }

  // ─── NOTIFICATIONS ──────────────────────────────────────────────────────────

  static Future<List<dynamic>> getNotifications() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> markNotificationRead(String id) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
      headers: await _headers(),
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
      headers: await _headers(),
    );
  }

  // ─── GIFTS ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getGiftCatalog() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/gifts/'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getReceivedGifts() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/gifts/received'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> sendGift({
    required String receiverId,
    required String giftSlug,
    String? context,
    String? matchId,
    String? message,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/gifts/send'),
      headers: await _headers(),
      body: jsonEncode({
        'receiver_id': receiverId,
        'gift_slug': giftSlug,
        if (context != null) 'context': context,
        if (matchId != null) 'match_id': matchId,
        if (message != null && message.isNotEmpty) 'message': message,
      }),
    );
    return await _handle(res);
  }

  // ─── WALLET ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/balance'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getWalletPacks() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/packs'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletConfig() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/config'),
      headers: await _headers(auth: false),
    );
    return await _handle(res);
  }

  static Future<List<dynamic>> getWalletTransactions() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/transactions'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> createWalletOrder(int credits) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/wallet/purchase/order'),
      headers: await _headers(),
      body: jsonEncode({'credits': credits}),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> verifyWalletPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required int credits,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/wallet/purchase/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
        'credits': credits,
      }),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getBillingDetails() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/billing-details'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> updateBillingDetails(Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/wallet/billing-details'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> getPayoutDetails() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/wallet/payout-details'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> updatePayoutDetails(Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/wallet/payout-details'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal(int credits) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/wallet/withdraw'),
      headers: await _headers(),
      body: jsonEncode({'credits': credits}),
    );
    return await _handle(res);
  }

  // ─── SUBSCRIPTIONS ──────────────────────────────────────────────────────────

  // Returns {plans: [...], free_hearts_per_day, free_passes_per_day}
  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/subscriptions/plans'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getMySubscription() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/subscriptions/me'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> createSubscriptionOrder(String plan) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/subscriptions/purchase/order'),
      headers: await _headers(),
      body: jsonEncode({'plan': plan}),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> verifySubscriptionPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String plan,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/subscriptions/purchase/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
        'plan': plan,
      }),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> getPartnerPreferences() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/preferences'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> submitReport({
    required String reportedId,
    required String reason,
    String? description,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/reports'),
      headers: await _headers(),
      body: jsonEncode({
        'reported_id': reportedId,
        'reason': reason,
        if (description != null) 'description': description,
      }),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> updatePartnerPreferences(
      Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/profile/preferences'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return await _handle(res);
  }

  // ─── Instant Match ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> instantMatchInfo() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/info'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> instantMatchJoin() async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/join'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> instantMatchStatus() async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/status'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> instantMatchSkip() async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/skip'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<Map<String, dynamic>> instantMatchConfirm() async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/confirm'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> instantMatchLeave() async {
    final res = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/leave'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> instantMatchChatStatus(String matchId) async {
    final res = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/chat/$matchId/status'),
      headers: await _headers(),
    );
    return await _handle(res);
  }

  static Future<void> instantMatchChatLeave(String matchId) async {
    final res = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/chat/$matchId/leave'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> instantMatchChatInvite(String matchId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/chat/$matchId/invite'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> instantMatchChatAccept(String matchId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/chat/$matchId/invite/accept'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> instantMatchChatDecline(String matchId) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/instant-match/chat/$matchId/invite/decline'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  /// Returns the active ad from /config, or null if none.
  static Future<Map<String, dynamic>?> getActiveAd() async {
    try {
      final res = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/config'),
        headers: await _headers(auth: false),
      );
      final data = await _handle(res);
      if (data is Map && data['active_ad'] is Map) {
        return Map<String, dynamic>.from(data['active_ad'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Returns true if the platform is open for users. Fails open.
  static Future<bool> getPlatformOpen() async {
    try {
      final res = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/config'),
        headers: await _headers(auth: false),
      );
      final data = await _handle(res);
      if (data is Map) return data['platform_open'] as bool? ?? true;
    } catch (_) {}
    return true;
  }
}
