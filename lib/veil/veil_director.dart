import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config/veil_config.dart';
import 'core/veil_models.dart';
import 'infra/curtain_cue.dart';
import 'infra/herald_hub.dart';
import 'infra/ledger_exchange.dart';
import 'infra/masque_vault.dart';
import 'infra/mummer_agent.dart';
import 'infra/signal_scout.dart';
import 'infra/trace_courier.dart';

/// The routing brain. Decides — once per launch — whether to show the native
/// game (house), the partner WebView (mirror), or the offline screen (hush).
class VeilDirector {
  VeilDirector({
    required this.vault,
    required this.scout,
    required this.courier,
    required this.ledger,
    required this.herald,
    required this.agent,
    required this.runtimeEnabled,
  });

  final MasqueVault vault;
  final SignalScout scout;
  final TraceCourier courier;
  final LedgerExchange ledger;
  final HeraldHub herald;
  final MummerAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && VeilConfig.veilCredentialsReady;

  Future<StageTarget>? _decideFuture;

  /// De-duplicates only *concurrent* startup calls, then clears the cache so a
  /// later call (e.g. Retry after Wi-Fi returns) re-runs the whole pipeline
  /// instead of replaying a stale offline verdict.
  Future<StageTarget> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??=
          _decide(onProgress: onProgress).whenComplete(() => _decideFuture = null);

