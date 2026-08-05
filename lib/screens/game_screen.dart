import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../game/engine.dart';
import '../game/level.dart';
import '../game/stage_painter.dart';
import '../widgets/game_hud.dart';
import '../widgets/ornate.dart';
import '../widgets/result_dialogs.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late LevelConfig cfg = Levels.at(widget.levelIndex);
  late GameEngine engine;
  late final Ticker _ticker;

  late final AnimationController _shift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  Duration _last = Duration.zero;
  bool _paused = false;
  bool _resultShown = false;
  int _shiftDirection = 1;
  int _startSeconds = 0;

  @override
  void initState() {
    super.initState();
    engine = GameEngine(cfg)..addListener(_onEngine);
    _startSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shift.dispose();
    engine.removeListener(_onEngine);
    engine.dispose();
    super.dispose();
  }

  /// The engine ticks every frame, so the widget tree stays out of its way and
  /// only the pieces wrapped in [AnimatedBuilder] repaint.
  void _onEngine() {
    if (!mounted || _resultShown) return;
    if (engine.state == RunState.won || engine.state == RunState.lost) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_paused || dt <= 0) return;
    engine.update(dt);
  }

  // ------------------------------------------------------------------ actions

  void _switchTo(int index) {
    if (index == engine.currentWorld || !engine.isRunning) return;
    _shiftDirection = index > engine.currentWorld ? 1 : -1;
    if ((engine.currentWorld - index).abs() == 2) _shiftDirection *= -1;
    engine.switchWorld(index);
    Audio.instance
      ..play(Sfx.realitySwitch, volume: 0.6)
      ..tapFeedback();
    _shift.forward(from: 0);
  }

  void _swipe(int delta) {
    if (!engine.isRunning) return;
    _switchTo((engine.currentWorld + delta + 3) % 3);
  }

  void _sync() {
    if (engine.state != RunState.playing) return;
    final wasLocked = engine.lockedCount;
    final ok = engine.attemptSync();
    if (ok) {
      if (engine.lockedCount > wasLocked && engine.state != RunState.merging) {
        Audio.instance
          ..play(Sfx.objectMatch)
          ..impact();
        _shift.forward(from: 0);
      } else if (engine.state == RunState.merging) {
        Audio.instance.play(Sfx.combo);
      }
    } else {
      Audio.instance
        ..play(Sfx.levelFailed, volume: 0.5)
        ..heavy();
    }
  }

  void _useBooster(Booster b) {
    final p = Progress.instance;
    if ((p.boosters[b] ?? 0) <= 0 || !engine.isRunning) {
      Audio.instance.play(Sfx.back);
      return;
    }
    p.consumeBooster(b);
    switch (b) {
      case Booster.reveal:
        engine.useReveal();
      case Booster.slow:
        engine.useSlow();
      case Booster.life:
        engine.useExtraLife();
    }
    Audio.instance
      ..play(Sfx.reward)
      ..impact();
    setState(() {});
  }

  Future<void> _pause() async {
    setState(() => _paused = true);
    Audio.instance.play(Sfx.popup);
    final action = await showPauseDialog(context, cfg);
    if (!mounted) return;
    switch (action) {
      case PauseAction.resume:
        setState(() => _paused = false);
      case PauseAction.restart:
        _restart();
      case PauseAction.quit:
        Navigator.of(context).pop();
      case null:
        setState(() => _paused = false);
    }
  }

  void _restart() {
    engine.removeListener(_onEngine);
    engine.dispose();
    setState(() {
      engine = GameEngine(cfg)..addListener(_onEngine);
      _resultShown = false;
      _paused = false;
      _startSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });
  }

  Future<void> _showResult() async {
    final won = engine.state == RunState.won;
    final stars = engine.starsEarned;
    final p = Progress.instance;
    final previousBest = p.bestScore[cfg.index] ?? 0;
    final spent = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _startSeconds;

    p.recordRun(
      levelIndex: cfg.index,
      won: won,
      score: engine.score,
      starsEarned: stars,
      syncs: engine.syncs,
      perfects: engine.perfects,
      objectsMerged: engine.objectsMerged,
      switches: engine.switches,
      combo: engine.maxCombo,
      secondsLeft: engine.remaining.floor(),
      secondsSpent: spent,
    );

    Audio.instance.play(won ? Sfx.achievement : Sfx.levelFailed);
    setState(() => _paused = true);

    final action = await showResultDialog(
      context,
      cfg: cfg,
      won: won,
      stars: stars,
      score: engine.score,
      previousBest: previousBest,
      syncs: engine.syncs,
      perfects: engine.perfects,
      maxCombo: engine.maxCombo,
      secondsLeft: engine.remaining.floor(),
      hasNext: cfg.index + 1 < Levels.count,
    );
    if (!mounted) return;
    switch (action) {
      case ResultAction.retry:
        _restart();
      case ResultAction.next:
        setState(() {
          cfg = Levels.at(cfg.index + 1);
        });
        _restart();
      case ResultAction.menu:
      case null:
        Navigator.of(context).pop();
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_paused) _pause();
      },
      child: Scaffold(
        backgroundColor: MM.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _StageBackground(location: cfg.location, engine: engine, shift: _shift),
            SafeArea(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: engine,
                    builder: (context, _) => GameHud(engine: engine, cfg: cfg, onPause: _pause),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v.abs() < 180) return;
                        _swipe(v < 0 ? 1 : -1);
                      },
                      onTap: _sync,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _shift,
                              builder: (context, child) {
                                final t = Curves.easeOutCubic.transform(_shift.value);
                                return Opacity(
                                  opacity: 0.25 + 0.75 * t,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.0012)
                                      ..rotateY((1 - t) * 0.5 * -_shiftDirection)
                                      ..scaleByDouble(
                                        0.9 + 0.1 * t,
                                        0.9 + 0.1 * t,
                                        1,
                                        1,
                                      ),
                                    child: child,
                                  ),
                                );
                              },
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: StagePainter(
                                    engine: engine,
                                    repaint: engine,
                                    showTrails: p.hintsOn,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: engine,
                                builder: (context, _) => Stack(
                                  children: [
                                    Positioned.fill(child: _FlashLayer(engine: engine)),
                                    if (engine.state == RunState.intro)
                                      Positioned.fill(
                                        child: _IntroOverlay(engine: engine, cfg: cfg),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: engine,
                    builder: (context, _) => _ControlDeck(
                      engine: engine,
                      accent: MM.worldColors[engine.currentWorld],
                      onSelectWorld: _switchTo,
                      onSync: _sync,
                      onBooster: _useBooster,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stage backdrop that takes on the hue of the reality you are standing in.
/// The photograph itself never rebuilds; only the tint above it does.
class _StageBackground extends StatelessWidget {
  const _StageBackground({
    required this.location,
    required this.engine,
    required this.shift,
  });

  final int location;
  final GameEngine engine;
  final Animation<double> shift;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Image.asset(A.bg(location), fit: BoxFit.cover, alignment: Alignment.center),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([engine, shift]),
          builder: (context, _) {
            final color = MM.worldColors[engine.currentWorld];
            final flare = 1 - Curves.easeOutCubic.transform(shift.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MM.night.withValues(alpha: 0.74),
                    Color.lerp(MM.night, color, 0.22 + 0.2 * flare)!.withValues(alpha: 0.52),
                    MM.night.withValues(alpha: 0.80),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FlashLayer extends StatelessWidget {
  const _FlashLayer({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    if (engine.flash == FlashKind.none || engine.flashT <= 0) return const SizedBox.shrink();
    final a = (engine.flashT / 1.0).clamp(0.0, 1.0);
    final color = switch (engine.flash) {
      FlashKind.missed => MM.danger,
      FlashKind.chainLost => const Color(0xFFFF9F43),
      FlashKind.locked => MM.worldColors[engine.currentWorld],
      FlashKind.merged => MM.goldBright,
      FlashKind.none => Colors.transparent,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [Colors.transparent, color.withValues(alpha: 0.30 * a)],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.55),
          child: Opacity(
            opacity: a,
            child: Transform.scale(
              scale: 1 + (1 - a) * 0.22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: MM.night.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.9), width: 1.6),
                ),
                child: Text(
                  engine.flashText,
                  textAlign: TextAlign.center,
                  style: MM.title(16, color: color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({required this.engine, required this.cfg});
  final GameEngine engine;
  final LevelConfig cfg;

  @override
  Widget build(BuildContext context) {
    final t = (engine.introLeft / 2.4).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Container(
        color: MM.night.withValues(alpha: 0.62 * t),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Opacity(
          opacity: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ACT ${cfg.number}', style: MM.title(15, color: MM.parchment)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(cfg.title.toUpperCase(), maxLines: 1, style: MM.title(30)),
              ),
              const SizedBox(height: 10),
              Image.asset(A.ornament, height: 26),
              const SizedBox(height: 14),
              Text(
                'Lock all three realities\nwithin the resonance window',
                textAlign: TextAlign.center,
                style: MM.body(14),
              ),
              if (cfg.modifiers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final m in cfg.modifiers)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MM.velvet.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MM.amethyst.withValues(alpha: 0.7)),
                        ),
                        child: Text(m.toUpperCase(), style: MM.body(10, color: MM.parchment)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom deck: reality selector, the big SYNC dial and the booster row.
class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.engine,
    required this.accent,
    required this.onSelectWorld,
    required this.onSync,
    required this.onBooster,
  });

  final GameEngine engine;
  final Color accent;
  final ValueChanged<int> onSelectWorld;
  final VoidCallback onSync;
  final ValueChanged<Booster> onBooster;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final closeness = engine.isRunning
        ? engine.worlds[engine.currentWorld].closeness(engine.t, engine.cfg.tolerance)
        : 0.0;
    final locked = engine.worlds[engine.currentWorld].locked;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, MM.night.withValues(alpha: 0.86)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: _WorldTab(
                      index: i,
                      selected: i == engine.currentWorld,
                      locked: engine.worlds[i].locked,
                      mirrored: engine.worlds[i].mirrored,
                      onTap: () => onSelectWorld(i),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BoosterButton(
                icon: Icons.visibility_rounded,
                count: p.boosters[Booster.reveal] ?? 0,
                active: engine.revealActive,
                color: const Color(0xFF54B9F0),
                onTap: () => onBooster(Booster.reveal),
              ),
              const Spacer(),
              _SyncDial(
                accent: accent,
                closeness: closeness,
                locked: locked,
                enabled: engine.state == RunState.playing,
                onTap: onSync,
              ),
              const Spacer(),
              _BoosterButton(
                icon: Icons.hourglass_bottom_rounded,
                count: p.boosters[Booster.slow] ?? 0,
                active: engine.slowActive,
                color: MM.emerald,
                onTap: () => onBooster(Booster.slow),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              locked
                  ? 'SWIPE TO THE NEXT REALITY'
                  : 'SWIPE TO SHIFT REALITY · TAP TO LOCK',
              maxLines: 1,
              style: MM.body(10, color: MM.parchment.withValues(alpha: 0.75))
                  .copyWith(letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldTab extends StatelessWidget {
  const _WorldTab({
    required this.index,
    required this.selected,
    required this.locked,
    required this.mirrored,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool locked;
  final bool mirrored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MM.worldColors[index];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [Color.lerp(c, Colors.white, 0.28)!, c]
                : [MM.velvet.withValues(alpha: 0.85), MM.deep.withValues(alpha: 0.9)],
          ),
          border: Border.all(
            color: locked ? MM.goldBright : c.withValues(alpha: selected ? 1 : 0.55),
            width: locked ? 2.4 : 1.6,
          ),
          boxShadow: selected
              ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: -2)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.lock_rounded, size: 15, color: MM.goldBright),
              ),
            Text(
              MMRoman.of(index),
              style: MM.title(17, color: selected ? Colors.white : c),
            ),
            if (mirrored)
              const Padding(
                padding: EdgeInsets.only(left: 5),
                child: Icon(Icons.flip_rounded, size: 14, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncDial extends StatelessWidget {
  const _SyncDial({
    required this.accent,
    required this.closeness,
    required this.locked,
    required this.enabled,
    required this.onTap,
  });

  final Color accent;
  final double closeness;
  final bool locked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 108.0;
    final ready = closeness >= 0.999;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(size, size),
              painter: _DialPainter(
                value: closeness,
                color: locked ? MM.goldBright : accent,
                ready: ready || locked,
              ),
            ),
            Container(
              width: size * 0.70,
              height: size * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: locked
                      ? [MM.goldBright, MM.gold, MM.goldDeep]
                      : ready
                      ? [Color.lerp(accent, Colors.white, 0.5)!, accent]
                      : [MM.velvetLight, MM.deep],
                ),
                border: Border.all(
                  color: locked ? MM.goldBright : accent.withValues(alpha: 0.9),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (locked ? MM.gold : accent).withValues(alpha: ready || locked ? 0.65 : 0.22),
                    blurRadius: ready || locked ? 26 : 12,
                    spreadRadius: ready || locked ? 1 : -2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  locked ? 'LOCKED' : 'SYNC',
                  style: MM.title(locked ? 14 : 18,
                      color: locked
                          ? const Color(0xFF3A1D05)
                          : ready
                          ? Colors.white
                          : MM.parchment),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.value, required this.color, required this.ready});

  final double value;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = MM.deep.withValues(alpha: 0.85),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6
        ..color = color
        ..maskFilter = ready ? const MaskFilter.blur(BlurStyle.solid, 4) : null,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.value != value || old.color != color || old.ready != ready;
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Badged(
        count: count,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [Color.lerp(color, Colors.white, 0.4)!, color]
                  : [MM.velvetLight, MM.deep],
            ),
            border: Border.all(
              color: count > 0 ? color.withValues(alpha: 0.9) : Colors.white24,
              width: 1.8,
            ),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: -2)]
                : null,
          ),
          child: Icon(
            icon,
            color: count > 0 || active ? Colors.white : Colors.white38,
            size: 26,
          ),
        ),
      ),
    );
  }
}
