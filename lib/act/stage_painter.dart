import 'dart:math';

import 'package:flutter/material.dart';

import '../studio/assets.dart';
import '../studio/image_bank.dart';
import '../studio/palette.dart';
import 'engine.dart';
import 'trajectory.dart';

class StagePainter extends CustomPainter {
  StagePainter({
    required this.engine,
    required this.repaint,
    required this.showTrails,
  }) : super(repaint: repaint);

  final GameEngine engine;
  final Listenable repaint;
  final bool showTrails;

  final ImageBank bank = ImageBank.instance;

  @override
  void paint(Canvas canvas, Size size) {
    final map = StageMap(Offset.zero & size);
    canvas.save();
    if (engine.shake > 0) {
      final s = engine.shake;
      final r = Random((engine.wall * 60).floor());
      canvas.translate((r.nextDouble() - 0.5) * 16 * s, (r.nextDouble() - 0.5) * 10 * s);
    }

    if (engine.state == RunState.merging) {
      _paintMerge(canvas, map);
    } else {
      final w = engine.worlds[engine.currentWorld];
      _paintWorld(canvas, map, w, 1.0);
      if (engine.revealActive) _paintRevealGhosts(canvas, map);
    }
    canvas.restore();
  }

  // --------------------------------------------------------------- one world

  void _paintWorld(Canvas canvas, StageMap map, WorldRun w, double alpha, {double lift = 0}) {
    final time = engine.timeOf(w);
    final warped = w.warped(time);
    final color = MM.worldColors[w.index];

    if (showTrails) {
      for (final o in w.objects) {
        if (o.decoy) continue;
        _paintTrail(canvas, map, w, o, color.withValues(alpha: 0.13 * alpha));
      }
    }

    for (final o in w.objects) {
      if (o.decoy) continue;
      final zone = _project(w, o.zone, time);
      final d = (o.positionAt(warped) - o.zone).distance;
      final near = (1 - d / (engine.cfg.tolerance * 2.4)).clamp(0.0, 1.0);
      _paintZone(canvas, map, zone, w, alpha, near, lift);
    }

    for (final o in w.objects) {
      final pos = _project(w, o.positionAt(warped), time);
      final d = (o.positionAt(warped) - o.zone).distance;
      final inZone = !o.decoy && d <= engine.cfg.tolerance;
      _paintObject(canvas, map, o, pos, alpha * o.opacityAt(warped), inZone, w.locked, lift);
    }

    if (w.locked) {
      for (final o in w.targets) {
        final zone = _project(w, o.zone, time);
        _sprite(canvas, A.ringGold, map.toScreen(zone), map.len(engine.cfg.tolerance * 3.4),
            opacity: 0.55 * alpha, rotation: engine.wall * 0.6);
      }
    }
  }

  void _paintTrail(Canvas canvas, StageMap map, WorldRun w, MObject o, Color color) {
    final path = Path();
    const n = 90;
    final time = engine.timeOf(w);
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final p = map.toScreen(_project(w, o.path.at(o.phase + u), time));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  void _paintZone(
    Canvas canvas,
    StageMap map,
    Offset zoneField,
    WorldRun w,
    double alpha,
    double near,
    double lift,
  ) {
    final c = map.toScreen(zoneField).translate(0, lift);
    final r = map.len(engine.cfg.tolerance);
    final color = MM.worldColors[w.index];
    final pulse = 0.5 + 0.5 * sin(engine.wall * 2.4 + w.index);

    _sprite(canvas, A.rings[w.index], c, r * 2.25,
        opacity: (0.55 + near * 0.45) * alpha, rotation: -engine.wall * 0.35);
    canvas.drawCircle(
      c,
      r * (1.0 + 0.05 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + near * 2.2
        ..color = color.withValues(alpha: (0.55 + near * 0.45) * alpha),
    );
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()..color = color.withValues(alpha: (0.10 + near * 0.20) * alpha),
    );
    // A cross-hair keeps the exact centre readable behind a large sprite.
    final tick = r * 0.34;
    final tickPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.5 * alpha);
    canvas.drawLine(c.translate(-tick, 0), c.translate(tick, 0), tickPaint);
    canvas.drawLine(c.translate(0, -tick), c.translate(0, tick), tickPaint);

    if (near > 0.55) {
      _sprite(canvas, A.haloGold, c, r * 3.2 * (0.9 + 0.2 * pulse),
          opacity: (near - 0.55) * 1.4 * alpha);
    }
  }

