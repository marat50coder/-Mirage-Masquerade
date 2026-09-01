import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

/// Starts AppsFlyer only to record install attribution (`Organic` /
/// `Non-organic`). No config POST, no WebView routing, no ATT / IDFA.
class Attribution {
  Attribution._();
  static final Attribution instance = Attribution._();

  static const _devKey = 'NUR4s2AGvF6bNrnjSs55xV';
  static const _appId = '6797925941';

  String? _status;
  bool _started = false;

  /// Last known `af_status`, or null until AppsFlyer answers.
  String? get status => _status;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: _devKey,
          appId: _appId,
          showDebug: kDebugMode,
        ),
      );
      sdk.onInstallConversionData((raw) {
        final map = _flat(raw);
        final value = map['af_status']?.toString();
        if (value != null && value.isNotEmpty) _status = value;
        assert(() {
          debugPrint('[MM.AF] status=$_status keys=${map.keys.toList()}');
          return true;
        }());
      });
      await sdk.initSdk(registerConversionDataCallback: true);
    } catch (error) {
      assert(() {
        debugPrint('[MM.AF] init failed: $error');
        return true;
      }());
    }
  }

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }
}
