import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'daily.dart';

enum Booster { reveal, slow, life }

const boosterPrices = <Booster, int>{
  Booster.reveal: 120,
  Booster.slow: 150,
  Booster.life: 200,
};

const boosterNames = <Booster, String>{
  Booster.reveal: 'Third Eye',
  Booster.slow: 'Hour Relic',
  Booster.life: 'Spare Mask',
};

const boosterDetails = <Booster, String>{
  Booster.reveal: 'Reveals the alignment of all three realities for 6 seconds.',
  Booster.slow: 'Slows every reality to half speed for 8 seconds.',
  Booster.life: 'Restores one attempt during a performance.',
};

/// Single source of truth for everything that survives an app restart.
class Progress extends ChangeNotifier {
  Progress._();
  static final Progress instance = Progress._();

  static const _key = 'mirage_masquerade_save_v1';

  SharedPreferences? _prefs;

  int highestUnlocked = 0;
  final Map<int, int> stars = {};
  final Map<int, int> bestScore = {};

  int coins = 150;
  int totalSyncs = 0;
  int totalPerfect = 0;
  int totalSwitches = 0;
  int totalObjects = 0;
  int levelsCompleted = 0;
  int bestCombo = 0;
  int bestOverallScore = 0;
  int secondsPlayed = 0;

  bool soundOn = true;
  bool musicOn = true;
  bool hapticsOn = true;
  bool hintsOn = true;

  bool notificationsPromptSeen = false;
  bool notificationsAllowed = false;
  bool tutorialSeen = false;

  String? avatarPath;

  final Map<Booster, int> boosters = {
    Booster.reveal: 1,
    Booster.slow: 1,
    Booster.life: 1,
  };

  String _dailyDate = '';
  final Map<String, int> dailyProgress = {};
  final Set<String> dailyClaimed = {};

