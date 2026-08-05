@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirage_masquerade/core/assets.dart';
import 'package:mirage_masquerade/core/image_bank.dart';
import 'package:mirage_masquerade/core/palette.dart';
import 'package:mirage_masquerade/core/progress.dart';
import 'package:mirage_masquerade/game/engine.dart';
import 'package:mirage_masquerade/game/level.dart';
import 'package:mirage_masquerade/game/stage_painter.dart';
import 'package:mirage_masquerade/screens/boot_screen.dart';
import 'package:mirage_masquerade/screens/daily_screen.dart';
import 'package:mirage_masquerade/screens/gallery_screen.dart';
import 'package:mirage_masquerade/screens/game_screen.dart';
import 'package:mirage_masquerade/screens/how_to_play_screen.dart';
import 'package:mirage_masquerade/screens/level_select_screen.dart';
import 'package:mirage_masquerade/screens/menu_screen.dart';
import 'package:mirage_masquerade/screens/settings_screen.dart';
import 'package:mirage_masquerade/screens/shop_screen.dart';
import 'package:mirage_masquerade/screens/stats_screen.dart';
import 'package:mirage_masquerade/widgets/game_hud.dart';
import 'package:mirage_masquerade/widgets/result_dialogs.dart';

Future<void> _settle(WidgetTester tester, {int passes = 6}) async {
  for (var i = 0; i < passes; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

final _shotKey = GlobalKey();

Future<void> _shoot(
  WidgetTester tester,
  Widget child,
  String name, {
  Size size = const Size(393, 852),
  bool stable = true,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: MM.night,
        ),
        home: child,
      ),
    ),
  );
  await _settle(tester);
  if (stable) {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  } else {
    await _dump(tester, name);
  }
}

/// Writes the current frame straight to disk. Used for screens whose engine is
/// seeded from the clock, where a byte-exact golden would never match twice.
Future<void> _dump(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final file = File('test/shots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PluginStubs.apply();
    await Progress.instance.load();
  });

  testWidgets('boot portrait', (tester) async {
    await _shoot(tester, const BootScreen(), '01_boot_portrait');
  });

  testWidgets('boot landscape', (tester) async {
    await _shoot(tester, const BootScreen(), '02_boot_landscape',
        size: const Size(852, 393));
  });

  testWidgets('menu', (tester) async {
    await _shoot(tester, const MenuScreen(), '04_menu');
  });

  testWidgets('levels', (tester) async {
    await _shoot(tester, const LevelSelectScreen(), '05_levels');
  });

  testWidgets('stage', (tester) async {
    await tester.runAsync(() async {
      for (final key in A.canvasImages()) {
        await ImageBank.instance.load(key);
      }
    });
    await _shoot(tester, const _StagePreview(), '06_stage');
  });

  testWidgets('stage drifting', (tester) async {
    await tester.runAsync(() async {
      for (final key in A.canvasImages()) {
        await ImageBank.instance.load(key);
      }
    });
    await _shoot(tester, const _StagePreview(drifting: true, level: 15), '06b_stage_drifting');
  });

  testWidgets('stage merging', (tester) async {
    await tester.runAsync(() async {
      for (final key in A.canvasImages()) {
        await ImageBank.instance.load(key);
      }
    });
    await _shoot(tester, const _StagePreview(merging: true, level: 19), '07_stage_merge');
  });

  testWidgets('daily', (tester) async {
    // Shows a live countdown to the next reset, so it never renders identically.
    await _shoot(tester, const DailyScreen(), '08_daily', stable: false);
  });

  testWidgets('shop', (tester) async {
    await _shoot(tester, const ShopScreen(), '09_shop');
  });

  testWidgets('gallery', (tester) async {
    await _shoot(tester, const GalleryScreen(), '10_gallery');
  });

  testWidgets('stats', (tester) async {
    await _shoot(tester, const StatsScreen(), '11_stats');
  });

  testWidgets('settings', (tester) async {
    await _shoot(tester, const SettingsScreen(), '12_settings');
  });

  testWidgets('how to play', (tester) async {
    await _shoot(tester, const HowToPlayScreen(), '13_how_to_play');
  });

  testWidgets('live game screen', (tester) async {
    await tester.runAsync(() async {
      for (final key in A.canvasImages()) {
        await ImageBank.instance.load(key);
      }
    });
    await _shoot(tester, const GameScreen(levelIndex: 9), '14_game_live', stable: false);
  });

  testWidgets('pause dialog', (tester) async {
    await _shootDialog(
      tester,
      (context) => showPauseDialog(context, Levels.at(6)),
      '15_pause',
    );
  });

  testWidgets('victory dialog', (tester) async {
    await _shootDialog(
      tester,
      (context) => showResultDialog(
        context,
        cfg: Levels.at(6),
        won: true,
        stars: 3,
        score: 18240,
        previousBest: 12100,
        syncs: 9,
        perfects: 6,
        maxCombo: 5,
        secondsLeft: 27,
        hasNext: true,
      ),
      '16_victory',
    );
  });

  testWidgets('defeat dialog', (tester) async {
    await _shootDialog(
      tester,
      (context) => showResultDialog(
        context,
        cfg: Levels.at(14),
        won: false,
        stars: 0,
        score: 4320,
        previousBest: 0,
        syncs: 3,
        perfects: 1,
        maxCombo: 2,
        secondsLeft: 0,
        hasNext: false,
      ),
      '17_defeat',
    );
  });
}

