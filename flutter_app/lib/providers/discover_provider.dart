import 'package:flutter/foundation.dart';
import '../models/discover_profile.dart';
import '../services/api_service.dart';

class DiscoverProvider extends ChangeNotifier {
  List<DiscoverProfile> _profiles = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  Map<String, String> _filters = {};
  String? _error;

  List<DiscoverProfile> get profiles => _profiles;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _profiles = [];
    }
    if (!_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiService.discover(page: _page, filters: _filters);
      final newProfiles = data.map((j) => DiscoverProfile.fromJson(j)).toList();
      _profiles = refresh ? newProfiles : [..._profiles, ...newProfiles];
      _hasMore = newProfiles.length >= 10;
      _page++;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyFilters(Map<String, String> filters) {
    _filters = filters;
    load(refresh: true);
  }

  void removeTopCard() {
    if (_profiles.isNotEmpty) {
      _profiles.removeAt(0);
      notifyListeners();
      if (_profiles.length <= 2 && _hasMore) load();
    }
  }
}
