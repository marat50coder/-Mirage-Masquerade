import 'dart:math';

import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../game/level.dart';
import 'ornate.dart';

enum PauseAction { resume, restart, quit }

enum ResultAction { retry, next, menu }

Future<PauseAction?> showPauseDialog(BuildContext context, LevelConfig cfg) {
  return showGeneralDialog<PauseAction>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: GoldPanel(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flourish(text: 'INTERMISSION', size: 22),
              const SizedBox(height: 6),
              Text(
                'Act ${cfg.number} · ${cfg.title}',
                textAlign: TextAlign.center,
                style: MM.body(13),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'RESUME',
                icon: Icons.play_arrow_rounded,
                onTap: () => Navigator.of(context).pop(PauseAction.resume),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'RESTART ACT',
                color: MM.amethyst,
                height: 52,
                fontSize: 16,
                icon: Icons.refresh_rounded,
                onTap: () => Navigator.of(context).pop(PauseAction.restart),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'LEAVE THE STAGE',
                color: MM.crimson,
                height: 52,
                fontSize: 16,
                icon: Icons.exit_to_app_rounded,
                sound: Sfx.back,
                onTap: () => Navigator.of(context).pop(PauseAction.quit),
              ),
            ],
          ),
        ),
        ),
      ),
    ),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

Future<ResultAction?> showResultDialog(
  BuildContext context, {
  required LevelConfig cfg,
  required bool won,
  required int stars,
  required int score,
  required int previousBest,
  required int syncs,
  required int perfects,
  required int maxCombo,
  required int secondsLeft,
  required bool hasNext,
  int failStreak = 0,
}) {
  return showGeneralDialog<ResultAction>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (context, _, _) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: GoldPanel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            tint: won ? MM.velvet : const Color(0xFF35131E),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(won ? A.medalGreen : A.sealRed, height: 54),
                const SizedBox(height: 8),
                Text(
                  won ? 'CURTAIN CALL' : 'THE ILLUSION FADES',
                  textAlign: TextAlign.center,
                  style: MM.title(24, color: won ? MM.gold : MM.danger),
                ),
                const SizedBox(height: 4),
                Text(
                  won
                      ? 'Act ${cfg.number} complete'
                      : 'Act ${cfg.number} — the realities drifted apart',
                  textAlign: TextAlign.center,
                  style: MM.body(12, color: MM.parchment.withValues(alpha: 0.85)),
                ),
                if (won) ...[
                  const SizedBox(height: 12),
                  _AnimatedStars(stars: stars),
                ],
                const SizedBox(height: 14),
                _ScoreRow(label: 'SCORE', value: '$score', highlight: true),
                _ScoreRow(
                  label: 'PERSONAL BEST',
                  value: '${score > previousBest ? score : previousBest}'
                      '${score > previousBest ? '  NEW!' : ''}',
                ),
                _ScoreRow(label: 'SYNCHRONISATIONS', value: '$syncs'),
                _ScoreRow(label: 'PERFECT MERGES', value: '$perfects'),
                _ScoreRow(label: 'BEST COMBO', value: 'x$maxCombo'),
                _ScoreRow(label: 'TIME LEFT', value: '${secondsLeft}s'),
                if (won)
                  _ScoreRow(
                    label: 'REWARD',
                    value: '+${20 + stars * 15} masks',
                    highlight: true,
                  ),
                if (!won && failStreak >= 3) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: MM.velvet.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MM.amethyst.withValues(alpha: 0.55)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            color: MM.goldBright,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tip: Lock the two slower realities first, then catch the fast one at its peak.',
                            style: MM.body(12, color: MM.parchment),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (won && hasNext)
                  GoldButton(
                    label: 'NEXT ACT',
                    icon: Icons.skip_next_rounded,
                    onTap: () => Navigator.of(context).pop(ResultAction.next),
                  ),
                if (won && !hasNext)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'You have mastered every performance.\nThe masquerade bows to you.',
                      textAlign: TextAlign.center,
                      style: MM.body(13, color: MM.goldBright),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GoldButton(
                        label: 'RETRY',
                        color: MM.amethyst,
                        height: 52,
                        fontSize: 15,
                        icon: Icons.refresh_rounded,
                        onTap: () => Navigator.of(context).pop(ResultAction.retry),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GoldButton(
                        label: 'MENU',
                        color: MM.crimson,
                        height: 52,
                        fontSize: 15,
                        icon: Icons.home_rounded,
                        sound: Sfx.back,
                        onTap: () => Navigator.of(context).pop(ResultAction.menu),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    ),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.88, end: 1.0)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _AnimatedStars extends StatefulWidget {
  const _AnimatedStars({required this.stars});
  final int stars;

  @override
  State<_AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<_AnimatedStars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      Future<void>.delayed(Duration(milliseconds: 260 + i * 320), () {
        if (mounted) Audio.instance.play(Sfx.reward, volume: 0.7);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Builder(
                  builder: (_) {
                    final start = 0.2 + i * 0.26;
                    final t = ((_c.value - start) / 0.26).clamp(0.0, 1.0);
                    final earned = i < widget.stars;
                    return SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (earned)
                            CustomPaint(
                              size: const Size(56, 56),
                              painter: _BurstPainter(t: t),
                            ),
                          Transform.scale(
                            scale: earned ? 0.6 + Curves.easeOutBack.transform(t) * 0.4 : 1,
                            child: Opacity(
                              opacity: earned ? (0.2 + t * 0.8) : 0.2,
                              child: Image.asset(A.star, height: 46),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t > 0.85) return;
    final progress = (t / 0.85).clamp(0.0, 1.0);
    final fade = 1 - progress;
    final center = size.center(Offset.zero);
    const count = 8;

    final linePaint = Paint()
      ..color = MM.goldBright.withValues(alpha: 0.9 * fade)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = MM.gold.withValues(alpha: 0.7 * fade)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final angle = (2 * pi * i / count) - pi / 2;
      final innerR = 14.0 + progress * 4;
      final outerR = innerR + 6 + progress * 16;
      canvas.drawLine(
        center + Offset(cos(angle) * innerR, sin(angle) * innerR),
        center + Offset(cos(angle) * outerR, sin(angle) * outerR),
        linePaint,
      );
      final dotAngle = angle + pi / count;
      final dotR = 10.0 + progress * 18;
      canvas.drawCircle(
        center + Offset(cos(dotAngle) * dotR, sin(dotAngle) * dotR),
        2.0 * (1 - progress * 0.5),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MM
                .body(10, color: MM.parchment.withValues(alpha: 0.7))
                .copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: highlight
                ? MM.title(16, color: MM.goldBright)
                : MM.body(14, color: MM.parchment),
          ),
        ],
      ),
    );
  }
}

/// Small toast used by the shop and daily screens.
void showMMToast(BuildContext context, String message, {bool good = true}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).padding.bottom + 90,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MM.night.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: good ? MM.gold : MM.danger,
                width: 1.6,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16)],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: MM.body(13, color: good ? MM.goldBright : MM.danger),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1600), entry.remove);
}