/// Pumps a screen, fires a dialog on it and shoots the result.
Future<void> _shootDialog(
  WidgetTester tester,
  void Function(BuildContext context) open,
  String name,
) async {
  tester.view.physicalSize = const Size(786, 1704);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(backgroundColor: MM.deep);
        },
      ),
    ),
  );
  open(ctx);
  // Long enough to drain the staggered star-reveal chimes.
  await _settle(tester, passes: 18);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

/// Renders the real stage with a deterministic engine so the golden is stable.
class _StagePreview extends StatefulWidget {
  const _StagePreview({this.merging = false, this.drifting = false, this.level = 6});

  final bool merging;
  final bool drifting;
  final int level;

  @override
  State<_StagePreview> createState() => _StagePreviewState();
}

class _StagePreviewState extends State<_StagePreview> {
  late final LevelConfig cfg = Levels.at(widget.level);
  late final GameEngine engine = GameEngine(cfg, seed: 42);

  @override
  void initState() {
    super.initState();
    engine.update(2.5);
    engine.state = RunState.playing;
    if (widget.merging) {
      engine.t = engine.worlds[0].alignAt;
      engine.currentWorld = 0;
      engine.attemptSync();
      engine.t = engine.worlds[1].alignAt;
      engine.currentWorld = 1;
      engine.attemptSync();
      engine.t = engine.worlds[2].alignAt;
      engine.currentWorld = 2;
      engine.attemptSync();
      engine.mergeT = 0.6;
    } else if (widget.drifting) {
      // Half a beat away, so every object sits far from its ring.
      engine.currentWorld = 1;
      engine.t = engine.worlds[1].alignAt + engine.worlds[1].period * 0.5;
    } else {
      engine.t = engine.worlds[1].alignAt - 0.35;
      engine.currentWorld = 1;
      engine.worlds[0].locked = true;
      engine.worlds[0].lockedAt = engine.worlds[0].alignAt;
      engine.chainStart = engine.wall;
    }
  }

  @override
  void dispose() {
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MM.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(A.bg(cfg.location), fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MM.night.withValues(alpha: 0.74),
                  Color.lerp(MM.night, MM.worldColors[engine.currentWorld], 0.22)!
                      .withValues(alpha: 0.52),
                  MM.night.withValues(alpha: 0.80),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                GameHud(engine: engine, cfg: cfg, onPause: () {}),
                Expanded(
                  child: CustomPaint(
                    painter: StagePainter(engine: engine, repaint: engine, showTrails: true),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 190),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for the native plugins so screens can be rendered head-less.
class PluginStubs {
  static void apply() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    for (final name in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global/events',
      'dev.fluttercommunity.plus/connectivity',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  }
}
