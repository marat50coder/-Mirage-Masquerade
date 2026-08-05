import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/palette.dart';
import '../widgets/ornate.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MMScreen(
      title: 'HOW THE SHOW WORKS',
      background: 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          GoldPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var w = 0; w < 3; w++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Image.asset(A.obj(w, 'joker'), height: 62),
                            const SizedBox(height: 4),
                            Text(
                              MM.worldRoman[w],
                              style: MM.title(15, color: MM.worldColors[w]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Every act runs three realities at once. They never pause — '
                  'objects keep travelling their paths even while you are looking '
                  'somewhere else.',
                  textAlign: TextAlign.center,
                  style: MM.body(12, color: MM.parchment),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Step(
            number: '1',
            title: 'Watch a reality',
            body: 'Each object drifts along its own loop. A glowing ring marks the '
                'sync zone that object has to be standing in.',
            asset: A.ringGold,
          ),
          const _Step(
            number: '2',
            title: 'Lock the moment',
            body: 'When every object of the visible reality sits inside its ring, '
                'the dial fills. Tap the stage or the SYNC dial to freeze that reality.',
            asset: A.orbGold,
          ),
          const _Step(
            number: '3',
            title: 'Shift and repeat',
            body: 'Swipe left or right to move to another reality. The clock keeps '
                'running, so remember where its objects were heading.',
            asset: A.spiralGold,
          ),
          const _Step(
            number: '4',
            title: 'Merge all three',
            body: 'Lock all three realities before the resonance window closes and '
                'the worlds collapse into one grand performance.',
            asset: A.burst,
          ),
          const SizedBox(height: 8),
          GoldPanel(
            padding: const EdgeInsets.all(14),
            tint: const Color(0xFF35131E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MIND THE RISKS', style: MM.title(14, color: MM.danger)),
                const SizedBox(height: 8),
                _Bullet('Locking out of phase costs one attempt.'),
                _Bullet('If the resonance window runs out, every lock is released.'),
                _Bullet('Consecutive merges build a combo that multiplies your score.'),
                _Bullet('Later acts add fading illusions, phantom doubles, mirrored '
                    'stages, revolving scenery and shifting tempo.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GoldPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROPS YOU CAN CARRY', style: MM.title(14)),
                const SizedBox(height: 8),
                _Bullet('Third Eye — peek at the other two realities for six seconds.'),
                _Bullet('Hour Relic — halves the tempo of every reality for eight seconds.'),
                _Bullet('Spare Mask — restores one attempt mid-performance.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.asset,
  });

  final String number;
  final String title;
  final String body;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GoldPanel(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Column(
                children: [
                  Image.asset(asset, height: 42),
                  const SizedBox(height: 2),
                  Text(number, style: MM.title(16)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: MM.title(13)),
                  const SizedBox(height: 4),
                  Text(body, style: MM.body(12, color: MM.parchment.withValues(alpha: 0.86))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Image.asset(A.suits[3], height: 11),
          ),
          Expanded(
            child: Text(text, style: MM.body(12, color: MM.parchment.withValues(alpha: 0.88))),
          ),
        ],
      ),
    );
  }
}
