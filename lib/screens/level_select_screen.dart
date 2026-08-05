import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../game/level.dart';
import '../widgets/ornate.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Future<void> _play(int index) async {
    Audio.instance.play(Sfx.menuOpen);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(levelIndex: index)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return MMScreen(
      title: 'THE PROGRAMME',
      background: 1,
      trailing: Center(child: Image.asset(A.star, height: 26)),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${p.totalStars} of ${Levels.count * 3} stars collected',
                  textAlign: TextAlign.center,
                  style: MM.body(12, color: MM.parchment.withValues(alpha: 0.8)),
                ),
              ),
            ),
          ),
          for (var loc = 0; loc < 6; loc++) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _LocationHeader(
                  location: loc,
                  unlocked: p.highestUnlocked >= loc * 4,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, loc == 5 ? 26 : 18),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final index = loc * 4 + i;
                    final cfg = Levels.at(index);
                    final unlocked = index <= p.highestUnlocked;
                    return _LevelTile(
                      cfg: cfg,
                      unlocked: unlocked,
                      stars: p.stars[index] ?? 0,
                      onTap: unlocked ? () => _play(index) : null,
                    );
                  },
                  childCount: 4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.location, required this.unlocked});
  final int location;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MM.gold.withValues(alpha: 0.7), width: 1.6),
              image: DecorationImage(image: AssetImage(A.bg(location)), fit: BoxFit.cover),
            ),
            foregroundDecoration: unlocked
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: 0.66),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Levels.locationName(location).toUpperCase(), style: MM.title(15)),
                Text(
                  unlocked ? 'Acts ${location * 4 + 1}–${location * 4 + 4}' : 'Locked stage',
                  style: MM.body(11, color: MM.parchment.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          if (!unlocked) const Icon(Icons.lock_rounded, color: MM.gold, size: 20),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.cfg,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final LevelConfig cfg;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = MM.worldColors[cfg.index % 3];
    return GestureDetector(
      onTap: onTap == null
          ? () => Audio.instance.play(Sfx.back)
          : () {
              Audio.instance
                ..play(Sfx.click)
                ..tapFeedback();
              onTap!();
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? [
                    Color.lerp(accent, Colors.white, 0.16)!,
                    Color.lerp(accent, Colors.black, 0.62)!,
                  ]
                : [MM.velvet.withValues(alpha: 0.94), MM.night.withValues(alpha: 0.96)],
          ),
          border: Border.all(
            color: unlocked ? MM.gold.withValues(alpha: 0.85) : MM.gold.withValues(alpha: 0.3),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Opacity(
          opacity: unlocked ? 1 : 0.72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unlocked)
                Text('${cfg.number}', style: MM.title(24, color: Colors.white))
              else
                const Icon(Icons.lock_rounded, color: Colors.white54, size: 22),
              const SizedBox(height: 4),
              StarsRow(count: stars, size: 13, gap: 1),
            ],
          ),
        ),
      ),
    );
  }
}
