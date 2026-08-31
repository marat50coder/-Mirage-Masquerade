// ignore_for_file: avoid_print

// Credential encoder for the house (dual-mode) layer.
//
// Position-keyed XOR against a project passphrase. No RC4-style KSA/PRGA
// (no 256-byte state, no key-scheduling loop).
//
//   dart run tool/encode_house_brief.dart
// Paste the printed arrays into lib/proscenium/config/house_brief.dart.
// VERIFY must round-trip exactly.
//
// Keep `_housePass` byte-for-byte identical to lib/proscenium/core/lantern_mask.dart.

const String _housePass = 'Lantern.proscenium.MM26.ward';
final List<int> _houseKey = _housePass.codeUnits;

int _keyAt(int index) => _houseKey[(index * 41 + 19) % _houseKey.length];

List<int> mask(String value) {
  final bytes = value.codeUnits;
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ _keyAt(i) ^ (i & 0x3E)) & 0xff,
  );
}

String unmask(List<int> masked) {
  if (masked.isEmpty) return '';
  return String.fromCharCodes(
    List<int>.generate(
      masked.length,
      (i) => (masked[i] ^ _keyAt(i) ^ (i & 0x3E)) & 0xff,
    ),
  );
}

void main() {
  const values = <String, String>{
    'endpoint': 'https://miragemasquerade.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'appsFlyerKey': 'NUR4s2AGvF6bNrnjSs55xV',
    'firebaseProject': '490507281717',
    'oneLinkHost': 'miragemasquerade.onelink.me',
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
