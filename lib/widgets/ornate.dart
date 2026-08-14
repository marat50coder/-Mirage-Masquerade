import 'dart:math';

import 'package:flutter/material.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/palette.dart';

/// Gilded frame used for every panel in the game.
class GoldPanel extends StatelessWidget {
  const GoldPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
    this.borderWidth = 2,
    this.opacity = 0.94,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final double borderWidth;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? MM.velvet;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.10)!.withValues(alpha: opacity),
            Color.lerp(base, Colors.black, 0.42)!.withValues(alpha: opacity),
          ],
        ),
        border: Border.all(color: MM.gold.withValues(alpha: 0.72), width: borderWidth),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: MM.gold.withValues(alpha: 0.12), blurRadius: 22, spreadRadius: -6),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.assetIcon,
    this.subtitle,
    this.enabled = true,
    this.color,
    this.height = 60,
    this.fontSize = 18,
    this.sound = Sfx.click,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? assetIcon;
  final bool enabled;
  final Color? color;
  final double height;
  final double fontSize;
  final String sound;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final accent = widget.color ?? MM.gold;
    final radius = BorderRadius.circular(widget.height * 0.42);
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              Audio.instance
                ..play(widget.sound)
                ..tapFeedback();
              widget.onTap!.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.965 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, 0.48)!,
                  accent,
                  Color.lerp(accent, Colors.black, 0.52)!,
                ],
                stops: const [0, 0.5, 1],
              ),
              border: Border.all(
                color: Color.lerp(accent, Colors.white, 0.72)!,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _down ? 0.20 : 0.48),
                  blurRadius: _down ? 6 : 20,
                  offset: Offset(0, _down ? 2 : 8),
                  spreadRadius: _down ? -2 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: _down ? 0.28 : 0.40),
                  blurRadius: _down ? 4 : 10,
                  offset: Offset(0, _down ? 1 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: widget.height * 0.42,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.32),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: widget.icon != null || widget.assetIcon != null
                        ? EdgeInsets.only(
                            left: widget.height * 0.92,
                            right: 14,
                          )
                        : const EdgeInsets.symmetric(horizontal: 14),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: const Color(0xFF2A1204),
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.subtitle!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: widget.fontSize * 0.60,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF4A230C),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.assetIcon != null)
                    Positioned(
                      left: widget.height * 0.18,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _GlyphBadge(
                          size: widget.height * 0.62,
                          accent: accent,
                          child: Image.asset(
                            widget.assetIcon!,
                            height: widget.height * 0.44,
                          ),
                        ),
                      ),
                    )
                  else if (widget.icon != null)
                    Positioned(
                      left: widget.height * 0.18,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _GlyphBadge(
                          size: widget.height * 0.62,
                          accent: accent,
                          child: Icon(
                            widget.icon,
                            color: const Color(0xFF2A1204),
                            size: widget.fontSize + 6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphBadge extends StatelessWidget {
  const _GlyphBadge({required this.size, required this.accent, required this.child});

  final double size;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(accent, Colors.white, 0.62)!,
            Color.lerp(accent, Colors.black, 0.18)!,
          ],
        ),
        border: Border.all(
          color: Color.lerp(accent, Colors.black, 0.35)!,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Vertical menu tile: big glyph on top, label below. Used on the menu screen
/// for the secondary destinations (Acts / Daily / Shop / Gallery).
class MenuTile extends StatefulWidget {
  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = MM.gold,
    this.sound = Sfx.menuOpen,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String sound;

  @override
  State<MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<MenuTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        Audio.instance
          ..play(widget.sound)
          ..tapFeedback();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.965 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(MM.velvet, Colors.white, 0.08)!.withValues(alpha: 0.94),
                Color.lerp(MM.velvet, Colors.black, 0.48)!.withValues(alpha: 0.94),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.72), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _down ? 0.18 : 0.34),
                blurRadius: _down ? 8 : 16,
                offset: Offset(0, _down ? 2 : 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.50)!,
                      accent,
                      Color.lerp(accent, Colors.black, 0.35)!,
                    ],
                  ),
                  border: Border.all(
                    color: Color.lerp(accent, Colors.white, 0.55)!,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: const Color(0xFF2A1204), size: 24),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: MM.parchment,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundGlyphButton extends StatelessWidget {
  const RoundGlyphButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 46,
    this.color = MM.gold,
    this.sound = Sfx.back,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final String sound;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Audio.instance
          ..play(sound)
          ..tapFeedback();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MM.velvetLight, MM.deep],
          ),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
        ),
        child: Icon(icon, color: color, size: size * 0.52),
      ),
    );
  }
}

class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.count, this.size = 20, this.total = 3, this.gap = 2});

  final int count;
  final int total;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            child: Opacity(
              opacity: i < count ? 1 : 0.22,
              child: Image.asset(A.star, height: size),
            ),
          ),
      ],
    );
  }
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.amount, this.height = 34});

  final int amount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 4, right: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: MM.deep.withValues(alpha: 0.86),
        border: Border.all(color: MM.gold.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(A.medalRed, height: height - 6),
          const SizedBox(width: 6),
          Text('$amount', style: MM.title(height * 0.46)),
        ],
      ),
    );
  }
}

/// Wraps a control with a small crimson counter badge in the corner.
class Badged extends StatelessWidget {
  const Badged({super.key, required this.child, required this.count});

  final Widget child;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -5,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: MM.crimson,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: MM.goldBright, width: 1.6),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6)],
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section title with the little gold flourish underneath.
class Flourish extends StatelessWidget {
  const Flourish({super.key, required this.text, this.size = 24});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(text, textAlign: TextAlign.center, style: MM.title(size)),
        const SizedBox(height: 4),
        Image.asset(A.ornament, height: size * 0.62, opacity: const AlwaysStoppedAnimation(0.85)),
      ],
    );
  }
}

/// Full-screen theatre backdrop with a slow drift of golden motes.
class Backdrop extends StatefulWidget {
  const Backdrop({
    super.key,
    required this.child,
    this.background = 0,
    this.dim = 0.62,
    this.accent = MM.gold,
  });

  final Widget child;
  final int background;
  final double dim;
  final Color accent;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MM.night,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(A.bg(widget.background), fit: BoxFit.cover, alignment: Alignment.topCenter),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MM.night.withValues(alpha: widget.dim + 0.16),
                  MM.night.withValues(alpha: widget.dim),
                  MM.night.withValues(alpha: widget.dim + 0.26),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _MotePainter(_c.value, widget.accent),
              size: Size.infinite,
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _MotePainter extends CustomPainter {
  _MotePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(19);
    for (var i = 0; i < 42; i++) {
      final bx = rng.nextDouble();
      final by = rng.nextDouble();
      final sp = 0.4 + rng.nextDouble() * 1.4;
      final r = 0.7 + rng.nextDouble() * 2.4;
      final y = (by - t * sp) % 1.0;
      final x = (bx + sin((t * 6.28 + i)) * 0.012) % 1.0;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = color.withValues(alpha: 0.08 + 0.20 * rng.nextDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.t != t;
}

/// Standard screen chrome: backdrop, top bar with back button and title.
class MMScreen extends StatelessWidget {
  const MMScreen({
    super.key,
    required this.title,
    required this.child,
    this.background = 0,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget child;
  final int background;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MM.night,
      body: Backdrop(
        background: background,
        dim: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    RoundGlyphButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack ?? () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MM.title(21),
                        ),
                      ),
                    ),
                    SizedBox(width: 46, child: trailing),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
