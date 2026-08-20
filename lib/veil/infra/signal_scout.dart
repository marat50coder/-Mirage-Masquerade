import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity + reachability checks for the veil pipeline.
class SignalScout {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Strict "truly offline" verdict — only returns `true` when the plugin
  /// EXPLICITLY reports a non-empty list of exclusively `[none]` interfaces
  /// (airplane mode / Wi-Fi off / no cellular). The empty-list cold-start
  /// case iOS produces before the reachability listener registers is
  /// deliberately treated as "unknown" so we don't strand a genuinely
  /// online first-launch on HushScreen — that path continues into the
  /// pipeline where the config POST is the final arbiter.
  Future<bool> isConfirmedOffline({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    try {
      final status = await _connectivity.checkConnectivity().timeout(
        timeout,
        onTimeout: () => const <ConnectivityResult>[],
      );
      if (status.isEmpty) return false;
      return status.every((value) => value == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Time-boxed DNS lookup against neutral hosts (never our own domain, so a
  /// VPN or an un-propagated app domain can't produce a false offline).
  ///
  /// Does NOT gate on `hasInterface()` on purpose: on iOS the very first
  /// `checkConnectivity()` call after a cold-start install can return an
  /// empty list or `[none]` before the native reachability listener has
  /// registered, which would produce a spurious HushTarget on the first
  /// launch even when Wi-Fi is on. DNS resolution is the authoritative
  /// answer — if the lookup succeeds we have connectivity, regardless of
  /// what the plugin has cached so far.
  Future<bool> canReachNetwork() async {
    for (final host in const <String>['cloudflare.com', 'apple.com']) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 3));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // fall through to the next host
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
