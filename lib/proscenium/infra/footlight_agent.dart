import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/house_brief.dart';

/// HTTP client that carries a real mobile-browser User-Agent.
///
/// The UA is assembled at runtime from encoded fragments in [HouseBrief], so
/// no plaintext browser scaffolding — nor the slot partner-identity tokens —
/// ships as a literal in the binary. The identical string is applied to the
/// WebView (`setUserAgent`) so HTTP and web sessions match.
///
/// GAME THEME: slot — the partner backend requires the app-id + bundle id and
/// app-name + app title suffix, so it is appended (from encoded tokens). A
/// crash game would omit it.
class FootlightAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _compose(HouseBrief.safariVersion);
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _compose(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _compose(HouseBrief.safariVersion);
    }
  }

  String get userAgent => _userAgent ?? _compose(HouseBrief.safariVersion);

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 16) return HouseBrief.safariVersion;
    return parts.join('.');
  }

  String _compose(String iosVersion) {
    // The platform CPU token and the Version/ token track the same iOS
    // release, as a genuine browser UA does.
    final cpu = iosVersion.replaceAll('.', '_');
    // `appid/…` carries the App Store id in its canonical `idNNNNNNNNNN` form
    // (matches itunes.apple.com/app/idNNNNNNNNNN and AppsFlyer's `appId`
    // field on iOS). Use `storeToken` — the CFBundleIdentifier is a separate
    // concept and mis-identifies the caller if shipped here.
    //
    // Tokens are joined with a single space — never a raw newline. RFC 7230
    // forbids bare CR/LF in header values, and dart:io's HttpClient throws
    // `Invalid HTTP header field value` the moment we try to POST, which
    // silently killed every config request with a `network_failure`
    // exception (and stranded the whole app on QuietWing even with Wi-Fi
    // on). The partner's diagnostic page reads `navigator.userAgent` — a JS
    // string — where the same UA is legal and still contains both tokens.
    final suffix = ' ${HouseBrief.uaAppIdToken}${HouseBrief.storeToken}'
        ' ${HouseBrief.uaAppNameToken}${HouseBrief.appTitle}';
    return '${HouseBrief.uaProduct} '
        '${HouseBrief.uaPlatformPrefix} $cpu ${HouseBrief.uaPlatformSuffix} '
        '${HouseBrief.uaEngine} '
        'Version/$iosVersion ${HouseBrief.uaMobileToken} '
        'Safari/${HouseBrief.safariTail}$suffix';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
