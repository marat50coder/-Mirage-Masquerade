import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/veil_config.dart';
import '../infra/herald_hub.dart';
import '../infra/masque_vault.dart';

/// Push opt-in promo shown once before the mirror on first attributed entry.
class HeraldInvite extends StatefulWidget {
  const HeraldInvite({
    super.key,
    required this.vault,
    required this.herald,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final MasqueVault vault;
  final HeraldHub herald;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<HeraldInvite> createState() => _HeraldInviteState();
}

class _HeraldInviteState extends State<HeraldInvite> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The boot screen locks portrait before routing here; re-enable landscape
    // so this screen rotates like the WebView that follows it.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.herald.askPermission();
    final token = widget.herald.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        VeilConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.nextBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background =
        landscape ? 'assets/veil/permit_h.webp' : 'assets/veil/permit_v.webp';
    final width = landscape
        ? (media.size.width * 0.336).clamp(256.0, 448.0)
        : (media.size.width * 0.64).clamp(224.0, 352.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _VeilButton(
                  width: width,
                  height: landscape ? 53 : 59,
                  fontSize: landscape ? 18 : 20,
                  label: 'Allow',
                  emphasized: true,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 10 : 13),
                _VeilButton(
                  width: width * 0.9,
                  height: landscape ? 46 : 51,
                  fontSize: landscape ? 16 : 18,
                  label: 'Not now',
                  emphasized: false,
                  busy: false,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VeilButton extends StatelessWidget {
  const _VeilButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFF7D774), Color(0xFFC8912F)]
                : const <Color>[Color(0xFF6D3BB0), Color(0xFF3A1C63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: emphasized ? const Color(0xFF5A3B10) : const Color(0xFF2A1247),
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF3A1D05),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: emphasized
                            ? const Color(0xFF3D2408)
                            : const Color(0xFFF3E9FF),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
