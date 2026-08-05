import 'package:flutter_test/flutter_test.dart';
import 'package:mirage_masquerade/game/engine.dart';
import 'package:mirage_masquerade/game/level.dart';

void main() {
  test('every level generates realities that can actually be aligned', () {
    for (var i = 0; i < Levels.count; i++) {
      final cfg = Levels.at(i);
      final engine = GameEngine(cfg, seed: 1000 + i);
      for (final world in engine.worlds) {
        expect(
          world.isAligned(world.alignAt, cfg.tolerance),
          isTrue,
          reason: 'level $i / reality ${world.index} is never aligned',
        );
        expect(
          world.windowHalf(cfg.tolerance),
          greaterThan(0.12),
          reason: 'level $i / reality ${world.index} has an untappable window',
        );
        expect(
          world.isAligned(world.alignAt + world.period, cfg.tolerance),
          isTrue,
          reason: 'level $i / reality ${world.index} does not repeat its beat',
        );
      }
      engine.dispose();
    }
  });

  test('the resonance window is long enough to reach every reality', () {
    for (var i = 0; i < Levels.count; i++) {
      final cfg = Levels.at(i);
      final engine = GameEngine(cfg, seed: 500 + i);
      final periods = engine.worlds.map((w) => w.period).toList()..sort();
      expect(engine.chainWindow, greaterThan(periods[2] + periods[1]));
      engine.dispose();
    }
  });
}
