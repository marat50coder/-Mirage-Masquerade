import 'package:flutter/material.dart';

import '../studio/assets.dart';
import '../studio/audio.dart';
import '../studio/palette.dart';
import '../studio/progress.dart';
import '../ornament/ornate.dart';
import '../ornament/result_dialogs.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static final _art = <Booster, String>{
    Booster.reveal: A.globe,
    Booster.slow: A.obj(1, 'clock'),
    Booster.life: A.obj(2, 'mask'),
  };

  static const _icons = <Booster, IconData>{
    Booster.reveal: Icons.visibility_rounded,
    Booster.slow: Icons.hourglass_bottom_rounded,
    Booster.life: Icons.favorite_rounded,
  };

  static const _colors = <Booster, Color>{
    Booster.reveal: Color(0xFF54B9F0),
    Booster.slow: MM.emerald,
    Booster.life: MM.crimson,
  };

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return MMScreen(
      title: 'THE PROPS ROOM',
      background: 3,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          Center(child: CoinPill(amount: p.coins, height: 40)),
          const SizedBox(height: 8),
          Text(
            'Masks are earned by finishing acts and daily challenges.',
            textAlign: TextAlign.center,
            style: MM.body(12, color: MM.parchment.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),
          for (final b in Booster.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GoldPanel(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _colors[b]!.withValues(alpha: 0.6),
                            MM.deep,
                          ],
                        ),
                        border: Border.all(color: _colors[b]!, width: 1.6),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(_art[b]!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_icons[b], size: 16, color: _colors[b]),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  boosterNames[b]!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MM.title(14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MM.night.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: MM.gold.withValues(alpha: 0.5)),
                                ),
                                child: Text('x${p.boosters[b] ?? 0}', style: MM.body(10)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            boosterDetails[b]!,
                            style: MM.body(11, color: MM.parchment.withValues(alpha: 0.84)),
                          ),
                          const SizedBox(height: 9),
                          GoldButton(
                            label: 'BUY · ${boosterPrices[b]} MASKS',
                            height: 42,
                            fontSize: 13,
                            color: _colors[b],
                            enabled: p.coins >= boosterPrices[b]!,
                            sound: Sfx.reward,
                            onTap: () {
                              if (p.buyBooster(b)) {
                                Audio.instance.impact();
                                showMMToast(context, '${boosterNames[b]} added to your props');
                              } else {
                                showMMToast(context, 'Not enough masks', good: false);
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
