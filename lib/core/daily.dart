import 'dart:math';

/// Counters a daily challenge can watch.
enum DailyMetric { syncs, levels, objects, perfect, switches, combo, swift }

class DailyTask {
  const DailyTask({
    required this.metric,
    required this.title,
    required this.detail,
    required this.target,
    required this.reward,
  });

  final DailyMetric metric;
  final String title;
  final String detail;
  final int target;
  final int reward;

  String get key => '${metric.name}_$target';
}

class DailyTasks {
  DailyTasks._();

  static const _pool = <DailyTask>[
    DailyTask(
      metric: DailyMetric.syncs,
      title: 'Triple Resonance',
      detail: 'Complete 5 successful synchronisations',
      target: 5,
      reward: 60,
    ),
    DailyTask(
      metric: DailyMetric.syncs,
      title: 'Grand Conductor',
      detail: 'Complete 12 successful synchronisations',
      target: 12,
      reward: 120,
    ),
    DailyTask(
      metric: DailyMetric.levels,
      title: 'Touring Company',
      detail: 'Finish 3 performances',
      target: 3,
      reward: 90,
    ),
    DailyTask(
      metric: DailyMetric.objects,
      title: 'Mirror Assembly',
      detail: 'Merge 50 illusion objects',
      target: 50,
      reward: 100,
    ),
    DailyTask(
      metric: DailyMetric.perfect,
      title: 'Flawless Illusion',
      detail: 'Land 3 perfect synchronisations',
      target: 3,
      reward: 110,
    ),
    DailyTask(
      metric: DailyMetric.switches,
      title: 'Between Realities',
      detail: 'Switch realities 100 times',
      target: 100,
      reward: 70,
    ),
    DailyTask(
      metric: DailyMetric.combo,
      title: 'Standing Ovation',
      detail: 'Reach a x4 resonance combo',
      target: 4,
      reward: 130,
    ),
    DailyTask(
      metric: DailyMetric.swift,
      title: 'Curtain Call',
      detail: 'Finish a performance with 30s to spare',
      target: 1,
      reward: 140,
    ),
  ];

  /// Deterministic per-day selection so the list is stable through the day.
  static List<DailyTask> forDate(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rng = Random(seed);
    final indices = List<int>.generate(_pool.length, (i) => i)..shuffle(rng);
    return indices.take(3).map((i) => _pool[i]).toList();
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
