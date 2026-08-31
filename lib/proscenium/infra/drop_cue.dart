import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads (and clears) the one-shot cold-start push URL that the native
/// SceneDelegate stashed in UserDefaults. The Dart key omits the `flutter.`
/// prefix that shared_preferences adds on iOS; the Swift side writes the
/// prefixed form (`flutter.mm_drop_cue`).
class DropCue {
  static const String _dartKey = 'mm_drop_cue';
  static const String _bootKey = 'mm_drop_boot';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Reads (and clears) the boolean flag SceneDelegate sets when a cold-start
  /// push tap occurred without a resolvable destination URL. Returning `true`
  /// tells the director to force the mirror route so a push‑woken user is
  /// never dropped on the native game just because the payload lacked a URL
  /// key the native side knew about.
  static Future<bool> consumeBoot() async {
    if (!Platform.isIOS) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final flag = preferences.getBool(_bootKey) ?? false;
      if (flag) await preferences.remove(_bootKey);
      return flag;
    } catch (_) {
      return false;
    }
  }
}

/// Reads the OneLink URL that the SceneDelegate stashed at cold-start
/// (`willConnectTo`) or during warm continue-user-activity. Read-only —
/// PlaybillScout peeks at every compose() call to overlay the click URL
/// query parameters (`pid`, `c`, `agency`, `siteid`, ...) on top of the
/// AppsFlyer install-conversion payload. On re-attribution installs
/// AppsFlyer collapses those into the OneLink brand slug; the URL is the
/// only source of truth.
class PlaybillClip {
  static const String _dartKey = 'mm_playbill_url';

  static Future<Uri?> peek() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      // Force a re-read from NSUserDefaults — SharedPreferences caches
      // values in memory on the first `getInstance()`, and the SceneDelegate
      // write from Swift happens AFTER that cache is warm. Without reload,
      // PlaybillScout keeps seeing null (no OneLink URL), the overlay never
      // runs and `body['campaign']` stays polluted with the OneLink brand
      // slug that AppsFlyer collapses re-attribution installs to.
      await preferences.reload();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      return Uri.tryParse(value);
    } catch (_) {
      return null;
    }
  }
}
