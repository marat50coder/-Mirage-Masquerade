import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

/// Runs the ATT prompt (once) and starts AppsFlyer to record install
/// attribution status (`Organic` / `Non-organic`). AppsFlyer is initialised
/// with `timeToWaitForATTUserAuthorization` so it waits for the user's
/// decision before sending the first launch event. If the user denies
/// tracking, the SDK still resolves `af_status` — it just does so without
/// IDFA.
class Attribution {
  Attribution._();
  static final Attribution instance = Attribution._();

  static const _devKey = 'NUR4s2AGvF6bNrnjSs55xV';
  static const _appId = '6797925941';
  static const _attWaitSeconds = 60;

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
          timeToWaitForATTUserAuthorization: _attWaitSeconds.toDouble(),
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
      unawaited(_requestAtt());
    } catch (error) {
      assert(() {
        debugPrint('[MM.AF] init failed: $error');
        return true;
      }());
    }
  }

  Future<void> _requestAtt() async {
    try {
      final current =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (current == TrackingStatus.notDetermined) {
        // Small delay so the OS is ready to present the modal after launch.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (error) {
      assert(() {
        debugPrint('[MM.ATT] prompt failed: $error');
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
