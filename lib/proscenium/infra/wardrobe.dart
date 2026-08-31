import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/house_models.dart';

/// Persistence for the house layer: route decision, cached / pending URLs and
/// push-invite bookkeeping. Prefix is project-unique (`mm.house.*`).
class Wardrobe {
  static const String _routeKey = 'mm.house.lane';
  static const String _expiryKey = 'mm.house.until';
  static const String _inviteKey = 'mm.house.call.after';
  static const String _permissionKey = 'mm.house.call.ok';
  static const String _osDeniedKey = 'mm.house.call.os_no';
  static const String _savedUrlKey = 'mm.house.safe.dest';
  static const String _pendingUrlKey = 'mm.house.safe.hold';
  static const String _lastMirrorKey = 'mm.house.safe.last_pane';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  HouseRoute get route => HouseRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(HouseRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      if (expiresAt != null) {
        await _preferences.setInt(_expiryKey, expiresAt);
      }
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Persists the current main-frame URL of the mirror so a returning launch
  /// can resume where the user actually was — instead of always reloading the
  /// initial cached URL and letting the partner rerun its redirect chain (on a
  /// repeat visit the partner often collapses to a generic landing because the
  /// specific offer was already served against this `af_id`).
  Future<void> rememberLastMirror(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      await _secure.write(key: _lastMirrorKey, value: trimmed);
    } catch (_) {}
  }

  Future<String?> lastMirrorUrl() async {
    try {
      return await _secure.read(key: _lastMirrorKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> forgetLastMirror() async {
    try {
      await _secure.delete(key: _lastMirrorKey);
    } catch (_) {}
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() => _preferences.setBool(_osDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
