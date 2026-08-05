/// Central registry of every bundled image so the boot screen can preload
/// exactly what the game will draw later.
class A {
  A._();

  static const objectKeys = <String>[
    'lion',
    'joker',
    'card',
    'mask',
    'mirror',
    'clock',
    'gem',
    'tent',
    'orb',
  ];

  static const objectLabels = <String, String>{
    'lion': 'Royal Lion',
    'joker': 'Court Jester',
    'card': 'Fate Card',
    'mask': 'Plume Mask',
    'mirror': 'Scrying Glass',
    'clock': 'Hour Relic',
    'gem': 'Prism Shard',
    'tent': 'Grand Pavilion',
    'orb': 'Sigil Orb',
  };

  static String obj(int world, String key) => 'assets/img/obj/w${world}_$key.webp';

  static const ringGold = 'assets/img/fx/ring_gold.webp';
  static const rings = <String>[
    'assets/img/fx/ring_w0.webp',
    'assets/img/fx/ring_w1.webp',
    'assets/img/fx/ring_w2.webp',
  ];
  static const haloGold = 'assets/img/fx/halo_gold.webp';
  static const halos = <String>[
    'assets/img/fx/halo_w0.webp',
    'assets/img/fx/halo_w1.webp',
    'assets/img/fx/halo_w2.webp',
  ];
  static const sparks = <String>[
    'assets/img/fx/spark_w0.webp',
    'assets/img/fx/spark_w1.webp',
    'assets/img/fx/spark_w2.webp',
  ];
  static const sparkGold = 'assets/img/fx/spark_gold.webp';
  static const spirals = <String>[
    'assets/img/fx/spiral_w0.webp',
    'assets/img/fx/spiral_w1.webp',
    'assets/img/fx/spiral_w2.webp',
  ];
  static const spiralGold = 'assets/img/fx/spiral_gold.webp';
  static const burst = 'assets/img/fx/burst.webp';
  static const pillar = 'assets/img/fx/pillar.webp';
  static const orbGold = 'assets/img/fx/orb_gold.webp';
  static const ornament = 'assets/img/fx/ornament.webp';

  static const logo = 'assets/img/ui/logo.webp';
  static const appIcon = 'assets/img/ui/app_icon.webp';
  static const jokerMenu = 'assets/img/ui/joker_menu.webp';
  static const jokerAlt = 'assets/img/ui/joker_alt.webp';
  static const star = 'assets/img/ui/star.webp';
  static const medalRed = 'assets/img/ui/medal_red.webp';
  static const medalGreen = 'assets/img/ui/medal_green.webp';
  static const sealRed = 'assets/img/ui/seal_red.webp';
  static const wingHeart = 'assets/img/ui/wing_heart.webp';
  static const circusTent = 'assets/img/ui/circus_tent.webp';
  static const globe = 'assets/img/ui/globe.webp';
  static const suits = <String>[
    'assets/img/ui/suit_heart.webp',
    'assets/img/ui/suit_diamond.webp',
    'assets/img/ui/suit_club.webp',
    'assets/img/ui/suit_spade.webp',
  ];

  static String bg(int i) => 'assets/img/bg/loc${i + 1}.webp';
  static const bgCount = 6;

  static const loadV = 'assets/img/screen/load_v.webp';
  static const loadH = 'assets/img/screen/load_h.webp';

  /// Sprites drawn by the game canvas — these must live in the [ImageBank].
  static List<String> canvasImages() => <String>[
    for (var w = 0; w < 3; w++)
      for (final k in objectKeys) obj(w, k),
    ...rings,
    ringGold,
    ...halos,
    haloGold,
    ...sparks,
    sparkGold,
    ...spirals,
    spiralGold,
    burst,
    pillar,
    orbGold,
    ornament,
  ];

  /// Images shown by ordinary widgets — precached so nothing pops in.
  static List<String> widgetImages() => <String>[
    logo,
    appIcon,
    jokerMenu,
    jokerAlt,
    star,
    medalRed,
    medalGreen,
    sealRed,
    wingHeart,
    circusTent,
    globe,
    ...suits,
    for (var i = 0; i < bgCount; i++) bg(i),
  ];
}

/// Sound effect names, matching files inside `assets/sfx/`.
class Sfx {
  Sfx._();
  static const click = 'button_click';
  static const back = 'button_back';
  static const menuOpen = 'menu_open';
  static const menuClose = 'menu_close';
  static const popup = 'popup_open';
  static const tab = 'tab_switch';
  static const realitySwitch = 'reality_switch';
  static const objectMatch = 'object_match';
  static const objectPlace = 'object_place';
  static const objectSelect = 'object_select';
  static const combo = 'combo';
  static const levelComplete = 'level_complete';
  static const levelFailed = 'level_failed';
  static const reward = 'reward';
  static const achievement = 'achievement_unlock';
  static const countdown = 'countdown_tick';
  static const notification = 'notification';
  static const ambient = 'ambient_loop';
}
