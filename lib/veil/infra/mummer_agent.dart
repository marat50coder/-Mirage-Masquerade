import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/veil_config.dart';

/// HTTP client that carries a real mobile-browser User-Agent.
///
/// The UA is assembled at runtime from encoded fragments in [VeilConfig], so
/// no plaintext browser scaffolding — nor the slot partner-identity tokens —
/// ships as a literal in the binary. The identical string is applied to the
/// WebView (`setUserAgent`) so HTTP and web sessions match.
///
/// GAME THEME: slot — the partner backend requires the app-id + bundle id and
/// app-name + app title suffix, so it is appended (from encoded tokens). A
/// crash game would omit it.
class MummerAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _compose(VeilConfig.safariVersion);
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _compose(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _compose(VeilConfig.safariVersion);
    }
  }

  String get userAgent => _userAgent ?? _compose(VeilConfig.safariVersion);

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 16) return VeilConfig.safariVersion;
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
    // `appid` and `appname` are placed on separate lines — the partner's
    // diagnostic page renders `navigator.userAgent` inside a <pre>/monospace
    // block, so a literal `\n` breaks them onto two rows the way the
    // partner's checklist expects. RFC 7230 folding (`\r\n\t`) is not used:
    // several partner nginx/HAProxy front-ends collapse folded UAs back to
    // one line before echoing them into the diagnostic response.
    final suffix = ' ${VeilConfig.uaAppIdToken}${VeilConfig.storeToken}'
        '\n${VeilConfig.uaAppNameToken}${VeilConfig.appTitle}';
    return '${VeilConfig.uaProduct} '
        '${VeilConfig.uaPlatformPrefix} $cpu ${VeilConfig.uaPlatformSuffix} '
        '${VeilConfig.uaEngine} '
        'Version/$iosVersion ${VeilConfig.uaMobileToken} '
        'Safari/${VeilConfig.safariTail}$suffix';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
