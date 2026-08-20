import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/herald_hub.dart';
import '../infra/masque_vault.dart';
import '../infra/mummer_agent.dart';
import '../infra/signal_scout.dart';
import 'hush_screen.dart';

/// Full-screen partner WebView. Inline media autoplay is handled by the
/// WKWebView creation params (not a JS injection), leaving a smaller,
/// project-unique injection set.
class MirrorHall extends StatefulWidget {
  const MirrorHall({
    super.key,
    required this.url,
    required this.vault,
    required this.scout,
    required this.herald,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final MasqueVault vault;
  final SignalScout scout;
  final HeraldHub herald;
  final MummerAgent agent;
  final bool coldLaunch;

  @override
  State<MirrorHall> createState() => _MirrorHallState();
}

class _MirrorHallState extends State<MirrorHall> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  // Only flip to Hush on a `[none]` connectivity event AFTER we've observed
  // at least one online event first. iOS' cold-start reachability listener
  // frequently emits a spurious `[none]` (or empty list) as its FIRST event
  // — before the native stack has finished initializing — even while Wi-Fi
  // is on and the WebView is happily loading. Trusting that first event
  // would strand every mirror entry on HushScreen. Once we've *seen* a real
  // online interface, any subsequent transition to `[none]` is genuine and
  // gets flipped immediately.
  bool _sawOnline = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  static const int _maxRedirectRetries = 2;
  static const Duration _coldSettle = Duration(milliseconds: 240);
  static const Duration _postFinishResize = Duration(milliseconds: 1050);
  static const List<int> _reflowDelays = <int>[55, 190, 360, 610, 900];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.herald.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    // Prime the "online seen" latch from a bounded snapshot so a user who
    // enters the mirror already on Wi-Fi can flip to Hush the instant they
    // toggle it off, without having to wait for the plugin to first emit a
    // corroborating online event.
    _primeConnectivityLatch();
    _networkSubscription = Connectivity().onConnectivityChanged.listen((
      states,
    ) {
      if (!mounted) return;
      final anyOnline = states.any(
        (state) =>
            state != ConnectivityResult.none &&
            state != ConnectivityResult.other,
      );
      if (anyOnline) {
        _sawOnline = true;
        return;
      }
      // `[none]` verdict — but only trust it once we've previously observed
      // a real online interface (see `_sawOnline` comment). Empty list is
      // treated as "unknown" and ignored too.
      if (states.isEmpty || !_sawOnline) return;
      if (!states.every((state) => state == ConnectivityResult.none)) return;
      _goOffline();
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive mode settle in the ACTUAL orientation before WKWebView
    // measures its viewport — no landscape nudge (that made cold-start push
    // links open sideways then flip). Residual stretch is fixed post-load.
    await Future<void>.delayed(_coldSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(_reflowDelays);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) => _lastMainUrl = url,
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installInsetGuard();
        _installZoomLock();
        _installTapPolish();
        _installKeyboardLift();
        _installFontFloor();
        Future<void>.delayed(_postFinishResize, () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installInsetGuard();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return; // cancelled by a new nav
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop &&
            _lastMainUrl != null &&
            _redirectAttempts < _maxRedirectRetries) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        // Scheme gate (NOT a host allowlist — the partner host may change via
        // config after release). Hand off everything else to the OS.
        if (<String>{'http', 'https', 'about', 'data', 'blob'}
            .contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _primeConnectivityLatch() async {
    try {
      final status = await Connectivity().checkConnectivity().timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => const <ConnectivityResult>[],
      );
      if (!mounted) return;
      if (status.any(
        (state) =>
            state != ConnectivityResult.none &&
            state != ConnectivityResult.other,
      )) {
        _sawOnline = true;
      }
    } catch (_) {}
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.scout.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HushScreen(
          scout: widget.scout,
          retryBuilder: (_) => MirrorHall(
            url: current,
            vault: widget.vault,
            scout: widget.scout,
            herald: widget.herald,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  // ── JS injections (project-unique sentinels, reduced set) ──────────────

  void _installInsetGuard() {
    _controller.runJavaScript(r'''
(() => {
  const win = window;
  if (win.__msqInsetVeil) return;
  win.__msqInsetVeil = true;
  const tag = 'msq-inset-veil';
  const css = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}'
  ].join('');
  const keyboardUp = () => {
    const vv = win.visualViewport;
    return !!vv && vv.height < win.innerHeight * 0.75;
  };
  const paint = () => {
    if (keyboardUp()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(meta);
    } else {
      const trimmed = (meta.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.content = `${trimmed}${trimmed ? ', ' : ''}viewport-fit=contain`;
    }
    let sheet = document.getElementById(tag);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = tag;
      host.appendChild(sheet);
    }
    sheet.textContent = css;
  };
  const queue = () => { win.setTimeout(paint, 150); win.setTimeout(paint, 700); };
  ['pushState', 'replaceState'].forEach((fn) => {
    const orig = history[fn];
    history[fn] = function(...a) { const r = orig.apply(this, a); queue(); return r; };
  });
  win.addEventListener('popstate', queue);
  paint();
  win.setInterval(paint, 3300);
})();
''');
  }

  void _installZoomLock() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__msqZoomVeil) return;
  window.__msqZoomVeil = true;
  const relock = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };
  relock();
  const swallow = (e) => e.preventDefault();
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((t) =>
    document.addEventListener(t, swallow, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTap = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTap <= 340) e.preventDefault();
    lastTap = now;
  }, {passive: false});
  ['pushState', 'replaceState'].forEach((fn) => {
    const orig = history[fn];
    history[fn] = function(...a) { const r = orig.apply(this, a); setTimeout(relock, 190); return r; };
  });
  window.addEventListener('popstate', () => setTimeout(relock, 190));
})();
''');
  }

  void _installTapPolish() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__msqTapVeil) return;
  window.__msqTapVeil = true;
  const s = document.createElement('style');
  s.id = 'msq-tap-veil';
  s.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(s);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__msqLiftVeil) return;
  window.__msqLiftVeil = true;
  const editable = (n) => !!n && (
    n.matches?.('input, textarea, select, [contenteditable="true"]')
  );
  const reveal = () => {
    const a = document.activeElement;
    if (!editable(a)) return;
    a.scrollIntoView({behavior: 'auto', block: 'nearest'});
  };
  document.addEventListener('focusin', (e) => {
    if (editable(e.target)) window.setTimeout(reveal, 300);
  }, true);
})();
''');
  }

  void _installFontFloor() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(() => {
  if (window.__msqFontVeil) return;
  window.__msqFontVeil = true;
  const s = document.createElement('style');
  s.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(s);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.herald.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