  void _paintObject(
    Canvas canvas,
    StageMap map,
    MObject o,
    Offset fieldPos,
    double alpha,
    bool inZone,
    bool locked,
    double lift,
  ) {
    final c = map.toScreen(fieldPos).translate(0, lift);
    final h = map.len(o.size * 2);
    final color = MM.worldColors[o.world];

    if (o.decoy) {
      _sprite(canvas, A.obj(o.world, o.key), c, h * 0.86, opacity: alpha * 0.34, grey: true);
      return;
    }

    if (inZone) {
      _sprite(canvas, A.sparks[o.world], c, h * 2.0, opacity: alpha * 0.55);
      canvas.drawCircle(
        c,
        h * 0.62,
        Paint()
          ..color = color.withValues(alpha: 0.22 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      c.translate(0, h * 0.42),
      h * 0.3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    _sprite(canvas, A.obj(o.world, o.key), c, h * (locked ? 1.06 : 1.0), opacity: alpha);
    if (locked) {
      _sprite(canvas, A.sparkGold, c, h * 1.5, opacity: 0.4 * alpha);
    }
  }

  // ------------------------------------------------------------ reveal & merge

  /// Third Eye booster: faint silhouettes of the realities you are not in.
  void _paintRevealGhosts(Canvas canvas, StageMap map) {
    for (final w in engine.worlds) {
      if (w.index == engine.currentWorld) continue;
      final time = engine.timeOf(w);
      final warped = w.warped(time);
      for (final o in w.targets) {
        final pos = map.toScreen(_project(w, o.positionAt(warped), time));
        final zone = map.toScreen(_project(w, o.zone, time));
        final d = (o.positionAt(warped) - o.zone).distance;
        final near = (1 - d / (engine.cfg.tolerance * 3)).clamp(0.0, 1.0);
        final color = MM.worldColors[w.index];
        canvas.drawLine(
          zone,
          pos,
          Paint()
            ..color = color.withValues(alpha: 0.18 + near * 0.3)
            ..strokeWidth = 1.2,
        );
        canvas.drawCircle(zone, map.len(engine.cfg.tolerance) * 0.5,
            Paint()..color = color.withValues(alpha: 0.16));
        canvas.drawCircle(pos, 4 + near * 4,
            Paint()..color = color.withValues(alpha: 0.45 + near * 0.5));
      }
    }
  }

  void _paintMerge(Canvas canvas, StageMap map) {
    final p = (engine.mergeT / GameEngine.mergeDuration).clamp(0.0, 1.0);
    final ease = Curves.easeOutCubic.transform(p);

    for (final w in engine.worlds) {
      final lift = (1 - ease) * (w.index - 1) * 26.0;
      _paintWorld(canvas, map, w, (1 - p * 0.55).clamp(0.0, 1.0), lift: lift);
    }

    final ref = engine.worlds[0];
    for (final o in ref.targets) {
      final c = map.toScreen(_project(ref, o.zone, engine.timeOf(ref)));
      final r = map.len(engine.cfg.tolerance);
      _sprite(canvas, A.burst, c, r * (2.6 + ease * 3.4), opacity: (1 - ease) * 0.7);
      _sprite(canvas, A.ringGold, c, r * (2.2 + ease * 3.2), opacity: (1 - ease) * 0.75,
          rotation: ease * 2.2);
      canvas.drawCircle(
        c,
        r * (0.6 + ease * 3.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ease)
          ..color = MM.goldBright.withValues(alpha: (1 - ease) * 0.9),
      );
    }

    final flare = (1 - p) * 0.5;
    if (flare > 0) {
      canvas.drawRect(
        Offset.zero & map.rect.size,
        Paint()..color = MM.goldBright.withValues(alpha: flare * 0.35),
      );
    }
  }

  // ------------------------------------------------------------------ helpers

  Offset _project(WorldRun w, Offset p, double time) {
    var q = p;
    if (w.spin != 0) {
      final a = w.spin * time;
      final d = q - Field.center;
      q = Field.center + Offset(d.dx * cos(a) - d.dy * sin(a), d.dx * sin(a) + d.dy * cos(a));
    }
    if (w.mirrored) q = Offset(Field.w - q.dx, q.dy);
    return q;
  }

  void _sprite(
    Canvas canvas,
    String key,
    Offset center,
    double targetHeight, {
    double opacity = 1,
    double rotation = 0,
    bool grey = false,
  }) {
    final img = bank[key];
    if (img == null || opacity <= 0.01) return;
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = targetHeight / max(iw, ih);
    final w = iw * scale;
    final h = ih * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
    if (grey) {
      paint.colorFilter = const ColorFilter.matrix(<double>[
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StagePainter old) => true;
}
