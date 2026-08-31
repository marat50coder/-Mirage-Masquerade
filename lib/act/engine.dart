import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../studio/assets.dart';
import 'level.dart';
import 'trajectory.dart';

enum RunState { intro, playing, merging, won, lost }

enum FlashKind { none, missed, chainLost, locked, merged }

class GameEngine extends ChangeNotifier {
  GameEngine(this.cfg, {int? seed}) : _rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch) {
    remaining = cfg.timeLimit.toDouble();
    _buildRound();
  }

  final LevelConfig cfg;
  final Random _rng;

  RunState state = RunState.intro;

  /// Motion clock for the realities (slow-motion aware).
  double t = 0;

  /// Real elapsed seconds since the run started.
  double wall = 0;

  double remaining = 0;
  double introLeft = 2.4;
  double mergeT = 0;
  static const double mergeDuration = 1.9;

  late List<WorldRun> worlds;
  int currentWorld = 1;

  int round = 0;
  int lives = 0;
  int score = 0;
  int combo = 0;
  int maxCombo = 0;
  int syncs = 0;
  int perfects = 0;
  int objectsMerged = 0;
  int switches = 0;
  int misses = 0;

  double chainWindow = 12;
  double? chainStart;
  final List<double> _lockAccuracy = [];

  double revealUntil = -1;
  double slowUntil = -1;

  FlashKind flash = FlashKind.none;
  double flashT = 0;
  String flashText = '';
  double shake = 0;
  double mergeFlare = 0;
  int lastRoundScore = 0;

  bool get revealActive => wall < revealUntil;
  bool get slowActive => wall < slowUntil;
  bool get isRunning => state == RunState.playing || state == RunState.merging;
  double get progress => (round / cfg.roundsRequired).clamp(0.0, 1.0);
  double get chainLeft =>
      chainStart == null ? 0 : (chainWindow - (wall - chainStart!)).clamp(0.0, chainWindow);
  int get lockedCount => worlds.where((w) => w.locked).length;

  WorldRun get world => worlds[currentWorld];

  double timeOf(WorldRun w) => w.locked ? w.lockedAt : t;

  // ------------------------------------------------------------------ update

  void update(double dt) {
    if (state == RunState.won || state == RunState.lost) return;
    if (dt > 0.05) dt = 0.05;

    wall += dt;
    t += dt * (slowActive ? 0.5 : 1.0);

    if (flashT > 0) {
      flashT -= dt;
      if (flashT <= 0) flash = FlashKind.none;
    }
    if (shake > 0) shake = (shake - dt * 2.6).clamp(0.0, 1.0);
    if (mergeFlare > 0) mergeFlare = (mergeFlare - dt * 1.4).clamp(0.0, 1.0);

    switch (state) {
      case RunState.intro:
        introLeft -= dt;
        if (introLeft <= 0) state = RunState.playing;
      case RunState.playing:
        remaining -= dt;
        if (chainStart != null && wall - chainStart! > chainWindow) {
          _breakChain('RESONANCE LOST', FlashKind.chainLost);
        }
        if (remaining <= 0) {
          remaining = 0;
          _finish(false);
        }
      case RunState.merging:
        mergeT += dt;
        if (mergeT >= mergeDuration) {
          mergeT = 0;
          if (round >= cfg.roundsRequired) {
            _finish(true);
          } else {
            _buildRound();
            state = RunState.playing;
          }
        }
      case RunState.won:
      case RunState.lost:
        break;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- actions

  void switchWorld(int index) {
    if (index == currentWorld || index < 0 || index > 2) return;
    currentWorld = index;
    switches++;
    notifyListeners();
  }

  void switchBy(int delta) => switchWorld((currentWorld + delta + 3) % 3);

  /// Returns true when the tap landed on a genuine alignment.
  bool attemptSync() {
    if (state != RunState.playing) return false;
    final w = world;
    if (w.locked) return false;

    if (!w.isAligned(t, cfg.tolerance)) {
      misses++;
      lives--;
      combo = 0;
      _breakChain('OUT OF PHASE', FlashKind.missed);
      shake = 1;
      if (lives <= 0) _finish(false);
      return false;
    }

    _lockAccuracy.add(w.closeness(t, cfg.tolerance));
    w.locked = true;
    w.lockedAt = t;
    chainStart ??= wall;
    flash = FlashKind.locked;
    flashT = 0.7;
    flashText = 'REALITY ${MMRoman.of(w.index)} LOCKED';

    if (lockedCount == 3) {
      _completeSync();
    } else {
      final next = _firstUnlockedAfter(currentWorld);
      if (next != null) {
        currentWorld = next;
        switches++;
      }
    }
    notifyListeners();
    return true;
  }

  int? _firstUnlockedAfter(int from) {
    for (var i = 1; i <= 2; i++) {
      final idx = (from + i) % 3;
      if (!worlds[idx].locked) return idx;
    }
    return null;
  }

  void _completeSync() {
    final elapsed = wall - (chainStart ?? wall);
    final accuracy = _lockAccuracy.fold(0.0, (a, b) => a + b) / 3;
    final speedBonus = ((chainWindow - elapsed) / chainWindow).clamp(0.0, 1.0) * 150;
    final multiplier = 1 + combo * 0.25;
    final gained = ((320 + accuracy * 260 + speedBonus) * multiplier).round();

    lastRoundScore = gained;
    score += gained;
    syncs++;
    round++;
    combo++;
    if (combo > maxCombo) maxCombo = combo;
    objectsMerged += cfg.objectsPerWorld * 3;
    if (accuracy >= 0.62) perfects++;

    chainStart = null;
    _lockAccuracy.clear();
    state = RunState.merging;
    mergeT = 0;
    mergeFlare = 1;
    flash = FlashKind.merged;
    flashT = 1.2;
    flashText = accuracy >= 0.62 ? 'PERFECT SYNCHRONISATION' : 'WORLDS MERGED';
  }

  void _breakChain(String text, FlashKind kind) {
    for (final w in worlds) {
      w.locked = false;
    }
    _lockAccuracy.clear();
    chainStart = null;
    combo = 0;
    flash = kind;
    flashT = 1.0;
    flashText = text;
  }

  void _finish(bool won) {
    state = won ? RunState.won : RunState.lost;
    notifyListeners();
  }

  bool useReveal() {
    if (!isRunning) return false;
    revealUntil = wall + 6;
    notifyListeners();
    return true;
  }

  bool useSlow() {
    if (!isRunning) return false;
    slowUntil = wall + 8;
    notifyListeners();
    return true;
  }

  bool useExtraLife() {
    lives++;
    if (state == RunState.lost && remaining > 0) state = RunState.playing;
    notifyListeners();
    return true;
  }

  int get starsEarned {
    if (state != RunState.won) return 0;
    var s = 1;
    if (score >= cfg.targetTwoStars) s = 2;
    if (score >= cfg.targetThreeStars && misses <= 1) s = 3;
    return s;
  }

  // -------------------------------------------------------------- generation

  void _buildRound() {
    lives = lives == 0 ? cfg.lives : lives;
    final keys = List<String>.from(A.objectKeys)..shuffle(_rng);
    final chosen = keys.take(cfg.objectsPerWorld).toList();
    final decoyKey = keys.length > cfg.objectsPerWorld ? keys[cfg.objectsPerWorld] : keys.first;
    final mirroredWorld = cfg.mirrored ? _rng.nextInt(3) : -1;

    worlds = List.generate(3, (w) {
      final period = (2.9 + _rng.nextDouble() * 1.3) / cfg.speedScale;
      final run = WorldRun(
        index: w,
        objects: <MObject>[],
        period: period,
        alignAt: t + 1.6 + _rng.nextDouble() * period,
        warpAmp: cfg.speedShift ? 0.22 + _rng.nextDouble() * 0.3 : 0,
        spin: cfg.spinning ? (_rng.nextDouble() - 0.5) * 0.30 : 0,
        mirrored: w == mirroredWorld,
      );
      for (final key in chosen) {
        run.objects.add(_makeObject(key, w, run, run.objects, decoy: false));
      }
      if (cfg.decoys) {
        run.objects.add(_makeObject(decoyKey, w, run, run.objects, decoy: true));
      }
      run.assignZones();
      _calibrate(run);
      _separateZones(run);
      return run;
    });

    final periods = worlds.map((w) => w.period).toList()..sort();
    chainWindow = ((periods[2] + periods[1]) * 1.35 + 4.2) * cfg.chainFactor;
    chainWindow = chainWindow.clamp(8.0, 26.0);

    chainStart = null;
    _lockAccuracy.clear();
  }

  /// Tunes a reality so its objects never cross their zones faster than the
  /// player can react: first by slowing the beat, then — once the beat hits its
  /// ceiling — by shrinking the loops themselves.
  void _calibrate(WorldRun w) {
    const maxPeriod = 6.5;
    final minHalf = 0.32 - 0.11 * (cfg.index / (Levels.count - 1));
    final tol = cfg.tolerance;
    final harmonics = [for (final o in w.objects) (w.period / o.period).round().clamp(1, 4)];

    for (var iter = 0; iter < 6; iter++) {
      var needed = w.period;
      for (var i = 0; i < w.objects.length; i++) {
        final o = w.objects[i];
        if (o.decoy) continue;
        final u = o.phase + w.warped(w.alignAt) / o.period;
        final required = harmonics[i] * o.path.speedAt(u) * minHalf / tol;
        if (required > needed) needed = required;
      }
      if (needed <= w.period * 1.02) break;

      if (needed > maxPeriod) {
        final k = maxPeriod / needed;
        for (final o in w.objects) {
          o.path = o.path.scaled(k);
        }
        needed = maxPeriod;
      }
      w.period = needed;
      for (var i = 0; i < w.objects.length; i++) {
        w.objects[i].period = needed / harmonics[i];
      }
      w.assignZones();
    }

    // Last resort for pathological loops: tighten them until the beat is wide.
    for (var iter = 0; iter < 5 && w.windowHalf(tol) < minHalf * 0.6; iter++) {
      for (final o in w.objects) {
        o.path = o.path.scaled(0.72);
      }
      w.assignZones();
    }
  }

  /// Slides whole loops around until no two sync zones sit on top of each
  /// other, so the player can always tell the targets apart.
  void _separateZones(WorldRun w) {
    final targets = w.targets.toList();
    if (targets.length < 2) return;
    final minSep = cfg.tolerance * 2.3;

    for (var iter = 0; iter < 60; iter++) {
      var moved = false;
      for (var a = 0; a < targets.length; a++) {
        for (var b = a + 1; b < targets.length; b++) {
          final oa = targets[a];
          final ob = targets[b];
          var delta = ob.zone - oa.zone;
          var distance = delta.distance;
          if (distance >= minSep) continue;
          if (distance < 0.01) {
            final angle = (a * 2.4 + b * 1.1);
            delta = Offset(cos(angle), sin(angle));
            distance = 1;
          }
          final unit = delta / distance;
          final push = (minSep - distance) / 2 + 0.5;
          _slide(oa, unit * -push);
          _slide(ob, unit * push);
          moved = true;
        }
      }
      if (!moved) break;
    }
  }

  void _slide(MObject o, Offset delta) {
    const margin = 11.0;
    final b = o.path.bounds();
    final lowX = margin - b.left;
    final highX = (Field.w - margin) - b.right;
    final lowY = margin - b.top;
    final highY = (Field.h - margin) - b.bottom;
    final dx = highX < lowX ? 0.0 : delta.dx.clamp(lowX, highX);
    final dy = highY < lowY ? 0.0 : delta.dy.clamp(lowY, highY);
    if (dx == 0 && dy == 0) return;
    o.path = o.path.translated(dx, dy);
    o.zone = o.zone.translate(dx, dy);
  }

  MObject _makeObject(
    String key,
    int worldIndex,
    WorldRun run,
    List<MObject> existing, {
    required bool decoy,
  }) {
    final allowed = <PathKind>[
      PathKind.line,
      PathKind.arc,
      if (cfg.index >= 2) PathKind.ellipse,
      if (cfg.index >= 6) PathKind.figureEight,
      if (cfg.index >= 10) PathKind.lissajous,
    ];

    MObject? best;
    var bestSeparation = -1.0;
    for (var attempt = 0; attempt < 26; attempt++) {
      final kind = allowed[_rng.nextInt(allowed.length)];
      final rx = 13 + _rng.nextDouble() * 15;
      final ry = 11 + _rng.nextDouble() * 19;
      var path = Path2(
        kind: kind,
        cx: Field.w / 2,
        cy: Field.h / 2,
        rx: rx,
        ry: kind == PathKind.line ? 0 : ry,
        rot: _rng.nextDouble() * pi * 2,
        swing: 0.7 + _rng.nextDouble() * 0.5,
        skew: _rng.nextDouble() * pi,
      );
      path = _fitToStage(path);

      final harmonic = (!decoy && cfg.index >= 4 && _rng.nextDouble() < 0.35) ? 2 : 1;
      // Keep sprites just small enough that the sync ring stays readable
      // around them, which also shrinks them as tolerances tighten.
      final half = (cfg.tolerance).clamp(7.5, 12.0);
      final candidate = MObject(
        key: key,
        world: worldIndex,
        path: path,
        phase: _rng.nextDouble(),
        period: run.period / harmonic,
        size: decoy ? half * 0.8 : half,
        decoy: decoy,
        phantom: cfg.phantoms && !decoy && _rng.nextDouble() < 0.38,
        phantomOffset: _rng.nextDouble(),
      );
      candidate.zone = candidate.positionAt(run.warped(run.alignAt));

      if (decoy) return candidate;

      var separation = double.infinity;
      for (final o in existing) {
        if (o.decoy) continue;
        separation = min(separation, (o.zone - candidate.zone).distance);
      }
      if (separation > bestSeparation) {
        bestSeparation = separation;
        best = candidate;
      }
      if (separation >= cfg.tolerance * 2.8) return candidate;
    }
    return best!;
  }

  /// Re-centres and shrinks a loop so it always stays on the visible stage.
  Path2 _fitToStage(Path2 p) {
    const margin = 13.0;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 72; i++) {
      final o = p.at(i / 72);
      minX = min(minX, o.dx);
      maxX = max(maxX, o.dx);
      minY = min(minY, o.dy);
      maxY = max(maxY, o.dy);
    }
    final availW = Field.w - margin * 2;
    final availH = Field.h - margin * 2;
    final spanX = max(maxX - minX, 0.001);
    final spanY = max(maxY - minY, 0.001);
    final scale = min(1.0, min(availW / spanX, availH / spanY));

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final halfW = spanX * scale / 2;
    final halfH = spanY * scale / 2;
    final targetX = (margin + halfW) +
        _rng.nextDouble() * max(0.0, (Field.w - margin - halfW) - (margin + halfW));
    final targetY = (margin + halfH) +
        _rng.nextDouble() * max(0.0, (Field.h - margin - halfH) - (margin + halfH));

    return Path2(
      kind: p.kind,
      cx: p.cx + (targetX - cx),
      cy: p.cy + (targetY - cy),
      rx: p.rx * scale,
      ry: p.ry * scale,
      rot: p.rot,
      swing: p.swing,
      skew: p.skew,
    );
  }
}

class MMRoman {
  MMRoman._();
  static const _r = ['I', 'II', 'III'];
  static String of(int i) => _r[i.clamp(0, 2)];
}

/// Screen-space placement helper shared by the painter and hit testing.
class StageMap {
  StageMap(this.rect) {
    final s = min(rect.width / Field.w, rect.height / Field.h);
    scale = s;
    origin = Offset(
      rect.left + (rect.width - Field.w * s) / 2,
      rect.top + (rect.height - Field.h * s) / 2,
    );
  }

  final Rect rect;
  late final double scale;
  late final Offset origin;

  Offset toScreen(Offset field) => origin + Offset(field.dx * scale, field.dy * scale);
  double len(double fieldUnits) => fieldUnits * scale;
}
