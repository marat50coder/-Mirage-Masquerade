# Mirage Masquerade

A vertical iOS puzzle-timing game built in Flutter. Three parallel realities of the
same masquerade run side by side, each on its own heartbeat. Swipe between them and
lock each reality the moment its illusions drift into their sync rings — then lock
all three inside one resonance window to merge them.

- Bundle identifier: `com.miragemasque.masqueradegame`
- Orientation: portrait-only in game, portrait **and** landscape on the loading screen
- Language: English

## Running it

```bash
flutter pub get
flutter run -d <device>
```

Release build for a physical device:

```bash
flutter build ios --release
```

## How the game works

Each of the three realities holds a handful of drifting objects, and every object has
one sync ring it periodically passes through. A reality is "aligned" when *all* of its
objects sit inside their rings at once; tap the stage (or the dial) at that instant to
lock it. Locking the first reality opens the resonance window, and all three must be
locked before it closes.

Later acts stack modifiers on top: extra objects, tighter tolerances, decoy doubles,
illusions that fade in and out, mirrored realities, spinning zones and speed shifts.

Scoring rewards precision — a lock inside the inner tolerance counts as *perfect* and
builds a combo multiplier. Stars are awarded per level from score, perfects and the
time left on the clock.

## Project layout

```
lib/
  core/       palette, asset registry, image cache, audio engine, save data, daily tasks
  game/       level definitions, trajectory math, the engine, the stage painter
  widgets/    ornate shared UI, HUD, pause/result dialogs, connectivity gate
  screens/    boot, notifications, menu, game, levels, daily, shop, gallery, stats,
              settings, how-to-play
assets/
  img/obj     per-reality object sprites
  img/fx      rings, halos, bursts, sparks
  img/ui      buttons, panels, frames, icons
  img/bg      stage backdrops
  img/screen  loading art (portrait + landscape) and logos
  sfx/        music and sound effects
```

`GameEngine` owns the run: it generates each round from a `LevelConfig`, calibrates
every reality so its objects never cross a ring faster than a player can react, and
pushes sync zones apart so targets stay visually distinct. It is a `ChangeNotifier`
driven by a `Ticker`, and `StagePainter` repaints straight off it.

## Tests

```bash
flutter test                                   # solvability + resonance-window checks
flutter test test/balance_probe.dart           # per-level difficulty read-out
flutter test test/screens_golden_test.dart --update-goldens   # re-render test/shots/*
```

`test/screens_golden_test.dart` renders every screen head-less into `test/shots/`,
which is how the UI is reviewed without a device. Text appears as blocks there because
the test environment ships no real fonts — only layout and artwork are meaningful.