  List<DailyTask> get dailyTasks => DailyTasks.forDate(DateTime.now());

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    _rollDailyIfNeeded();
    Audio.instance
      ..soundEnabled = soundOn
      ..musicEnabled = musicOn
      ..hapticsEnabled = hapticsOn;
  }

  void _fromJson(Map<String, dynamic> j) {
    highestUnlocked = j['highestUnlocked'] as int? ?? 0;
    stars
      ..clear()
      ..addAll((j['stars'] as Map?)?.map((k, v) => MapEntry(int.parse('$k'), v as int)) ?? {});
    bestScore
      ..clear()
      ..addAll((j['bestScore'] as Map?)?.map((k, v) => MapEntry(int.parse('$k'), v as int)) ?? {});
    coins = j['coins'] as int? ?? 150;
    totalSyncs = j['totalSyncs'] as int? ?? 0;
    totalPerfect = j['totalPerfect'] as int? ?? 0;
    totalSwitches = j['totalSwitches'] as int? ?? 0;
    totalObjects = j['totalObjects'] as int? ?? 0;
    levelsCompleted = j['levelsCompleted'] as int? ?? 0;
    bestCombo = j['bestCombo'] as int? ?? 0;
    bestOverallScore = j['bestOverallScore'] as int? ?? 0;
    secondsPlayed = j['secondsPlayed'] as int? ?? 0;
    soundOn = j['soundOn'] as bool? ?? true;
    musicOn = j['musicOn'] as bool? ?? true;
    hapticsOn = j['hapticsOn'] as bool? ?? true;
    hintsOn = j['hintsOn'] as bool? ?? true;
    notificationsPromptSeen = j['notifSeen'] as bool? ?? false;
    notificationsAllowed = j['notifAllowed'] as bool? ?? false;
    tutorialSeen = j['tutorialSeen'] as bool? ?? false;
    avatarPath = j['avatarPath'] as String?;
    final b = j['boosters'] as Map?;
    if (b != null) {
      for (final k in Booster.values) {
        boosters[k] = b[k.name] as int? ?? 0;
      }
    }
    _dailyDate = j['dailyDate'] as String? ?? '';
    dailyProgress
      ..clear()
      ..addAll((j['dailyProgress'] as Map?)?.map((k, v) => MapEntry('$k', v as int)) ?? {});
    dailyClaimed
      ..clear()
      ..addAll(((j['dailyClaimed'] as List?) ?? const []).map((e) => '$e'));
  }

  Map<String, dynamic> _toJson() => {
    'highestUnlocked': highestUnlocked,
    'stars': stars.map((k, v) => MapEntry('$k', v)),
    'bestScore': bestScore.map((k, v) => MapEntry('$k', v)),
    'coins': coins,
    'totalSyncs': totalSyncs,
    'totalPerfect': totalPerfect,
    'totalSwitches': totalSwitches,
    'totalObjects': totalObjects,
    'levelsCompleted': levelsCompleted,
    'bestCombo': bestCombo,
    'bestOverallScore': bestOverallScore,
    'secondsPlayed': secondsPlayed,
    'soundOn': soundOn,
    'musicOn': musicOn,
    'hapticsOn': hapticsOn,
    'hintsOn': hintsOn,
    'notifSeen': notificationsPromptSeen,
    'notifAllowed': notificationsAllowed,
    'tutorialSeen': tutorialSeen,
    'avatarPath': avatarPath,
    'boosters': {for (final k in Booster.values) k.name: boosters[k] ?? 0},
    'dailyDate': _dailyDate,
    'dailyProgress': dailyProgress,
    'dailyClaimed': dailyClaimed.toList(),
  };

  void _rollDailyIfNeeded() {
    final today = DailyTasks.dateKey(DateTime.now());
    if (_dailyDate != today) {
      _dailyDate = today;
      dailyProgress.clear();
      dailyClaimed.clear();
      _save();
    }
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode(_toJson()));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  void setSound(bool v) {
    soundOn = v;
    Audio.instance.soundEnabled = v;
    _commit();
  }

  void setMusic(bool v) {
    musicOn = v;
    Audio.instance.musicEnabled = v;
    Audio.instance.applyMusicSetting();
    _commit();
  }

  void setHaptics(bool v) {
    hapticsOn = v;
    Audio.instance.hapticsEnabled = v;
    _commit();
  }

  void setHints(bool v) {
    hintsOn = v;
    _commit();
  }

  void markNotificationPrompt(bool allowed) {
    notificationsPromptSeen = true;
    notificationsAllowed = allowed;
    _commit();
  }

  void markTutorialSeen() {
    tutorialSeen = true;
    _commit();
  }

  void setAvatarPath(String? path) {
    avatarPath = path;
    _commit();
  }

  // ------------------------------------------------------------------ dailies

  void bumpDaily(DailyMetric metric, int amount) {
    if (amount <= 0) return;
    _rollDailyIfNeeded();
    final k = metric.name;
    if (metric == DailyMetric.combo) {
      dailyProgress[k] = (dailyProgress[k] ?? 0) < amount ? amount : dailyProgress[k]!;
    } else {
      dailyProgress[k] = (dailyProgress[k] ?? 0) + amount;
    }
  }

  int dailyValue(DailyMetric m) => dailyProgress[m.name] ?? 0;

  bool dailyDone(DailyTask t) => dailyValue(t.metric) >= t.target;

  bool dailyIsClaimed(DailyTask t) => dailyClaimed.contains(t.key);

  bool claimDaily(DailyTask t) {
    if (!dailyDone(t) || dailyIsClaimed(t)) return false;
    dailyClaimed.add(t.key);
    coins += t.reward;
    _commit();
    return true;
  }

  // ------------------------------------------------------------------- store

  bool buyBooster(Booster b) {
    final price = boosterPrices[b]!;
    if (coins < price) return false;
    coins -= price;
    boosters[b] = (boosters[b] ?? 0) + 1;
    _commit();
    return true;
  }

  bool consumeBooster(Booster b) {
    final n = boosters[b] ?? 0;
    if (n <= 0) return false;
    boosters[b] = n - 1;
    _commit();
    return true;
  }

  // ---------------------------------------------------------------- gameplay

  void recordSwitches(int n) {
    totalSwitches += n;
    bumpDaily(DailyMetric.switches, n);
  }

  void recordRun({
    required int levelIndex,
    required bool won,
    required int score,
    required int starsEarned,
    required int syncs,
    required int perfects,
    required int objectsMerged,
    required int switches,
    required int combo,
    required int secondsLeft,
    required int secondsSpent,
  }) {
    totalSyncs += syncs;
    totalPerfect += perfects;
    totalObjects += objectsMerged;
    totalSwitches += switches;
    secondsPlayed += secondsSpent;
    if (combo > bestCombo) bestCombo = combo;
    if (score > bestOverallScore) bestOverallScore = score;

    bumpDaily(DailyMetric.syncs, syncs);
    bumpDaily(DailyMetric.perfect, perfects);
    bumpDaily(DailyMetric.objects, objectsMerged);
    bumpDaily(DailyMetric.switches, switches);
    bumpDaily(DailyMetric.combo, combo);

    if (won) {
      levelsCompleted += 1;
      bumpDaily(DailyMetric.levels, 1);
      if (secondsLeft >= 30) bumpDaily(DailyMetric.swift, 1);
      if ((stars[levelIndex] ?? 0) < starsEarned) stars[levelIndex] = starsEarned;
      if (levelIndex >= highestUnlocked) highestUnlocked = levelIndex + 1;
      coins += 20 + starsEarned * 15;
    }
    if ((bestScore[levelIndex] ?? 0) < score) bestScore[levelIndex] = score;
    _commit();
  }

  void resetAll() {
    highestUnlocked = 0;
    stars.clear();
    bestScore.clear();
    coins = 150;
    totalSyncs = 0;
    totalPerfect = 0;
    totalSwitches = 0;
    totalObjects = 0;
    levelsCompleted = 0;
    bestCombo = 0;
    bestOverallScore = 0;
    secondsPlayed = 0;
    tutorialSeen = false;
    avatarPath = null;
    boosters
      ..[Booster.reveal] = 1
      ..[Booster.slow] = 1
      ..[Booster.life] = 1;
    dailyProgress.clear();
    dailyClaimed.clear();
    _commit();
  }
}
