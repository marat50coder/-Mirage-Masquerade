import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../game/engine.dart';
import '../game/level.dart';
import 'ornate.dart';

/// Top counter panel: act, timer, level progress, attempts, combo and score.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.engine, required this.cfg, required this.onPause});

  final GameEngine engine;
  final LevelConfig cfg;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final best = Progress.instance.bestScore[cfg.index] ?? 0;
    final seconds = engine.remaining.ceil();
    final urgent = seconds <= 15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              RoundGlyphButton(
                icon: Icons.pause_circle_filled_rounded,
                size: 42,
                onTap: onPause,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACT ${cfg.number} · ${cfg.title.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MM.title(13),
                    ),
                    Text(
                      Levels.locationName(cfg.location).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MM.body(9, color: MM.parchment.withValues(alpha: 0.7))
                          .copyWith(letterSpacing: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TimerChip(seconds: seconds, urgent: urgent),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MM.night.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MM.gold.withValues(alpha: 0.36)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(A.suits[0], height: 14),
                    const SizedBox(width: 5),
                    Text('SYNC ${engine.round}/${cfg.roundsRequired}', style: MM.title(11)),
                    const Spacer(),
                    if (engine.combo > 1) ...[
                      Text('COMBO x${engine.combo}', style: MM.title(11, color: MM.emerald)),
                      const SizedBox(width: 10),
                    ],
                    Text('BEST $best', style: MM.body(10, color: MM.parchment.withValues(alpha: 0.8))),
                    const SizedBox(width: 10),
                    Text('${engine.score}', style: MM.title(13, color: MM.goldBright)),
                  ],
                ),
                const SizedBox(height: 6),
                _Bar(
                  value: engine.progress,
                  colors: const [MM.goldDeep, MM.gold, MM.goldBright],
                  height: 8,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var i = 0; i < cfg.lives; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Opacity(
                          opacity: i < engine.lives ? 1 : 0.2,
                          child: Image.asset(A.obj(0, 'mask'), height: 17),
                        ),
                      ),
                    if (engine.lives > cfg.lives)
                      for (var i = 0; i < engine.lives - cfg.lives; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Image.asset(A.obj(2, 'mask'), height: 17),
                        ),
                    const Spacer(),
                    _LockDots(engine: engine),
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            child: engine.chainStart == null
                ? const SizedBox(width: double.infinity, height: 6)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('RESONANCE WINDOW', style: MM.title(9, color: MM.goldBright)),
                            const Spacer(),
                            Text(
                              '${engine.chainLeft.toStringAsFixed(1)}s',
                              style: MM.title(9, color: MM.goldBright),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _Bar(
                          value: engine.chainWindow == 0 ? 0 : engine.chainLeft / engine.chainWindow,
                          colors: engine.chainLeft < 3
                              ? const [Color(0xFF8E1C1C), MM.danger, Color(0xFFFF9A9A)]
                              : const [Color(0xFF6E3BA8), MM.amethyst, Color(0xFFDCA8FF)],
                          height: 6,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LockDots extends StatelessWidget {
  const _LockDots({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(left: 5),
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: engine.worlds[i].locked
                  ? MM.goldBright
                  : MM.worldColors[i].withValues(alpha: 0.28),
              border: Border.all(
                color: engine.worlds[i].locked ? MM.gold : MM.worldColors[i],
                width: 1.4,
              ),
              boxShadow: engine.worlds[i].locked
                  ? [BoxShadow(color: MM.gold.withValues(alpha: 0.7), blurRadius: 8)]
                  : null,
            ),
          ),
      ],
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds, required this.urgent});
  final int seconds;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: MM.night.withValues(alpha: 0.75),
        border: Border.all(color: urgent ? MM.danger : MM.gold.withValues(alpha: 0.7), width: 1.5),
        boxShadow: urgent
            ? [BoxShadow(color: MM.danger.withValues(alpha: 0.5), blurRadius: 12)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.hourglass_bottom_rounded : Icons.hourglass_top_rounded,
            size: 15,
            color: urgent ? MM.danger : MM.gold,
          ),
          const SizedBox(width: 5),
          Text('$m:$s', style: MM.title(15, color: urgent ? MM.danger : MM.gold)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.colors, this.height = 8});

  final double value;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0) <= 0 ? 0.0001 : value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
