/// Symmetric, position-keyed XOR decoder for the veil layer's stored secrets.
///
/// Deliberately NOT an RC4-style KSA/PRGA stream cipher: there is no 256-byte
/// permutation state and no key-scheduling loop, so the binary carries no
/// `byte-array -> state loop -> Uri.parse -> loadRequest` signature. Each byte
/// is XORed against a project passphrase keyed by position plus a small index
/// mix — the same transform used by tool/encode_veil_values.dart.
///
/// Keep `_veilPass` byte-for-byte identical to the encoder tool.
const String _veilPass = 'Mirage.Masque.veil.2o26.key';
final List<int> _veilKey = _veilPass.codeUnits;

int _keyAt(int index) => _veilKey[(index * 37 + 11) % _veilKey.length];

String unmaskString(List<int> masked) {
  if (masked.isEmpty) return '';
  final out = List<int>.filled(masked.length, 0);
  for (var i = 0; i < masked.length; i++) {
    out[i] = (masked[i] ^ _keyAt(i) ^ (i & 0x5B)) & 0xff;
  }
  return String.fromCharCodes(out);
}
