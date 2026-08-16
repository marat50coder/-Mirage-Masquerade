import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/veil_config.dart';
import 'curtain_cue.dart';
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
        final link = result.deepLink;
        if (link != null) {
          final merged = <String, dynamic>{}
            ..addAll(Map<String, dynamic>.from(link.clickEvent));
          // Some OneLinks deliver these ONLY via the typed DeepLink getters
          // and omit them from the raw clickEvent map — surface both.
          void put(String key, dynamic value) {
            if (value == null) return;
            final s = '$value';
            if (s.isEmpty || s == 'null') return;
            merged[key] = value;
          }
          put('deep_link_value', link.deepLinkValue);
          put('match_type', link.matchType);
          put('media_source', link.mediaSource);
          put('campaign', link.campaign);
          put('campaign_id', link.campaignId);
          put('is_deferred', link.isDeferred);
          put('click_http_referrer', link.clickHttpReferrer);
          put('af_sub1', link.afSub1);
          put('af_sub2', link.afSub2);
          put('af_sub3', link.afSub3);
          put('af_sub4', link.afSub4);
          put('af_sub5', link.afSub5);
          _deepLink = merged;
        }
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
            'af_status=${received['af_status']} '
            'media_source=${received['media_source']} '
            'campaign=${received['campaign']} '
            'campaign_id=${received['campaign_id']} '
            'af_c_id=${received['af_c_id']} '
            'af_adset=${received['af_adset']} '
            'adset=${received['adset']} '
            'agency=${received['agency']} '
            'keys=${received.keys.toList()}',
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

    // Deep-link WINS over install for non-empty values — a stale empty
    // install-value must never block a real OneLink sub_id from reaching the
    // partner. (Was `putIfAbsent` before, which caused the exact symptom.)
    _deepLink?.forEach((key, value) {
      if (value == null) return;
      final s = '$value';
      if (s.isEmpty || s == 'null') return;
      body[key] = value;
    });
    // App-open fills gaps only.
    _reopen?.forEach((key, value) {
      if (value == null) return;
      final s = '$value';
      if (s.isEmpty || s == 'null') return;
      body.putIfAbsent(key, () => value);
    });

    // Partners often pack the sub_ids into `deep_link_value` as a
    // query-string (`sub_id_11=x&sub_id_2=y&...`). Unpack so those keys land
    // in the body directly.
    _unpackDeepLinkValue(body);

    // OneLink URL overlay. When AppsFlyer treats the click as
    // re-attribution (`match_type: id_matching`, `is_retargeting: true`)
    // it collapses `media_source` / `campaign` / `agency` into the OneLink
    // brand slug (`miragemasquerade`) and drops the raw URL parameters.
    // Universal Links deliver the untouched click URL to
    // SceneDelegate.scene(_:continue:), which stashes it in UserDefaults;
    // parse the query here and overlay it on top of the SDK payload so the
    // partner's config endpoint receives the real `pid` / `c` / `agency`
    // instead of the brand slug fallback. URL query parameters always win
    // — they are, definitionally, what the click carried.
    await _overlayOneLinkUrl(body);

    // AppsFlyer's `onInstallConversionData` returns **canonical** field
    // names (`media_source`, `campaign`, `campaign_id`, `af_siteid`, ...)
    // while OneLink URLs carry the **raw** forms (`pid`, `c`, `siteid`,
    // `af_c_id`). Mirror both spellings so whichever the partner keys on is
    // present.
    const List<List<String>> aliasPairs = <List<String>>[
      <String>['media_source', 'pid'],
      <String>['campaign', 'c'],
      <String>['campaign_id', 'af_c_id'],
      <String>['adset', 'af_adset'],
      <String>['adset_id', 'af_adset_id'],
      <String>['af_siteid', 'siteid'],
      <String>['af_siteid', 'site_id'],
    ];
    for (final pair in aliasPairs) {
      final left = body[pair[0]];
      final right = body[pair[1]];
      if (_nonEmpty(left) && !_nonEmpty(right)) {
        body[pair[1]] = left;
      } else if (_nonEmpty(right) && !_nonEmpty(left)) {
        body[pair[0]] = right;
      }
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

  /// Reads the OneLink URL captured natively by SceneDelegate, extracts
  /// its query parameters and overlays them on [body]. Also fills the raw
  /// AppsFlyer aliases (`pid` ↔ `media_source`, `c` ↔ `campaign`) directly
  /// from the URL so the partner sees the true click parameters even when
  /// the SDK's install-conversion callback returned the OneLink brand
  /// slug as a fallback.
  Future<void> _overlayOneLinkUrl(Map<String, dynamic> body) async {
    final url = await OneLinkAttache.peek();
    if (url == null) return;
    final params = url.queryParameters;
    if (params.isEmpty) return;

    // Every URL query param is added — the click URL is authoritative.
    params.forEach((key, value) {
      if (key.isEmpty || value.isEmpty) return;
      body[key] = value;
    });

    // Promote the raw OneLink aliases to their canonical partner-side
    // spellings so `pid=Test Source` in the URL surfaces as
    // `media_source=Test Source` in the body (the partner's sub_id_11 slot
    // reads `media_source`, so this is what turns it green).
    void promote(String from, String to) {
      final raw = params[from];
      if (raw == null || raw.isEmpty) return;
      body[to] = raw;
    }
    promote('pid', 'media_source');
    promote('c', 'campaign');
    promote('af_c_id', 'campaign_id');
    promote('af_adset', 'adset');
    promote('siteid', 'af_siteid');
  }

  /// If `deep_link_value` arrives as a query-string blob
  /// (`campaign=foo&campaign_id=bar&…`), split it and merge each key into
  /// [body]. Partners occasionally pack the canonical attribution fields
  /// there when the click URL couldn't be parsed by the AppsFlyer SDK
  /// directly (deep-link redirect chains, cached universal links, etc).
  /// Deep-link values win over what was already there — the URL is the
  /// closest thing to source of truth for a OneLink click.
  static void _unpackDeepLinkValue(Map<String, dynamic> body) {
    final raw = body['deep_link_value'];
    if (raw is! String || raw.isEmpty || !raw.contains('=')) return;
    for (final pair in raw.split('&')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final k = Uri.decodeQueryComponent(pair.substring(0, eq));
      final v = Uri.decodeQueryComponent(pair.substring(eq + 1));
      if (k.isEmpty || v.isEmpty) continue;
      body[k] = v;
    }
  }

  static bool _nonEmpty(Object? v) {
    if (v == null) return false;
    final s = '$v';
    return s.isNotEmpty && s != 'null';
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
