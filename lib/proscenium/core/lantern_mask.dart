/// Position-keyed XOR decoder for house-layer secrets.
///
/// No RC4-style KSA/PRGA: no 256-byte permutation, no key-scheduling loop.
/// Each byte is mixed against a project passphrase, an index stride and a
/// nibble mask. Keep `_housePass` identical to tool/encode_house_brief.dart.
const String _housePass = 'Lantern.proscenium.MM26.ward';
final List<int> _houseKey = _housePass.codeUnits;

int _mixAt(int index) => _houseKey[(index * 41 + 19) % _houseKey.length];

String lanternReveal(List<int> masked) {
  if (masked.isEmpty) return '';
  final out = List<int>.filled(masked.length, 0);
  for (var i = 0; i < masked.length; i++) {
    out[i] = (masked[i] ^ _mixAt(i) ^ (i & 0x3E)) & 0xff;
  }
  return String.fromCharCodes(out);
}
