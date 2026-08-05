import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/daily.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../widgets/ornate.dart';
import '../widgets/result_dialogs.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final tasks = p.dailyTasks;
    final now = DateTime.now();
    final resetIn = DateTime(now.year, now.month, now.day + 1).difference(now);

    return MMScreen(
      title: 'DAILY CHALLENGES',
      background: 4,
      trailing: null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          Center(child: CoinPill(amount: p.coins, height: 38)),
          const SizedBox(height: 10),
          Text(
            'New challenges in ${resetIn.inHours}h ${resetIn.inMinutes % 60}m',
            textAlign: TextAlign.center,
            style: MM.body(12, color: MM.parchment.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 16),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(
                task: t,
                value: p.dailyValue(t.metric),
                claimed: p.dailyIsClaimed(t),
                onClaim: () {
                  if (p.claimDaily(t)) {
                    Audio.instance
                      ..play(Sfx.reward)
                      ..impact();
                    showMMToast(context, '+${t.reward} masks collected');
                    setState(() {});
                  }
                },
              ),
            ),
          const SizedBox(height: 6),
          GoldPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Image.asset(A.globe, height: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIFETIME LEDGER', style: MM.title(13)),
                      const SizedBox(height: 4),
                      Text(
                        '${p.totalSyncs} synchronisations · ${p.totalObjects} objects merged\n'
                        '${p.totalSwitches} reality shifts · ${p.totalPerfect} perfect merges',
                        style: MM.body(11, color: MM.parchment.withValues(alpha: 0.82)),
                      ),
                    ],
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.value,
    required this.claimed,
    required this.onClaim,
  });

  final DailyTask task;
  final int value;
  final bool claimed;
  final VoidCallback onClaim;

  static const _icons = <DailyMetric, String>{
    DailyMetric.syncs: A.orbGold,
    DailyMetric.levels: A.circusTent,
    DailyMetric.objects: A.spiralGold,
    DailyMetric.perfect: A.star,
    DailyMetric.switches: A.haloGold,
    DailyMetric.combo: A.wingHeart,
    DailyMetric.swift: A.medalGreen,
  };

  @override
  Widget build(BuildContext context) {
    final done = value >= task.target;
    final ratio = (value / task.target).clamp(0.0, 1.0);
    return GoldPanel(
      padding: const EdgeInsets.all(13),
      tint: claimed ? const Color(0xFF1B2A20) : MM.velvet,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Opacity(
            opacity: claimed ? 0.5 : 1,
            child: Image.asset(_icons[task.metric] ?? A.star, height: 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title.toUpperCase(), style: MM.title(13)),
                const SizedBox(height: 2),
                Text(
                  task.detail,
                  style: MM.body(11, color: MM.parchment.withValues(alpha: 0.82)),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: Colors.black45,
                          valueColor: AlwaysStoppedAnimation(
                            claimed ? MM.emerald : (done ? MM.goldBright : MM.amethyst),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${value.clamp(0, task.target)}/${task.target}',
                      style: MM.body(11, color: MM.parchment),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: claimed
                ? Column(
                    children: [
                      const Icon(Icons.verified_rounded, color: MM.emerald, size: 26),
                      Text('CLAIMED', style: MM.body(9, color: MM.emerald)),
                    ],
                  )
                : GoldButton(
                    label: done ? 'CLAIM' : '+${task.reward}',
                    height: 44,
                    fontSize: 13,
                    enabled: done,
                    color: done ? MM.gold : MM.velvetLight,
                    sound: Sfx.reward,
                    onTap: onClaim,
                  ),
          ),
        ],
      ),
    );
  }
}
