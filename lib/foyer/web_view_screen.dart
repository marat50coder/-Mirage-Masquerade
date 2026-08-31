import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../studio/assets.dart';
import '../studio/audio.dart';
import '../studio/palette.dart';
import '../ornament/ornate.dart';

/// A simple in-app browser used for legal / support pages so the player never
/// has to leave the app.
///
/// [fullScreen] renders the page edge-to-edge with only a floating back button
/// on top — used for interactive pages like the support form that need every
/// pixel. The default framed layout keeps the ornate theatre header.
class MMWebViewScreen extends StatefulWidget {
  const MMWebViewScreen({
    super.key,
    required this.title,
    required this.url,
    this.fullScreen = false,
    this.stretchContent = false,
  });

  final String title;
  final String url;
  final bool fullScreen;

  /// When `true`, injects CSS on load that makes the page fill the entire
  /// viewport (used for the Support form which naturally sits in a small
  /// desktop-style card in the middle of a big blank background).
  final bool stretchContent;

  @override
  State<MMWebViewScreen> createState() => _MMWebViewScreenState();
}

/// Inline CSS + viewport meta injected once the page is loaded. Grows the
/// single centred card so it uses the whole screen and stays readable.
const _stretchScript = r'''
(function fitSupportCard() {
  var head = document.head || document.documentElement;
  var meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'viewport';
    head.appendChild(meta);
  }
  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  var sheet = document.createElement('style');
  sheet.appendChild(document.createTextNode(
    'html,body{margin:0!important;padding:0!important;height:100%!important;background:#fff!important;}'
    + 'body{display:flex!important;align-items:stretch!important;justify-content:center!important;padding:14px!important;box-sizing:border-box!important;}'
    + 'body>*{width:100%!important;max-width:640px!important;box-sizing:border-box!important;}'
    + 'form,.card,.container,.support,.box,.content,main,section{width:100%!important;max-width:640px!important;box-sizing:border-box!important;padding:22px!important;margin:0 auto!important;border-radius:16px!important;}'
    + 'input,textarea{font-size:17px!important;padding:12px!important;box-sizing:border-box!important;width:100%!important;}'
    + 'textarea{min-height:220px!important;}'
    + 'button,input[type="submit"]{font-size:17px!important;padding:14px!important;width:100%!important;}'
  ));
  head.appendChild(sheet);
})();
''';

class _MMWebViewScreenState extends State<MMWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // White so pages that don't set their own background still render dark
      // text on light instead of dark-on-dark.
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _failed = false;
              });
            }
          },
          onPageFinished: (_) async {
            if (widget.stretchContent) {
              try {
                await _controller.runJavaScript(_stretchScript);
              } catch (_) {}
            }
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // iOS reports every subresource failure through here; only surface a
            // full-page error when the main frame itself failed.
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) return _buildFullScreen(context);
    return _buildFramed();
  }

  Widget _buildFramed() {
    return MMScreen(
      title: widget.title,
      background: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
        child: GoldPanel(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _webBody(rounded: true),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context) {
    // Dark status-bar icons since the page is on white.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _webBody(rounded: false),
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  radius: 26,
                  onTap: () {
                    Audio.instance
                      ..play(Sfx.back)
                      ..tapFeedback();
                    Navigator.of(context).maybePop();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: MM.night.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(color: MM.gold.withValues(alpha: 0.8), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: MM.goldBright,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webBody({required bool rounded}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        WebViewWidget(controller: _controller),
        if (_loading)
          const ColoredBox(
            color: Color(0xF2FFFFFF),
            child: Center(
              child: CircularProgressIndicator(color: MM.goldDeep),
            ),
          ),
        if (_failed)
          Container(
            color: MM.night,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: MM.gold, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load the page.',
                    style: MM.title(15, color: MM.parchment),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: MM.body(12, color: MM.parchment.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 18),
                  GoldButton(
                    label: 'RETRY',
                    icon: Icons.refresh_rounded,
                    height: 46,
                    fontSize: 14,
                    onTap: _reload,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
