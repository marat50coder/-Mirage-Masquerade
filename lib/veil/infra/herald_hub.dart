import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'masque_vault.dart';

@pragma('vm:entry-point')
Future<void> veilBackgroundMessage(RemoteMessage _) async {}

/// FCM / APNs wrapper: token warm-up, foreground presentation, and pulling a
/// destination URL out of a push payload.
class HeraldHub {
  HeraldHub(this._vault, {required this.enabled});

  final MasqueVault _vault;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  Future<void>? _initialTokenFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
    final initialUrl = initial == null ? null : _extract(initial.data);
    if (initialUrl != null) await _vault.stashPushUrl(initialUrl);

    FirebaseMessaging.onBackgroundMessage(veilBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _extract(message.data);
      if (url == null) return;
      final callback = onDestination;
      if (callback == null) {
        _vault.stashPushUrl(url);
      } else {
        callback(url);
      }
    });
    // APNs handshake is kicked off in the background. Before the very first
    // notification permission grant, `_waitForApns` just polls a nil token
    // (Firebase can't register with APNs without permission) — awaiting it
    // inline would tack ~3.3 s of dead time onto every first launch for no
    // network benefit. The director calls `awaitToken()` later with its own
    // bounded budget just before the config POST.
    _initialTokenFuture = _acquireInitialToken();
    unawaited(_initialTokenFuture);
  }

  Future<void> _acquireInitialToken() async {
    final messaging = _messaging;
    if (messaging == null) return;
    await _waitForApns();
    try {
      _token = await messaging.getToken();
    } catch (_) {}
  }

  /// Blocks up to [timeout] for the initial FCM token to arrive. Returns the
  /// token (may still be null if APNs never coughed one up — that's fine, the
  /// config POST just goes without `push_token`).
  Future<String?> awaitToken({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final existing = _token;
    if (existing != null && existing.isNotEmpty) return existing;
    final pending = _initialTokenFuture;
    if (pending == null) return _token;
    try {
      await pending.timeout(timeout, onTimeout: () {});
    } catch (_) {}
    return _token;
  }

  String? _extract(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApns({int attempts = 7}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 470));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    // Lazily boot when the director's fast-path returned a cached mirror URL
    // and never ran `herald.boot()`. Without this, `_messaging` stays null on
    // every return-user launch and the answer is a permanent `false`, which
    // suppressed the HeraldInvite re-show even after the snooze window
    // (VeilConfig.pushSnoozeSeconds) had elapsed.
    try {
      await boot();
    } catch (_) {}
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 12);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
