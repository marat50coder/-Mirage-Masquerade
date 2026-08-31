import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decoded sprites kept in memory so the game canvas can draw without ever
/// touching the asset bundle mid-frame.
class ImageBank {
  ImageBank._();
  static final ImageBank instance = ImageBank._();

  final Map<String, ui.Image> _images = {};

  ui.Image? operator [](String key) => _images[key];

  bool get isEmpty => _images.isEmpty;

  Future<void> load(String path, {int? targetWidth}) async {
    if (_images.containsKey(path)) return;
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    _images[path] = frame.image;
  }
}
