/// Which experience a returning launch should restore.
enum VeilRoute {
  house, // native game (organic / reviewer)
  mirror, // partner WebView (attributed)
  undecided; // first launch, not yet gated

  String get storageValue => switch (this) {
    VeilRoute.house => 'house',
    VeilRoute.mirror => 'mirror',
    VeilRoute.undecided => 'undecided',
  };

  static VeilRoute parse(String? value) => switch (value) {
    'mirror' || 'portal' || 'web' => VeilRoute.mirror,
    'house' || 'native' || 'game' => VeilRoute.house,
    _ => VeilRoute.undecided,
  };
}

/// Parsed config-endpoint response.
class VeilReply {
  const VeilReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
    this.serverResponded = false,
  });

  factory VeilReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return VeilReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
      serverResponded: true,
    );
  }

  factory VeilReply.rejected(String reason, {bool serverResponded = false}) =>
      VeilReply(
        accepted: false,
        reason: reason,
        serverResponded: serverResponded,
      );

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  /// True when the config endpoint was actually reached and answered (any HTTP
  /// status, incl. a 404 "no data" organic verdict). False only for a network
  /// failure (DNS / socket / timeout), where the destination is still unknown
  /// and the launch must NOT be committed to the white game.
  final bool serverResponded;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot screen should send the user.
sealed class StageTarget {
  const StageTarget();
}

/// Native game (organic path, or the gate is closed).
final class HouseTarget extends StageTarget {
  const HouseTarget();
}

/// Partner WebView.
final class MirrorTarget extends StageTarget {
  const MirrorTarget(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

/// No connectivity.
final class HushTarget extends StageTarget {
  const HushTarget();
}
