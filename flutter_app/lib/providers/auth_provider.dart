import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  ProfileModel? _profile;
  Map<String, dynamic>? _partnerPreferences;
  bool _loading = true;

  UserModel? get user => _user;
  ProfileModel? get profile => _profile;
  Map<String, dynamic>? get partnerPreferences => _partnerPreferences;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isProfileComplete => _profile?.isComplete ?? false;

  final _googleSignIn = GoogleSignIn(
    serverClientId: ApiConfig.googleServerClientId,
    scopes: ['email', 'profile'],
  );

  Future<void> initialize() async {
    try {
      final token = await StorageService.getToken();
      final userData = await StorageService.getUser();
      if (token != null && userData != null) {
        _user = UserModel.fromJson(userData);
        await _fetchProfile();
      }
    } catch (_) {
      await StorageService.clearAll();
      _user = null;
      _profile = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  BannedException? _banInfo;
  BannedException? get banInfo => _banInfo;

  // Name from Google account — pre-fills step 0 of onboarding for new users
  String? _pendingGoogleName;
  String? get pendingGoogleName => _pendingGoogleName;
  void clearPendingGoogleName() => _pendingGoogleName = null;

  Future<void> _fetchProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      _profile = ProfileModel.fromJson(data);
    } on BannedException catch (e) {
      _banInfo = e;
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      if (e.statusCode == 401) rethrow;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchPartnerPreferences() async {
    try {
      _partnerPreferences = await ApiService.getPartnerPreferences();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    // ApiService.login() throws on bad credentials — let it propagate.
    final data = await ApiService.login(email: email, password: password);
    await _saveSession(data);
    // Profile fetch is best-effort — never block navigation on it.
    // If profile is missing/incomplete, _navigate() sends user to onboarding.
    try {
      await _fetchProfile();
    } catch (_) {}
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    final data = await ApiService.signup(
      email: email,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
    );
    if (data['access_token'] != null) {
      await _saveSession(data);
      // New users have no profile yet — ignore any fetch error so navigation proceeds
      try { await _fetchProfile(); } catch (_) {}
    }
  }

  Future<void> googleSignIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw ApiException(message: 'Google sign-in cancelled');
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw ApiException(message: 'Failed to get ID token from Google');
    final data = await ApiService.googleAuth(idToken);
    // Capture display name before saving session so onboarding can pre-fill it
    _pendingGoogleName = account.displayName?.split(' ').first.trim();
    await _saveSession(data);
    // Profile fetch is best-effort — same as login().
    try {
      await _fetchProfile();
    } catch (_) {}
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    if (data['access_token'] != null) {
      await StorageService.saveToken(data['access_token']);
    }
    if (data['refresh_token'] != null) {
      await StorageService.saveRefreshToken(data['refresh_token']);
    }
    final userMap = {
      'user_id': data['user_id'] ?? '',
      'email': data['email'] ?? '',
      'name': data['name'],
    };
    await StorageService.saveUser(userMap);
    _user = UserModel.fromJson(userMap);
    notifyListeners();
    // Register FCM push token with backend (best-effort, non-blocking).
    NotificationService.registerToken().catchError((_) {});
  }

  Future<void> logout() async {
    await ApiService.logout();
    await StorageService.clearAll();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _user = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> refreshProfile() => _fetchProfile();

  void updateLocalProfile(ProfileModel profile) {
    _profile = profile;
    notifyListeners();
  }
}
