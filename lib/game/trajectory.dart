import 'dart:math';
import 'dart:ui';

/// The virtual stage every level is authored in. It is letterboxed into
/// whatever space the device gives us, so gameplay is identical everywhere.
class Field {
  Field._();
  static const double w = 100;
  static const double h = 160;
  static const Offset center = Offset(w / 2, h / 2);
}

enum PathKind { line, ellipse, figureEight, arc, lissajous }

/// A closed loop of period 1 in its parameter `u`, which is what keeps the
/// three realities mathematically guaranteed to be solvable.
class Path2 {
  const Path2({
    required this.kind,
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.rot,
    this.swing = 1.0,
    this.skew = 0.0,
  });

  final PathKind kind;
  final double cx, cy, rx, ry, rot;
  final double swing;
  final double skew;

  Offset at(double u) {
    final tau = 2 * pi * u;
    double lx, ly;
    switch (kind) {
      case PathKind.line:
        lx = sin(tau) * rx;
        ly = 0;
      case PathKind.ellipse:
        lx = cos(tau) * rx;
        ly = sin(tau) * ry;
      case PathKind.figureEight:
        lx = sin(tau) * rx;
        ly = sin(2 * tau) * ry;
      case PathKind.arc:
        final a = swing * sin(tau);
        lx = sin(a) * rx;
        ly = (1 - cos(a)) * ry;
      case PathKind.lissajous:
        lx = sin(2 * tau) * rx;
        ly = sin(3 * tau + skew) * ry;
    }
    final c = cos(rot), s = sin(rot);
    return Offset(cx + lx * c - ly * s, cy + lx * s + ly * c);
  }

  /// Field units travelled per unit of `u` at the given point of the loop.
  double speedAt(double u) {
    const e = 0.0025;
    return (at(u + e) - at(u - e)).distance / (2 * e);
  }

  /// Axis-aligned box the loop sweeps through.
  Rect bounds() {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 72; i++) {
      final o = at(i / 72);
      if (o.dx < minX) minX = o.dx;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy < minY) minY = o.dy;
      if (o.dy > maxY) maxY = o.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Sliding the loop moves every point on it — including the sync zone — by
  /// exactly the same amount, so alignment timing is untouched.
  Path2 translated(double dx, double dy) => Path2(
    kind: kind,
    cx: cx + dx,
    cy: cy + dy,
    rx: rx,
    ry: ry,
    rot: rot,
    swing: swing,
    skew: skew,
  );

  /// Same loop shrunk towards its own centre, which scales its speed too.
  Path2 scaled(double k) => Path2(
    kind: kind,
    cx: cx,
    cy: cy,
    rx: rx * k,
    ry: ry * k,
    rot: rot,
    swing: swing,
    skew: skew,
  );
}

/// One illusion object living inside one reality.
class MObject {
  MObject({
    required this.key,
    required this.world,
    required this.path,
    required this.phase,
    required this.period,
    required this.size,
    required this.decoy,
    required this.phantom,
    required this.phantomOffset,
  });

  final String key;
  final int world;

  /// Mutable so the round calibrator can shrink a loop that moves too fast.
  Path2 path;
  final double phase;

  /// Seconds for one full loop. Always a whole fraction of the world period.
  double period;
  final double size;
  final bool decoy;
  final bool phantom;
  final double phantomOffset;

  Offset zone = Offset.zero;

  Offset positionAt(double warped) => path.at(phase + warped / period);

  /// 0.3 .. 1.0 — how visible a fading illusion currently is. It never goes
  /// fully transparent, so a faded object can still be tracked by eye.
  double opacityAt(double warped) {
    if (!phantom) return 1;
    final u = phase + warped / period + phantomOffset;
    final v = 0.5 + 0.5 * sin(2 * pi * u);
    return 0.3 + 0.7 * (v * v);
  }
}

/// A whole reality: its objects, its heartbeat and its lock state.
class WorldRun {
  WorldRun({
    required this.index,
    required this.objects,
    required this.period,
    required this.alignAt,
    required this.warpAmp,
    required this.spin,
    required this.mirrored,
  });

  final int index;
  final List<MObject> objects;

  /// Seconds between two consecutive alignment moments.
  double period;

  /// First moment (in level time) at which this reality lines up.
  double alignAt;

  /// Amplitude of the tempo warp; 0 means a steady beat.
  double warpAmp;

  /// Radians per second the whole constellation revolves on screen.
  double spin;

  final bool mirrored;

  bool locked = false;
  double lockedAt = 0;

  Iterable<MObject> get targets => objects.where((o) => !o.decoy);

  /// Monotonic time warp with warped(t + period) == warped(t) + period, so
  /// tempo can breathe without ever breaking the alignment schedule.
  double warped(double t) {
    if (warpAmp == 0) return t;
    return t + warpAmp * period / (2 * pi) * sin(2 * pi * t / period);
  }

  void assignZones() {
    final w = warped(alignAt);
    for (final o in objects) {
      o.zone = o.positionAt(w);
    }
  }

  /// Worst object distance from its zone, in field units.
  double worstDistance(double t) {
    final w = warped(t);
    var worst = 0.0;
    for (final o in targets) {
      final d = (o.positionAt(w) - o.zone).distance;
      if (d > worst) worst = d;
    }
    return worst;
  }

  /// 0 = far away, 1 = dead centre.
  double closeness(double t, double tolerance) {
    final d = worstDistance(t);
    return (1 - d / tolerance).clamp(0.0, 1.0);
  }

  bool isAligned(double t, double tolerance) => worstDistance(t) <= tolerance;

  /// Half-length in seconds of the alignment window around an alignment beat.
  double windowHalf(double tolerance) {
    const step = 0.015;
    var s = 0.0;
    while (s < 1.4) {
      final n = s + step;
      if (worstDistance(alignAt + n) > tolerance || worstDistance(alignAt - n) > tolerance) {
        break;
      }
      s = n;
    }
    return s;
  }

  /// Time until the next alignment beat from `t`.
  double timeToNextBeat(double t) {
    final k = ((t - alignAt) / period).ceil();
    final next = alignAt + k * period;
    return next - t;
  }
}
