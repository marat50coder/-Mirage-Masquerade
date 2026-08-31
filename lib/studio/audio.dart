import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'assets.dart';

/// Small pooled sound engine: a handful of one-shot players plus a dedicated
/// looping player for the ambient theatre bed.
class Audio {
  Audio._();
  static final Audio instance = Audio._();

  static const _poolSize = 5;
  final List<AudioPlayer> _pool = [];

  /// Created inside [init] so simply touching the singleton never reaches for
  /// the platform channel.
  AudioPlayer? _music;
  int _next = 0;
  bool _ready = false;

  bool soundEnabled = true;
  bool musicEnabled = true;
  bool hapticsEnabled = true;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      for (var i = 0; i < _poolSize; i++) {
        final p = AudioPlayer(playerId: 'mm_sfx_$i');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(p);
      }
      final music = AudioPlayer(playerId: 'mm_ambient');
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(0.34);
      _music = music;
    } catch (_) {
      // Audio is a nicety; never let it break the launch sequence.
    }
  }

  void play(String name, {double volume = 0.85}) {
    if (!soundEnabled || _pool.isEmpty) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    unawaited(() async {
      try {
        await player.stop();
        await player.setVolume(volume);
        await player.play(AssetSource('sfx/$name.mp3'));
      } catch (_) {}
    }());
  }

  Future<void> startMusic() async {
    final music = _music;
    if (!musicEnabled || music == null) return;
    try {
      if (music.state == PlayerState.playing) return;
      await music.play(AssetSource('sfx/${Sfx.ambient}.mp3'), volume: 0.34);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  Future<void> applyMusicSetting() async {
    if (musicEnabled) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  void tapFeedback() {
    if (!hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  void impact() {
    if (!hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (!hapticsEnabled) return;
    HapticFeedback.heavyImpact();
  }
}
