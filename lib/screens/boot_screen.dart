import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/image_bank.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../veil/core/veil_models.dart';
import '../veil/pages/herald_invite.dart';
import '../veil/pages/hush_screen.dart';
import '../veil/pages/mirror_hall.dart';
import '../veil/veil_director.dart';
import 'menu_screen.dart';

/// First screen of the app AND the veil routing point. Works in both
/// orientations; the game itself locks to portrait once the curtain rises.
/// While the loading art plays, [VeilDirector.decide] resolves organic (game)
/// vs attributed (WebView) vs offline.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, this.director});

  final VeilDirector? director;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  static const _minimumShow = Duration(milliseconds: 3200);

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  Animation<double> _fill = const AlwaysStoppedAnimation(0);
  double _value = 0;
  Timer? _creep;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _run();
  }

  @override
  void dispose() {
    _creep?.cancel();
    _shimmer.dispose();
    _bar.dispose();
    super.dispose();
  }

  void _to(double target, {Duration? duration}) {
    if (!mounted) return;
    if (target <= _value) return;
    _bar.duration = duration ?? const Duration(milliseconds: 520);
    _fill = Tween<double>(begin: _value, end: target).animate(
      CurvedAnimation(parent: _bar, curve: Curves.easeOutCubic),
    );
    _value = target;
    _bar.forward(from: 0);
    setState(() {});
  }

  /// While the pipeline is doing a long await (network, attribution, config
  /// POST), tick the bar forward by tiny amounts so the user never sees a
  /// frozen number. The creep never overshoots [ceiling]; when real progress
  /// arrives via `_to`, the bar jumps ahead and the creep continues from
  /// there.
  void _startCreep(double ceiling) {
    _creep?.cancel();
    _creep = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted) return;
      if (_value >= ceiling - 0.001) return;
      _to(
        (_value + 0.006).clamp(0.0, ceiling),
        duration: const Duration(milliseconds: 260),
      );
    });
  }

  void _stopCreep() {
    _creep?.cancel();
    _creep = null;
  }

  Future<void> _run() async {
    final started = DateTime.now();

    // Progress (settings/save data) is needed on both paths and is tiny.
    await Progress.instance.load();
    _to(0.08);

    // Resolve organic vs attributed FIRST — nothing white-part-specific is
    // preloaded until we know we're staying in the house.
    _startCreep(0.66);
    StageTarget target;
    try {
      target = await (widget.director?.decide(
            onProgress: (v) {
              _to((0.08 + v * 0.60).clamp(0.0, 0.68));
            },
          ) ??
          Future<StageTarget>.value(const HouseTarget()));
    } catch (_) {
      target = const HouseTarget();
    }
    _stopCreep();
    if (!mounted) return;

    if (target is MirrorTarget) {
      await _openMirror(target, started);
      return;
    }
    if (target is HushTarget) {
      await _openHush(started);
      return;
    }

    // House (organic / reviewer / gate closed) → warm the game.
    await Audio.instance.init();
    _to(0.72);

    _startCreep(0.86);
    final canvas = A.canvasImages();
    for (var i = 0; i < canvas.length; i++) {
      await ImageBank.instance.load(canvas[i]);
      if (i % 6 == 0) _to(0.72 + 0.14 * (i / canvas.length));
    }
    if (!mounted) return;
    final widgets = A.widgetImages();
    for (var i = 0; i < widgets.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(widgets[i]), context);
      if (i % 4 == 0) _to(0.86 + 0.08 * (i / widgets.length));
    }
    _stopCreep();
    _to(0.95);
    unawaited(Audio.instance.startMusic());

    final elapsed = DateTime.now().difference(started);
    final wait = _minimumShow - elapsed;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;

    _to(1.0, duration: const Duration(milliseconds: 620));
    await Future<void>.delayed(const Duration(milliseconds: 760));
    if (!mounted) return;

    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 620),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// Attributed path: optional push invite, then the partner WebView. A short
  /// splash floor is enough — no need to hold the full game-length minimum.
  Future<void> _openMirror(MirrorTarget target, DateTime started) async {
    final director = widget.director!;
    // Drive the bar to a full 100% and let the fill animation actually play
    // out before navigating, so the user visibly sees the load complete
    // instead of the bar snapping away mid-progress.
    _stopCreep();
    _to(1.0, duration: const Duration(milliseconds: 560));
    final elapsed = DateTime.now().difference(started);
    const floor = Duration(milliseconds: 1200);
    final remaining = floor - elapsed;
    const minFill = Duration(milliseconds: 720);
    await Future<void>.delayed(remaining > minFill ? remaining : minFill);
    if (!mounted) return;

    Widget mirror(BuildContext _) => MirrorHall(
          url: target.url,
          coldLaunch: target.coldLaunch,
          vault: director.vault,
          scout: director.scout,
          herald: director.herald,
          agent: director.agent,
        );

    final wantsInvite = director.vault.shouldShowPushInvite &&
        await director.herald.canOfferPermission();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: wantsInvite
            ? (_) => HeraldInvite(
                  vault: director.vault,
                  herald: director.herald,
                  nextBuilder: mirror,
                )
            : mirror,
      ),
    );
  }

  Future<void> _openHush(DateTime started) async {
    _stopCreep();
    final director = widget.director!;
    final elapsed = DateTime.now().difference(started);
    const floor = Duration(milliseconds: 700);
    if (elapsed < floor) await Future<void>.delayed(floor - elapsed);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HushScreen(
          scout: director.scout,
          retryBuilder: (_) => BootScreen(director: director),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MM.night,
      body: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight;
          final barWidth = landscape ? box.maxWidth * 0.52 : box.maxWidth * 0.80;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                landscape ? A.loadH : A.loadV,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: landscape ? 26 : 64),
                  child: SizedBox(
                    width: barWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LOADING',
                          textAlign: TextAlign.center,
                          style: MM.body(landscape ? 11 : 13, color: MM.goldBright).copyWith(
                            letterSpacing: 3.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: landscape ? 8 : 12),
                        AnimatedBuilder(
                          animation: Listenable.merge([_bar, _shimmer]),
                          builder: (context, _) {
                            final v = _fill.value.clamp(0.0, 1.0);
                            return _ProgressBar(
                              value: v,
                              shimmer: _shimmer.value,
                              height: landscape ? 20 : 26,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.shimmer, required this.height});

  final double value;
  final double shimmer;
  final double height;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height / 2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: r,
            color: const Color(0xFF150B22).withValues(alpha: 0.88),
            border: Border.all(color: MM.gold.withValues(alpha: 0.9), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: MM.gold.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: -4),
            ],
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              children: [
                // Left-to-right fill.
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value <= 0 ? 0.0001 : value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFB4611F), MM.gold, MM.goldBright, MM.gold],
                          stops: [0, 0.4, 0.72, 1],
                        ),
                      ),
                      child: CustomPaint(painter: _SheenPainter(shimmer)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value <= 0 ? 0.0001 : value,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: height * 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      fontSize: height * 0.52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: const Color(0xFFFFD447),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, 0)),
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 0)),
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, -1)),
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SheenPainter extends CustomPainter {
  _SheenPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (t * 1.6 - 0.3) * size.width;
    final w = max(size.width * 0.22, 26.0);
    canvas.drawRect(
      Rect.fromLTWH(x, 0, w, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x, 0, w, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _SheenPainter old) => old.t != t;
}
