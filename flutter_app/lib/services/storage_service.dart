import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'user_data';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _userKey, value: jsonEncode(user));

  static Future<Map<String, dynamic>?> getUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<void> clearAll() => _storage.deleteAll();

  // ─── Theme Mode ─────────────────────────────────────────────────────────────

  static const _darkModeKey = 'dark_mode';

  static Future<void> saveDarkMode(bool enabled) =>
      _storage.write(key: _darkModeKey, value: enabled ? 'true' : 'false');

  static Future<bool> getDarkMode() async {
    final value = await _storage.read(key: _darkModeKey);
    return value == 'true';
  }

  // ─── Daily pass counter (resets at midnight) ────────────────────────────────

  static const _passDateKey  = 'pass_date';
  static const _passCountKey = 'pass_count';

  static Future<int> getTodayPassCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: _passDateKey);
    if (savedDate != today) return 0;
    return int.tryParse(await _storage.read(key: _passCountKey) ?? '0') ?? 0;
  }

  static Future<void> incrementPassCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: _passDateKey);
    int count = 0;
    if (savedDate == today) {
      count = int.tryParse(await _storage.read(key: _passCountKey) ?? '0') ?? 0;
    }
    await _storage.write(key: _passDateKey, value: today);
    await _storage.write(key: _passCountKey, value: '${count + 1}');
  }

  // ─── Daily like counter (resets at midnight) ─────────────────────────────────

  static const _likeDateKey  = 'like_date';
  static const _likeCountKey = 'like_count';

  static Future<int> getTodayLikeCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: _likeDateKey);
    if (savedDate != today) return 0;
    return int.tryParse(await _storage.read(key: _likeCountKey) ?? '0') ?? 0;
  }

  static Future<void> incrementLikeCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = await _storage.read(key: _likeDateKey);
    int count = 0;
    if (savedDate == today) {
      count = int.tryParse(await _storage.read(key: _likeCountKey) ?? '0') ?? 0;
    }
    await _storage.write(key: _likeDateKey, value: today);
    await _storage.write(key: _likeCountKey, value: '${count + 1}');
  }
}
