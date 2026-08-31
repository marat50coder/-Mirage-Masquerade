/// Difficulty curve for the 24 performances of Mirage Masquerade.
class LevelConfig {
  const LevelConfig({
    required this.index,
    required this.location,
    required this.title,
    required this.objectsPerWorld,
    required this.roundsRequired,
    required this.lives,
    required this.timeLimit,
    required this.tolerance,
    required this.speedScale,
    required this.chainFactor,
    required this.phantoms,
    required this.decoys,
    required this.mirrored,
    required this.spinning,
    required this.speedShift,
  });

  final int index;
  final int location;
  final String title;
  final int objectsPerWorld;
  final int roundsRequired;
  final int lives;
  final int timeLimit;

  /// Radius, in field units, within which an object counts as "in its zone".
  final double tolerance;
  final double speedScale;

  /// Multiplier applied to the resonance chain window (lower = harsher).
  final double chainFactor;

  final bool phantoms;
  final bool decoys;
  final bool mirrored;
  final bool spinning;
  final bool speedShift;

  int get number => index + 1;

  int get targetTwoStars => roundsRequired * 430;
  int get targetThreeStars => roundsRequired * 640;

  List<String> get modifiers => [
    if (phantoms) 'Fading illusions',
    if (decoys) 'Phantom doubles',
    if (mirrored) 'Mirrored stage',
    if (spinning) 'Revolving scenery',
    if (speedShift) 'Shifting tempo',
  ];
}

const _locationNames = <String>[
  'Velvet Prologue',
  'Crimson Grand Hall',
  'Sapphire Reverie',
  'Ivory Gala',
  'Amethyst Nocturne',
  'Emerald Finale',
];

const _actTitles = <String>[
  'Opening Bow', 'Two Lanterns', 'The Slow Waltz', 'Rehearsal Ends',
  'Scarlet Overture', 'Fading Players', 'Ribbons of Light', 'The Ringmaster Calls',
  'Sapphire Descent', 'Doubles in the Dark', 'Glass Corridor', 'Tempo of Tides',
  'Ivory Procession', 'Reflections Askew', 'The Pale Carousel', 'Gilded Clockwork',
  'Amethyst Nocturne', 'Whispering Spires', 'Revolving Masks', 'Midnight Assembly',
  'Emerald Awakening', 'The Shifting Choir', 'Three Crowns', 'Grand Finale',
];

class Levels {
  Levels._();

  static const count = 24;

  static String locationName(int location) => _locationNames[location];

  static final List<LevelConfig> all = List.generate(count, _build);

  static LevelConfig at(int i) => all[i.clamp(0, count - 1)];

  static LevelConfig _build(int i) {
    final location = i ~/ 4;
    final objects = i < 3
        ? 1
        : i < 7
        ? 2
        : i < 12
        ? 3
        : i < 18
        ? 4
        : 5;
    final rounds = 3 + (i ~/ 4);
    final lives = i < 8
        ? 5
        : i < 16
        ? 4
        : 3;
    final p = i / (count - 1);
    return LevelConfig(
      index: i,
      location: location,
      title: _actTitles[i],
      objectsPerWorld: objects,
      roundsRequired: rounds,
      lives: lives,
      timeLimit: (96 + rounds * 11).clamp(110, 175),
      tolerance: 9.4 - 3.9 * p,
      speedScale: 0.82 + 0.78 * p,
      chainFactor: 1.05 - 0.3 * p,
      phantoms: i >= 5,
      decoys: i >= 8,
      mirrored: i >= 11,
      spinning: i >= 14,
      speedShift: i >= 17,
    );
  }
}
