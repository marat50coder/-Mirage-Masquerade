import 'package:flutter/material.dart';

/// Colour language of the theatre: night velvet, antique gold and the three
/// reality hues that the whole game is built around.
class MM {
  MM._();

  static const night = Color(0xFF0E0718);
  static const deep = Color(0xFF1A0E2B);
  static const velvet = Color(0xFF2A1743);
  static const velvetLight = Color(0xFF3B2160);

  static const gold = Color(0xFFF5CE7A);
  static const goldBright = Color(0xFFFFE9A8);
  static const goldDeep = Color(0xFF9C6C22);
  static const parchment = Color(0xFFF7EAD0);

  static const crimson = Color(0xFFE8425C);
  static const amethyst = Color(0xFFA95CF2);
  static const emerald = Color(0xFF35CE83);

  static const danger = Color(0xFFFF5D5D);

  static const worldColors = <Color>[crimson, amethyst, emerald];
  static const worldDark = <Color>[
    Color(0xFF57121F),
    Color(0xFF3A1360),
    Color(0xFF0E4A2C),
  ];
  static const worldNames = <String>[
    'Crimson Cabaret',
    'Amethyst Illusion',
    'Emerald Mirage',
  ];
  static const worldRoman = <String>['I', 'II', 'III'];

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold, goldDeep],
  );

  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deep, night],
  );

  static TextStyle title(double size, {Color color = gold}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 1.6,
    height: 1.1,
    shadows: const [
      Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  static TextStyle body(double size, {Color color = parchment, FontWeight w = FontWeight.w600}) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: 0.3,
        height: 1.25,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      );
}
