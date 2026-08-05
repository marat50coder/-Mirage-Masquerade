import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../game/level.dart';
import '../widgets/ornate.dart';

/// Collection of unlocked stages and illusion artefacts.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static const _stageUnlock = [0, 4, 8, 12, 16, 20];
  static const _artifactUnlock = [0, 5, 12, 22, 35, 50, 70, 95, 125];

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final unlockedStages = _stageUnlock.where((v) => p.highestUnlocked >= v).length;
    final unlockedArtifacts = _artifactUnlock.where((v) => p.totalSyncs >= v).length;

    return MMScreen(
      title: 'THE COLLECTION',
      background: 5,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          Text(
            'Stages $unlockedStages/6   ·   Artefacts $unlockedArtifacts/9',
            textAlign: TextAlign.center,
            style: MM.body(12, color: MM.parchment.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 14),
          const Flourish(text: 'THEATRICAL STAGES', size: 16),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: 6,
            itemBuilder: (context, i) {
              final unlocked = p.highestUnlocked >= _stageUnlock[i];
              return _StageCard(
                index: i,
                unlocked: unlocked,
                requirement: 'Reach Act ${_stageUnlock[i] + 1}',
              );
            },
          ),
          const SizedBox(height: 24),
          const Flourish(text: 'ILLUSION ARTEFACTS', size: 16),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: A.objectKeys.length,
            itemBuilder: (context, i) {
              final key = A.objectKeys[i];
              final need = _artifactUnlock[i];
              final unlocked = p.totalSyncs >= need;
              return _ArtifactCard(
                objectKey: key,
                world: i % 3,
                unlocked: unlocked,
                requirement: '$need syncs',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.index, required this.unlocked, required this.requirement});

  final int index;
  final bool unlocked;
  final String requirement;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Audio.instance.play(unlocked ? Sfx.tab : Sfx.back),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MM.gold.withValues(alpha: unlocked ? 0.8 : 0.3), width: 1.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(A.bg(index), fit: BoxFit.cover),
            if (!unlocked)
              BackdropDim(child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, color: MM.gold, size: 28),
                    const SizedBox(height: 6),
                    Text(requirement, style: MM.body(10, color: MM.parchment)),
                  ],
                ),
              )),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                color: MM.night.withValues(alpha: 0.78),
                child: Text(
                  Levels.locationName(index).toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MM.title(11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackdropDim extends StatelessWidget {
  const BackdropDim({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: MM.night.withValues(alpha: 0.78), child: child);
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.objectKey,
    required this.world,
    required this.unlocked,
    required this.requirement,
  });

  final String objectKey;
  final int world;
  final bool unlocked;
  final String requirement;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Audio.instance.play(unlocked ? Sfx.objectSelect : Sfx.back),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? [MM.worldColors[world].withValues(alpha: 0.34), MM.deep]
                : [MM.velvet.withValues(alpha: 0.5), MM.night],
          ),
          border: Border.all(
            color: unlocked ? MM.gold.withValues(alpha: 0.75) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: unlocked
                  ? Image.asset(A.obj(world, objectKey), fit: BoxFit.contain)
                  : const Center(child: Icon(Icons.help_outline_rounded, color: Colors.white24, size: 30)),
            ),
            const SizedBox(height: 5),
            Text(
              unlocked ? (A.objectLabels[objectKey] ?? objectKey).toUpperCase() : requirement,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MM.body(9, color: unlocked ? MM.goldBright : MM.parchment.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
