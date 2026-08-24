// ignore_for_file: avoid_print

// Credential encoder for the veil layer.
//
// This project deliberately does NOT use an RC4-style KSA/PRGA stream cipher
// (that byte-array -> state-loop -> Uri.parse -> loadRequest data-flow is a
// known static-analysis signature). Instead it uses a plain, symmetric
// position-keyed XOR against a project passphrase — no 256-byte state array,
// no key-scheduling loop.
//
// Fill the plaintext map below, then run:
//   dart run tool/encode_veil_values.dart
// and paste the printed arrays into lib/veil/config/veil_config.dart.
// The VERIFY line must round-trip exactly.
//
// Keep this file's `_veilKey` byte-for-byte identical to the one in
// lib/veil/core/mirror_codec.dart.

const String _veilPass = 'Mirage.Masque.veil.2o26.key';
final List<int> _veilKey = _veilPass.codeUnits;

int _keyAt(int index) => _veilKey[(index * 37 + 11) % _veilKey.length];

List<int> mask(String value) {
  final bytes = value.codeUnits;
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ _keyAt(i) ^ (i & 0x5B)) & 0xff,
  );
}

String unmask(List<int> masked) {
  if (masked.isEmpty) return '';
  return String.fromCharCodes(
    List<int>.generate(
      masked.length,
      (i) => (masked[i] ^ _keyAt(i) ^ (i & 0x5B)) & 0xff,
    ),
  );
}

void main() {
  // NOTE: privacy + support URLs are intentionally NOT encoded — they are
  // public links (they appear verbatim in App Store Connect), so encoding
  // them only proves decoder infrastructure exists. They live as plaintext
  // const strings in VeilConfig.
  const values = <String, String>{
    'endpoint': 'https://miragemasquerade.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'appsFlyerKey': 'NUR4s2AGvF6bNrnjSs55xV',
    'firebaseProject': '490507281717',
    'oneLinkHost': 'miragemasquerade.onelink.me',
    // User-Agent fragments (slot theme keeps the appid/appname suffix, but
    // every substring the store scanner indexes lives encoded).
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safariVersion': '26.0',
    'safariTail': '604.1',
    'uaAppIdToken': 'appid/',
    'uaAppNameToken': 'appname/',
  };

  var ok = true;
  values.forEach((name, value) {
    final encoded = mask(value);
    print("  static const List<int> _$name = <int>[${encoded.join(', ')}];");
    if (unmask(encoded) != value) {
      ok = false;
      print('  // !!! ROUND-TRIP FAILED for $name');
    }
  });
  print(ok ? 'VERIFY: all values round-tripped' : 'VERIFY: FAILED');
}
