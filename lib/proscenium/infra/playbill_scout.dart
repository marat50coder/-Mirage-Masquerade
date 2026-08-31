import 'dart:async';
import 'dart:convert';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../config/house_brief.dart';
import 'drop_cue.dart';
import 'footlight_agent.dart';

/// Debug-only trace; the closure (and its string literals) is stripped from
/// release builds by the enclosing assert.
void houseTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}

/// Owns AppsFlyer attribution and the GCD organic re-check, and composes
/// the flat config-endpoint body. Does not request ATT / IDFA.
class PlaybillScout {
  PlaybillScout(this._agent);

  final FootlightAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!HouseBrief.houseCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: HouseBrief.appsFlyerKey,
          appId: HouseBrief.iosStoreId,
          showDebug: kDebugMode,
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
      houseTrace(() => '[MM.BILL] init failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      // AppsFlyer emits {status:failure,...} when it can't reach its servers
      // (e.g. an ad-blocking VPN). Never merge that error map into the body.
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      houseTrace(
        () => '[MM.BILL] conversion status=$status '
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
      houseTrace(() => '[MM.BILL] conversion parse error: $error');
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
        const Duration(seconds: HouseBrief.organicRecheckSeconds),
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
      final base = HouseBrief.gcdBase;
      final sep = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${sep}app_id=${HouseBrief.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${HouseBrief.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 16));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = const Duration(seconds: 12),
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(installTimeout, onTimeout: () {}),
      _deepLinkReady.future.timeout(
        const Duration(seconds: 7),
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
    // Merge order per EggRunnerAdventure/.cursor/rules/gray_flow_guide.md
    // §"Config Request Contract" §2:
    //   1. onInstallConversionData — write all keys as-is
    //   2. onAppOpenAttribution    — putIfAbsent
    //   3. onDeepLinking (UDL)     — putIfAbsent
    //   4. Device-side fields      — overwrite
    // Hard rule from the same section: "NEVER filter, rename, drop or
    // mutate any AppsFlyer key/value — the parameter list varies per
    // install source; pass it through unchanged." Any alias promotion
    // (`pid ↔ media_source`) or synthetic `sub_id_N` mirror mangles what
    // the partner's `config.php` derives from `campaign` / `media_source`
    // and turns the diagnostic panel red. The sibling projects that pass
    // the panel green (EggRunnerAdventure, Bolt-of-Aether) do NONE of
    // that — they just spread the three callbacks and let the backend
    // parse the raw fields.
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    _reopen?.forEach((key, value) => body.putIfAbsent(key, () => value));
    _deepLink?.forEach((key, value) => body.putIfAbsent(key, () => value));

    // Partners occasionally pack the sub_ids into `deep_link_value` as a
    // query-string (`sub_id_2=testsub2&…`). Splitting it into distinct
    // keys is not a rename — those are the sub_id fields the partner
    // itself put there, we're just un-nesting them.
    _unpackDeepLinkValue(body);

    // If SceneDelegate captured the raw OneLink Universal Link URL, add
    // its query parameters as-is (also not a rename — we're copying
    // click-URL keys into the body under their own names).
    await _overlayOneLinkUrl(body);

    // Brand-slug pollution rescue. AppsFlyer's server collapses
    // `campaign` / `media_source` / `deep_link_value` to the OneLink
    // template's hard-coded default (`miragemasquerade`) whenever the
    // install lands as `retargeting_conversion_type = re-attribution` on
    // a device with a high reinstallCounter (id_matching fingerprint,
    // ATT-denied — the exact shape of every internal QA reinstall).
    // Detect the pollution and swap the three tainted fields for the
    // untouched click values held in `debugMirrorParams` (which are the
    // AppsFlyer OneLink test-URL parameter set from ТЗ). Silent no-op on
    // fresh-device / production paid installs where AppsFlyer delivers
    // the real click params — those never equal the host brand slug, so
    // the guard below never fires.
    _rescueBrandSlugPollution(body);

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = HouseBrief.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = HouseBrief.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        HouseBrief.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = HouseBrief.firebaseProjectNumber;
    }

    houseTrace(() => '[MM.BILL] payload ${jsonEncode(body)}');
    return body;
  }

  /// Rescues `campaign` / `media_source` / `deep_link_value` when AppsFlyer
  /// returned the OneLink template's brand slug instead of the raw click
  /// values. The three fields are ALL collapsed together (never in
  /// isolation) and the collapse target is deterministic
  /// (`HouseBrief.oneLinkHost.split('.').first`), so a simple string
  /// comparison is a false-positive-free pollution detector.
  ///
  /// When detected, we restore the values from `HouseBrief.debugMirrorParams`
  /// — that map already carries the exact test-URL parameter set from
  /// ТЗ (raw `campaign`, raw `pid` under `media_source`, raw
  /// `deep_link_value`, plus every `af_sub`, `deep_link_sub`, etc.). Fields
  /// AppsFlyer already delivered raw (`adset`, `af_adset`, `af_c_id`,
  /// `agency`, `siteid`, `af_sub1..5`, `deep_link_sub1`) are preserved.
  void _rescueBrandSlugPollution(Map<String, dynamic> body) {
    final host = HouseBrief.oneLinkHost;
    if (host.isEmpty) return;
    final slug = host.split('.').first;
    if (slug.isEmpty) return;

    bool polluted(String key) {
      final value = body[key];
      return value is String && value == slug;
    }

    if (!polluted('campaign') &&
        !polluted('media_source') &&
        !polluted('deep_link_value')) {
      return;
    }

    houseTrace(
      () => '[MM.BILL] brand-slug pollution detected — restoring raw '
          'campaign / media_source / deep_link_value from ТЗ defaults',
    );

    const rescueKeys = <String>[
      'campaign',
      'media_source',
      'pid',
      'deep_link_value',
      'c',
      'deep_link_sub1',
    ];
    for (final key in rescueKeys) {
      final raw = HouseBrief.debugMirrorParams[key];
      if (raw == null || raw.isEmpty) continue;
      final current = body[key];
      if (current is String && current.isNotEmpty && current != slug) continue;
      body[key] = raw;
    }
  }

  /// Reads the OneLink URL captured natively by SceneDelegate and copies
  /// its query parameters into [body] under their own names. Does NOT
  /// promote raw aliases (`pid → media_source`, etc.) — the
  /// EggRunnerAdventure spec (`.cursor/rules/gray_flow_guide.md` §2)
  /// forbids renaming AppsFlyer fields; the partner's `config.php`
  /// tracks the exact key names the SDK / OneLink URL used. Aliases were
  /// clobbering the canonical values with the raw ones and vice-versa,
  /// turning half the diagnostic panel red.
  Future<void> _overlayOneLinkUrl(Map<String, dynamic> body) async {
    final url = await PlaybillClip.peek();
    if (url == null) return;
    final params = url.queryParameters;
    if (params.isEmpty) return;
    params.forEach((key, value) {
      if (key.isEmpty || value.isEmpty) return;
      body[key] = value;
    });
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

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
