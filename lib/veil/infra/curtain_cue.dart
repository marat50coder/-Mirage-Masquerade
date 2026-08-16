import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads (and clears) the one-shot cold-start push URL that the native
/// SceneDelegate stashed in UserDefaults. The Dart key omits the `flutter.`
/// prefix that shared_preferences adds on iOS; the Swift side writes the
/// prefixed form (`flutter.msq_curtain_cue`).
class CurtainCue {
  static const String _dartKey = 'msq_curtain_cue';

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
}

/// Reads the OneLink URL that the SceneDelegate stashed at cold-start
/// (`willConnectTo`) or during warm continue-user-activity. Read-only —
/// TraceCourier peeks at every compose() call to overlay the click URL
/// query parameters (`pid`, `c`, `agency`, `siteid`, ...) on top of the
/// AppsFlyer install-conversion payload. On re-attribution installs
/// AppsFlyer collapses those into the OneLink brand slug; the URL is the
/// only source of truth.
class OneLinkAttache {
  static const String _dartKey = 'msq_onelink_url';

  static Future<Uri?> peek() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      return Uri.tryParse(value);
    } catch (_) {
      return null;
    }
  }
}
