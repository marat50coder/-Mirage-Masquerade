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