  Future<StageTarget> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      _trace(() => '[MSQ.VEIL] gate closed runtime=$runtimeEnabled '
          'creds=${VeilConfig.veilCredentialsReady}');
      onProgress(1);
      return const HouseTarget();
    }

    _trace(() => '[MSQ.VEIL] decide route=${vault.route}');
    herald.onTokenChanged = _refreshForToken;

    // Cold-start push tap is consumed FIRST — before any network work — so a
    // timeout race can never lose the destination URL.
    final coldUrl = await CurtainCue.consume();
    if (coldUrl != null) {
      await vault.saveRoute(VeilRoute.mirror);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return MirrorTarget(coldUrl, coldLaunch: true);
    }

    // SceneDelegate saw a notificationResponse but couldn't extract a URL
    // from the payload — force the mirror route so the pipeline falls
    // through to the config endpoint / cached URL instead of the native
    // game. Without this a push tap on a user who was previously routed to
    // house strands them on the wrong screen.
    final pushBoot = await CurtainCue.consumeBoot();
    if (pushBoot && vault.route != VeilRoute.mirror) {
      _trace(() => '[MSQ.VEIL] cold push tap w/o URL → force mirror');
      await vault.saveRoute(VeilRoute.mirror);
    }

    // Truly-offline fast path — jumps to HushScreen instantly instead of
    // running the whole ATT + AppsFlyer + config pipeline (which would sit
    // on the loading screen for 30+ s waiting for network timeouts). Only
    // triggers when connectivity_plus EXPLICITLY reports every interface as
    // `[none]`; the ambiguous empty-list cold-start hiccup falls through so
    // an actually-online first-launch never hits Hush by mistake.
    if (await scout.isConfirmedOffline()) {
      _trace(() => '[MSQ.VEIL] confirmed offline → hush');
      onProgress(1);
      return const HushTarget();
    }

    onProgress(0.14);
    return switch (vault.route) {
      VeilRoute.undecided => _firstDecision(onProgress),
      VeilRoute.mirror => _returningMirror(onProgress),
      VeilRoute.house => _returningHouse(onProgress),
    };
  }

  Future<StageTarget> _firstDecision(void Function(double) progress) async {
    progress(0.3);
    // Parallel push + attribution warm-up. AppsFlyer's `onDeepLinking`
    // callback only fires after `initSdk` runs — awaiting `herald.boot()`
    // sequentially before that would let a OneLink click arrive before the
    // SDK was listening. (OneLink URL capture is still safe either way,
    // since SceneDelegate stashes it natively, but AppsFlyer's own signal
    // is what unlocks `af_status=Non-organic` for the config POST.)
    try {
      await Future.wait<void>(<Future<void>>[herald.boot(), courier.start()]);
    } catch (_) {}
    // FCM's `getInitialMessage()` writes any cold-start push URL into the
    // vault only AFTER `herald.boot()` finishes. Consume it here — before
    // the config request — otherwise a push tap on a fresh install would be
    // silently overwritten by the config endpoint's default destination.
    final pushUrl = await vault.consumePushUrl();
    if (pushUrl != null && pushUrl.isNotEmpty) {
      _trace(() => '[MSQ.VEIL] first: FCM initial push → open');
      await vault.saveRoute(VeilRoute.mirror);
      unawaited(_backgroundDispatch());
      progress(1);
      return MirrorTarget(pushUrl, coldLaunch: true);
    }
    // Deliberately no DNS pre-gate here — connectivity_plus /
    // InternetAddress.lookup can both misfire on a truly cold app process
    // (empty state list, transient SocketException) while Wi-Fi is on,
    // which used to strand the very first launch on HushScreen. The config
    // POST below is the authoritative online test; if it fails without any
    // server response we route to a retryable HushTarget further down.
    progress(0.5);
    // First launch must wait long enough for AppsFlyer to resolve attribution
    // *after* the ATT prompt (SDK waits ~6 s for the ATT verdict), otherwise
    // the config POST fires with no af_status and a real OneLink install is
    // misrouted to the white game.
    final tokenFuture = herald.awaitToken(timeout: const Duration(seconds: 4));
    await courier.awaitSignals(installTimeout: const Duration(seconds: 13));
    final token = await tokenFuture;
    progress(0.74);
    final (reply, body) = await _requestConfig(token: token);
    progress(1);
    final hadAttribution = _bodyHasAttribution(body);
    _trace(() => '[MSQ.VEIL] first: hasDest=${reply.hasDestination} '
        'attrResolved=${courier.attributionResolved} attr=$hadAttribution '
        'server=${reply.serverResponded} reason=${reply.reason}');
    if (reply.hasDestination) {
      await vault.saveRoute(VeilRoute.mirror);
      return MirrorTarget(reply.url!);
    }
    // Connectivity check passed (neutral DNS ok) but the config POST itself
    // failed — most often the very first request racing a just-restored
    // connection after the offline screen's Retry. Do NOT drop a possibly
    // attributed OneLink user into the white game: show the offline screen so
    // a user-driven Retry re-runs the decision and can still reach the mirror.
    // A real server verdict (even a 404 "no data") sets serverResponded, so
    // the organic / reviewer path below is unaffected.
    if (!reply.serverResponded) {
      _trace(() => '[MSQ.VEIL] first: config network fail → hush (retryable)');
      return const HushTarget();
    }
    // Real server verdict with no URL → organic → white. Persist only when
    // the POST actually carried AppsFlyer attribution — otherwise leave the
    // route undecided so the next cold-launch retries fresh (AppsFlyer will
    // usually cough up the conversion callback within 1–2 launches).
    if (hadAttribution) {
      await vault.saveRoute(VeilRoute.house);
    }
    return const HouseTarget();
  }

  Future<StageTarget> _returningMirror(void Function(double) progress) async {
    // Any stash left by a previous session (SceneDelegate cold-tap or a
    // foreground onMessageOpenedApp fired while the app was killed) wins
    // outright — that URL is exactly what the user tapped a notification for.
    final earlyStash = await vault.consumePushUrl();
    if (earlyStash != null && earlyStash.isNotEmpty) {
      progress(1);
      return MirrorTarget(earlyStash);
    }
    // Boot herald BEFORE checking cached URL so FCM's `getInitialMessage()`
    // has a chance to stash any cold-start push URL Firebase's swizzled
    // AppDelegate ate before SceneDelegate saw the notificationResponse.
    // Without this, the fast-path below would open the initial cached URL
    // instead of the URL the user just tapped in the notification.
    try {
      await herald.boot();
    } catch (_) {}
    final pendingPush = await vault.consumePushUrl();
    if (pendingPush != null && pendingPush.isNotEmpty) {
      _trace(() => '[MSQ.VEIL] returning-mirror: FCM push → open');
      progress(1);
      return MirrorTarget(pendingPush, coldLaunch: true);
    }
    // On a plain re-entry (no push) we deliberately reopen the initial
    // partner URL, not whatever page the user was last on. The test flow
    // requires deterministic entry so the partner's funnel is re-runnable
    // — a "last URL" resume was landing testers on a mid-funnel page.
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return MirrorTarget(cached);
    }

    // Herald is already booted; only the attribution SDK still needs a start
    // for the config POST below.
    try {
      await courier.start();
    } catch (_) {}
    // No DNS pre-gate — see _firstDecision comment. Config POST is the
    // authoritative online test.
    progress(0.64);
    final tokenFuture = herald.awaitToken(timeout: const Duration(seconds: 4));
    await courier.awaitSignals(installTimeout: const Duration(seconds: 7));
    final token = await tokenFuture;
    final (reply, _) = await _requestConfig(token: token);
    progress(1);
    if (reply.hasDestination) return MirrorTarget(reply.url!);
    if (cached != null) return MirrorTarget(cached);
    // Truly offline (POST failed) — Hush, retryable.
    if (!reply.serverResponded) return const HushTarget();
    return const HushTarget();
  }

  Future<StageTarget> _returningHouse(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      progress(1);
      return const HouseTarget();
    }
    await Future.wait<void>(<Future<void>>[herald.boot(), courier.start()]);
    // A cold-start push on a user previously routed to house must still open
    // the mirror. `herald.boot()` has now landed any FCM initial message in
    // the vault — pick it up before deciding between native game and config.
    final pushUrl = await vault.consumePushUrl();
    if (pushUrl != null && pushUrl.isNotEmpty) {
      _trace(() => '[MSQ.VEIL] returning-house: FCM push → open');
      await vault.saveRoute(VeilRoute.mirror);
      unawaited(_backgroundDispatch());
      progress(1);
      return MirrorTarget(pushUrl, coldLaunch: true);
    }
    if (!await scout.canReachNetwork()) {
      progress(1);
      return const HouseTarget();
    }
    progress(0.58);
    final tokenFuture = herald.awaitToken(timeout: const Duration(seconds: 4));
    await courier.awaitSignals();
    final token = await tokenFuture;
    final (reply, body) = await _requestConfig(token: token);
    progress(1);
    if (reply.hasDestination) {
      await vault.saveRoute(VeilRoute.mirror);
      return MirrorTarget(reply.url!);
    }
    // Stuck-in-house rescue: if we're still committed to native but the POST
    // couldn't carry any AppsFlyer attribution, bounce back to `undecided` so
    // the next launch retries as a fresh install. Without this, a slow first
    // AppsFlyer callback traps the user on white forever.
    if (!_bodyHasAttribution(body)) {
      await vault.saveRoute(VeilRoute.undecided);
    }
    return const HouseTarget();
  }

  /// A "no destination" reply is only trustworthy when the POST actually
  /// carried AppsFlyer attribution. If the body was just the base identity
  /// fields (bundle_id / os / store_id / locale / af_id / push fields), the
  /// server had nothing to match against — that's a slow-conversion miss,
  /// not a genuine organic user, and the route stays `undecided` so the next
  /// cold-launch retries.
  static bool _bodyHasAttribution(Map<String, dynamic> body) {
    const baseKeys = <String>{
      'af_id',
      'bundle_id',
      'os',
      'store_id',
      'locale',
      'push_token',
      'firebase_project_id',
    };
    return body.keys.any((k) => !baseKeys.contains(k));
  }

  Future<(VeilReply reply, Map<String, dynamic> body)> _requestConfig({
    String? token,
  }) async {
    final body = await courier.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? herald.token,
    );
    // Simulate a non-organic OneLink install so the real server returns the
    // real destination URL. Debug forces this by default (Xcode convenience);
    // a release build only forces it when EXPLICITLY compiled with
    // `--dart-define=FORCE_MIRROR=true`. A normal `flutter build ipa` folds
    // `forceMirror` to a compile-time `false`, tree-shaking this whole block
    // (and the sample params) out of the shipped binary. Real attribution
    // always wins (putIfAbsent).
    final bool forceMirror = kDebugMode
        ? VeilConfig.debugForceMirror
        : VeilConfig.forceMirrorRelease;
    if (forceMirror) {
      body['af_status'] = 'Non-organic';
      // Hard-override with the diagnostic test values, in both debug and
      // release. AppsFlyer's re-attribution (`is_retargeting=true` in the
      // test OneLink) collapses `media_source` / `campaign` down to the
      // OneLink brand slug ("miragemasquerade"), which paints the partner's
      // Parameter-Passing panel red for sub_id_1 / sub_id_2 (they're
      // derived from `campaign.split('_')`). `putIfAbsent` used to leave
      // the polluted values in place; a straight assignment forces the
      // known-good raw click params to ship. Safe in release too — this
      // branch only runs with the explicit `--dart-define=FORCE_MIRROR=true`
      // opt-in build; a normal store IPA tree-shakes the whole block out.
      VeilConfig.debugMirrorParams.forEach((key, value) {
        body[key] = value;
      });
      _trace(() => '[MSQ.VEIL] force mirror: af_status=Non-organic '
          '(release=${!kDebugMode})');
    }
    final reply = await ledger.request(body);
    _trace(() => '[MSQ.VEIL] cfg af_status=${body['af_status']} '
        'attrResolved=${courier.attributionResolved} '
        'hasDest=${reply.hasDestination} server=${reply.serverResponded} '
        'reason=${reply.reason}');
    return (reply, body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        herald.boot(),
        courier.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    // Skip while the main decide pipeline is still running: FirebaseMessaging
    // fires `onTokenRefresh` from inside `herald.boot()`, which arrives BEFORE
    // `courier.start()` gets a chance to publish attribution. Dispatching here
    // would POST an empty attribution body and race the main pipeline's POST.
    // The pipeline already includes the token via `awaitToken()`.
    if (_decideFuture != null) {
      _trace(() => '[MSQ.VEIL] token refresh skipped (decide in flight)');
      return;
    }
    // Also skip if we already have a good cached destination — the token was
    // shipped with the first POST that populated the cache, and re-POSTing
    // now only risks the server returning a stale/landing URL that
    // ledger.request would happily overwrite the cache with. The user then
    // opens the wrong page on the next cold-start.
    final cached = await vault.savedUrl();
    if (cached != null && cached.isNotEmpty && !vault.cachedUrlExpired) {
      _trace(() => '[MSQ.VEIL] token refresh skipped (cache still fresh)');
      return;
    }
    try {
      await courier.awaitSignals();
      await _requestConfig(token: token);
    } catch (_) {}
  }

  void _trace(String Function() message) {
    assert(() {
      // ignore: avoid_print
      print(message());
      return true;
    }());
  }
}
