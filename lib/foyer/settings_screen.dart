import 'package:flutter/material.dart';

import '../studio/assets.dart';
import '../studio/audio.dart';
import '../studio/palette.dart';
import '../studio/progress.dart';
import '../studio/reminders.dart';
import '../ornament/ornate.dart';
import '../ornament/result_dialogs.dart';
import 'web_view_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openPage(
    String title,
    String url, {
    bool fullScreen = false,
    bool stretchContent = false,
  }) {
    Audio.instance
      ..play(Sfx.menuOpen)
      ..tapFeedback();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MMWebViewScreen(
          title: title,
          url: url,
          fullScreen: fullScreen,
          stretchContent: stretchContent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    return MMScreen(
      title: 'STAGE SETTINGS',
      background: 3,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          GoldPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                _Toggle(
                  icon: Icons.music_note_rounded,
                  label: 'Ambient music',
                  value: p.musicOn,
                  onChanged: (v) => setState(() => p.setMusic(v)),
                ),
                const _Divider(),
                _Toggle(
                  icon: Icons.volume_up_rounded,
                  label: 'Sound effects',
                  value: p.soundOn,
                  onChanged: (v) => setState(() => p.setSound(v)),
                ),
                const _Divider(),
                _Toggle(
                  icon: Icons.vibration_rounded,
                  label: 'Haptics',
                  value: p.hapticsOn,
                  onChanged: (v) => setState(() => p.setHaptics(v)),
                ),
                const _Divider(),
                _Toggle(
                  icon: Icons.timeline_rounded,
                  label: 'Show motion trails',
                  subtitle: 'Draws the path each object follows',
                  value: p.hintsOn,
                  onChanged: (v) => setState(() => p.setHints(v)),
                ),
                const _Divider(),
                _Toggle(
                  icon: Icons.notifications_active_rounded,
                  label: 'Bonus reminders',
                  value: p.notificationsAllowed,
                  onChanged: (v) async {
                    final granted = await Reminders.instance.setEnabled(v);
                    if (!mounted) return;
                    setState(() => p.markNotificationPrompt(granted && v));
                    if (v && !granted && context.mounted) {
                      showMMToast(
                        context,
                        'Permission denied for reminders',
                        good: false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GoldPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Image.asset(A.appIcon, height: 66),
                const SizedBox(height: 10),
                Text('MIRAGE MASQUERADE', style: MM.title(15)),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.2 (14)',
                  style: MM.body(11, color: MM.parchment.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Three realities run at once. Only one is ever visible.\n'
                  'Bring them into a single moment and the show goes on.',
                  textAlign: TextAlign.center,
                  style: MM.body(11, color: MM.parchment.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GoldButton(
                  label: 'PRIVACY POLICY',
                  color: MM.amethyst,
                  height: 54,
                  fontSize: 13,
                  icon: Icons.privacy_tip_rounded,
                  onTap: () => _openPage(
                    'PRIVACY POLICY',
                    'https://miragemasquerade.com/privacy-policy.html',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoldButton(
                  label: 'SUPPORT',
                  color: MM.emerald,
                  height: 54,
                  fontSize: 13,
                  icon: Icons.support_agent_rounded,
                  onTap: () => _openPage(
                    'SUPPORT',
                    'https://miragemasquerade.com/support.html',
                    fullScreen: true,
                    stretchContent: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoldButton(
            label: 'RESET ALL PROGRESS',
            color: MM.crimson,
            height: 54,
            fontSize: 15,
            icon: Icons.delete_forever_rounded,
            sound: Sfx.back,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: GoldPanel(
                      tint: const Color(0xFF35131E),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ERASE THE PLAYBILL?', style: MM.title(17, color: MM.danger)),
                          const SizedBox(height: 8),
                          Text(
                            'Every act, star, mask and record will be lost.',
                            textAlign: TextAlign.center,
                            style: MM.body(12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GoldButton(
                                  label: 'CANCEL',
                                  height: 48,
                                  fontSize: 14,
                                  onTap: () => Navigator.of(context).pop(false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GoldButton(
                                  label: 'ERASE',
                                  color: MM.crimson,
                                  height: 48,
                                  fontSize: 14,
                                  onTap: () => Navigator.of(context).pop(true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (confirmed == true && context.mounted) {
                p.resetAll();
                showMMToast(context, 'Progress erased', good: false);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(color: MM.gold.withValues(alpha: 0.2), height: 1);
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: MM.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MM.body(14, color: MM.parchment)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: MM.body(10, color: MM.parchment.withValues(alpha: 0.62)),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: MM.goldBright,
            activeTrackColor: MM.goldDeep,
            inactiveThumbColor: MM.parchment.withValues(alpha: 0.6),
            inactiveTrackColor: MM.velvet,
            onChanged: (v) {
              Audio.instance
                ..play(v ? Sfx.click : Sfx.back)
                ..tapFeedback();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
