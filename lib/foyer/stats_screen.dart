import 'package:flutter/material.dart';

import '../studio/assets.dart';
import '../studio/palette.dart';
import '../studio/progress.dart';
import '../act/level.dart';
import '../ornament/ornate.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final hours = p.secondsPlayed ~/ 3600;
    final minutes = (p.secondsPlayed % 3600) ~/ 60;
    final completion = (p.levelsCompleted / Levels.count * 100).clamp(0, 100).round();

    return MMScreen(
      title: 'PLAYBILL',
      background: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          GoldPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              children: [
                Image.asset(A.appIcon, height: 74),
                const SizedBox(height: 10),
                Text('$completion% OF THE SHOW MASTERED', style: MM.title(15)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completion / 100,
                    minHeight: 9,
                    backgroundColor: Colors.black45,
                    valueColor: const AlwaysStoppedAnimation(MM.gold),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(A.star, height: 22),
                    const SizedBox(width: 6),
                    Text(
                      '${p.totalStars} / ${Levels.count * 3} stars',
                      style: MM.body(13, color: MM.parchment),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StatGrid(
            entries: [
              _Stat('Acts cleared', '${p.levelsCompleted}', A.circusTent),
              _Stat('Synchronisations', '${p.totalSyncs}', A.orbGold),
              _Stat('Perfect merges', '${p.totalPerfect}', A.star),
              _Stat('Objects merged', '${p.totalObjects}', A.spiralGold),
              _Stat('Reality shifts', '${p.totalSwitches}', A.haloGold),
              _Stat('Best combo', 'x${p.bestCombo}', A.wingHeart),
              _Stat('Best score', '${p.bestOverallScore}', A.medalRed),
              _Stat('Time on stage', '${hours}h ${minutes}m', A.obj(1, 'clock')),
            ],
          ),
          const SizedBox(height: 18),
          const Flourish(text: 'ACT RECORDS', size: 15),
          const SizedBox(height: 10),
          GoldPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                for (var i = 0; i < Levels.count; i++)
                  if ((p.bestScore[i] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text('${i + 1}', style: MM.title(12)),
                          ),
                          Expanded(
                            child: Text(
                              Levels.at(i).title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MM.body(12, color: MM.parchment),
                            ),
                          ),
                          StarsRow(count: p.stars[i] ?? 0, size: 13, gap: 1),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 58,
                            child: Text(
                              '${p.bestScore[i]}',
                              textAlign: TextAlign.right,
                              style: MM.title(12, color: MM.goldBright),
                            ),
                          ),
                        ],
                      ),
                    ),
                if (p.bestScore.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No performances recorded yet.',
                      style: MM.body(12, color: MM.parchment.withValues(alpha: 0.7)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.asset);
  final String label;
  final String value;
  final String asset;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.entries});
  final List<_Stat> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.15,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return GoldPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          radius: 14,
          child: Row(
            children: [
              Image.asset(e.asset, height: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MM.title(16, color: MM.goldBright),
                    ),
                    Text(
                      e.label.toUpperCase(),
                      maxLines: 2,
                      style: MM.body(9, color: MM.parchment.withValues(alpha: 0.76))
                          .copyWith(letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
