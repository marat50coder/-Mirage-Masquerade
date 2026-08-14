import 'dart:math';

import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../game/level.dart';
import '../widgets/ornate.dart';
import 'daily_screen.dart';
import 'gallery_screen.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Audio.instance.startMusic();
    Progress.instance.addListener(_onProgress);
  }

  @override
  void dispose() {
    Progress.instance.removeListener(_onProgress);
    _float.dispose();
    super.dispose();
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget page) async {
    Audio.instance.play(Sfx.menuOpen);
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    final p = Progress.instance;
    if (!p.tutorialSeen) {
      p.markTutorialSeen();
      await _open(const HowToPlayScreen());
      if (!mounted) return;
    }
    final next = p.highestUnlocked.clamp(0, Levels.count - 1);
    await _open(GameScreen(levelIndex: next));
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final claimable = p.dailyTasks.where((t) => p.dailyDone(t) && !p.dailyIsClaimed(t)).length;
    final nextLevel = Levels.at(p.highestUnlocked.clamp(0, Levels.count - 1));

    return Scaffold(
      backgroundColor: MM.night,
      body: Backdrop(
        background: 0,
        dim: 0.58,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < 700;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: [
                        _StatPill(
                          asset: A.star,
                          value: '${p.totalStars}/${Levels.count * 3}',
                        ),
                        const SizedBox(width: 8),
                        CoinPill(amount: p.coins),
                        const Spacer(),
                        RoundGlyphButton(
                          icon: Icons.help_outline_rounded,
                          size: 36,
                          sound: Sfx.popup,
                          onTap: () => _open(const HowToPlayScreen()),
                        ),
                        const SizedBox(width: 8),
                        RoundGlyphButton(
                          icon: Icons.insights_rounded,
                          size: 36,
                          sound: Sfx.tab,
                          onTap: () => _open(const StatsScreen()),
                        ),
                        const SizedBox(width: 8),
                        RoundGlyphButton(
                          icon: Icons.settings_rounded,
                          size: 36,
                          sound: Sfx.menuOpen,
                          onTap: () => _open(const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -18,
                          bottom: -10,
                          child: AnimatedBuilder(
                            animation: _float,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, sin(_float.value * pi) * 6),
                              child: child,
                            ),
                            child: Opacity(
                              opacity: 0.85,
                              child: Image.asset(A.jokerMenu, height: compact ? 132 : 190),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -22,
                          bottom: -6,
                          child: AnimatedBuilder(
                            animation: _float,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, -sin(_float.value * pi) * 7),
                              child: child,
                            ),
                            child: Opacity(
                              opacity: 0.8,
                              child: Image.asset(A.jokerAlt, height: compact ? 118 : 168),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(height: compact ? 4 : 12),
                            AnimatedBuilder(
                              animation: _float,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, sin(_float.value * pi) * 4 - 2),
                                child: child,
                              ),
                              child: Image.asset(
                                A.logo,
                                height: compact ? 140 : 190,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: compact ? 2 : 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'THREE REALITIES · ONE PERFORMANCE',
                                  maxLines: 1,
                                  style: MM.body(11, color: MM.parchment)
                                      .copyWith(letterSpacing: 2.2, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  GoldButton(
                                    label: p.highestUnlocked == 0
                                        ? 'BEGIN THE SHOW'
                                        : 'CONTINUE',
                                    subtitle:
                                        'Act ${nextLevel.number} · ${nextLevel.title}',
                                    height: 74,
                                    fontSize: 22,
                                    icon: Icons.play_arrow_rounded,
                                    onTap: _play,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: MenuTile(
                                          label: 'ACTS',
                                          icon: Icons.grid_view_rounded,
                                          color: MM.amethyst,
                                          sound: Sfx.tab,
                                          onTap: () =>
                                              _open(const LevelSelectScreen()),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Badged(
                                          count: claimable,
                                          child: MenuTile(
                                            label: 'DAILY',
                                            icon: Icons.task_alt_rounded,
                                            color: MM.emerald,
                                            sound: Sfx.tab,
                                            onTap: () =>
                                                _open(const DailyScreen()),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MenuTile(
                                          label: 'SHOP',
                                          icon: Icons.storefront_rounded,
                                          color: MM.crimson,
                                          sound: Sfx.tab,
                                          onTap: () =>
                                              _open(const ShopScreen()),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MenuTile(
                                          label: 'GALLERY',
                                          icon: Icons.theater_comedy_rounded,
                                          color: const Color(0xFF3E8FD6),
                                          sound: Sfx.tab,
                                          onTap: () =>
                                              _open(const GalleryScreen()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.asset, required this.value});
  final String asset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 5, right: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: MM.deep.withValues(alpha: 0.86),
        border: Border.all(color: MM.gold.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, height: 24),
          const SizedBox(width: 6),
          Text(value, style: MM.title(15)),
        ],
      ),
    );
  }
}

