import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/veil_config.dart';
import 'mummer_agent.dart';

/// Debug-only trace; the closure (and its string literals) is stripped from
/// release builds by the enclosing assert.
void veilTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}

/// Owns AppsFlyer attribution, the ATT prompt and the GCD organic re-check,
/// and composes the flat config-endpoint body.
class TraceCourier {
  TraceCourier(this._agent);

  final MummerAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!VeilConfig.veilCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: VeilConfig.appsFlyerKey,
          appId: VeilConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 6,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flat(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      veilTrace(() => '[MSQ.TRACE] init failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 480));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      // AppsFlyer emits {status:failure,...} when it can't reach its servers
      // (e.g. an ad-blocking VPN). Never merge that error map into the body.
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      veilTrace(
        () => '[MSQ.TRACE] conversion status=$status '
            'af_status=${received['af_status']}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else {
        // Publish the verdict immediately so the launch decision (and the
        // config POST) carries af_status without blocking on the organic
        // re-check. Waiting inline used to let awaitSignals time out first,
        // so the POST went out with no attribution and a real OneLink user
        // was misrouted to the white game.
        _install = received;
        if (received['af_status'] == 'Organic') {
          unawaited(_recheckOrganic(received));
        }
      }
    } catch (error) {
      veilTrace(() => '[MSQ.TRACE] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  /// AppsFlyer sometimes reports `Organic` first and attaches the real
  /// non-organic attribution a few seconds later. Refine `_install` in the
  /// background so a delayed OneLink match is still picked up by the
  /// token-refresh re-POST / the next launch.
  Future<void> _recheckOrganic(Map<String, dynamic> received) async {
    try {
      await Future<void>.delayed(
        const Duration(seconds: VeilConfig.organicRecheckSeconds),
      );
      final refined = await _fetchGcd();
      if (refined != null && refined.isNotEmpty) _install = refined;
    } catch (_) {}
  }

  /// True once AppsFlyer produced a usable verdict (organic or non-organic).
  /// A `null`/empty map means attribution never resolved (timeout / SDK
  /// failure) — the caller must NOT persist a white-game verdict in that case.
  bool get attributionResolved => _install != null && _install!.isNotEmpty;

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD keys on the numeric App Store id, not the bundle id.
      final base = VeilConfig.gcdBase;
      final sep = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${sep}app_id=${VeilConfig.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${VeilConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = const Duration(seconds: 10),
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(installTimeout, onTimeout: () {}),
      _deepLinkReady.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    if (_reopen != null) {
      _reopen!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = VeilConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = VeilConfig.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        VeilConfig.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = VeilConfig.firebaseProjectNumber;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }
    veilTrace(() => '[MSQ.TRACE] payload ${jsonEncode(body)}');
    return body;
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
