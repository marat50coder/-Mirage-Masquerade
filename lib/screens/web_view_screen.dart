import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/palette.dart';
import '../widgets/ornate.dart';

/// A simple in-app browser used for legal / support pages so the player never
/// has to leave the app.
class MMWebViewScreen extends StatefulWidget {
  const MMWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<MMWebViewScreen> createState() => _MMWebViewScreenState();
}

class _MMWebViewScreenState extends State<MMWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MM.night)
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
          onPageFinished: (_) {
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
    return MMScreen(
      title: widget.title,
      background: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
        child: GoldPanel(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.white),
                WebViewWidget(controller: _controller),
                if (_loading)
                  const ColoredBox(
                    color: Color(0xCC0E0718),
                    child: Center(
                      child: CircularProgressIndicator(color: MM.goldBright),
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
            ),
          ),
        ),
      ),
    );
  }
}
