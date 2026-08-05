import 'package:flutter_test/flutter_test.dart';
import 'package:mirage_masquerade/game/engine.dart';
import 'package:mirage_masquerade/game/level.dart';

void main() {
  test('balance probe', () {
    for (var i = 0; i < Levels.count; i++) {
      final cfg = Levels.at(i);
      var minWindow = 99.0, maxWindow = 0.0;
      var minPeriod = 99.0, maxPeriod = 0.0;
      var minChain = 99.0, maxChain = 0.0;
      var minSeparation = 999.0;
      var worstReachable = 0.0;

      for (var seed = 0; seed < 40; seed++) {
        final e = GameEngine(cfg, seed: seed);
        minChain = minChain > e.chainWindow ? e.chainWindow : minChain;
        maxChain = maxChain < e.chainWindow ? e.chainWindow : maxChain;
        for (final w in e.worlds) {
          final half = w.windowHalf(cfg.tolerance) * 2;
          if (half < minWindow) minWindow = half;
          if (half > maxWindow) maxWindow = half;
          if (w.period < minPeriod) minPeriod = w.period;
          if (w.period > maxPeriod) maxPeriod = w.period;
          final zones = w.targets.toList();
          for (var a = 0; a < zones.length; a++) {
            for (var b = a + 1; b < zones.length; b++) {
              final d = (zones[a].zone - zones[b].zone).distance;
              if (d < minSeparation) minSeparation = d;
            }
          }
        }
        // Worst case time needed to chain all three locks.
        final ps = e.worlds.map((w) => w.period).toList()..sort();
        final need = ps[2] + ps[1];
        if (need / e.chainWindow > worstReachable) worstReachable = need / e.chainWindow;
        e.dispose();
      }

      // ignore: avoid_print
      print('L${(i + 1).toString().padLeft(2)} '
          'obj=${cfg.objectsPerWorld} tol=${cfg.tolerance.toStringAsFixed(1)} '
          'window=${minWindow.toStringAsFixed(2)}..${maxWindow.toStringAsFixed(2)}s '
          'period=${minPeriod.toStringAsFixed(1)}..${maxPeriod.toStringAsFixed(1)}s '
          'chain=${minChain.toStringAsFixed(1)}..${maxChain.toStringAsFixed(1)}s '
          'sep=${minSeparation == 999.0 ? '-' : minSeparation.toStringAsFixed(1)} '
          'load=${worstReachable.toStringAsFixed(2)}');
    }
  });
}
