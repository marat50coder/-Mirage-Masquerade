import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../studio/assets.dart';
import '../studio/audio.dart';
import '../studio/palette.dart';
import '../studio/progress.dart';
import 'ornate.dart';
import 'result_dialogs.dart';

/// Circular avatar chip shown next to the coin/stars pills.
///
/// Tapping it opens a bottom sheet where the player can take a fresh photo,
/// pick one from the library or remove the current picture. The chosen image
/// is copied into the app's documents directory so it survives across
/// launches even if the source file goes away.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final path = p.avatarPath;
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final hasImage = file != null && file.existsSync();

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MM.velvetLight, MM.deep],
          ),
          border: Border.all(color: MM.gold.withValues(alpha: 0.85), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
            : Icon(
                Icons.person_rounded,
                color: MM.gold.withValues(alpha: 0.9),
                size: size * 0.6,
              ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    Audio.instance
      ..play(Sfx.menuOpen)
      ..tapFeedback();
    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const _AvatarSheet(),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _AvatarChoice.camera:
        await _pickFrom(context, ImageSource.camera);
      case _AvatarChoice.library:
        await _pickFrom(context, ImageSource.gallery);
      case _AvatarChoice.remove:
        Progress.instance.setAvatarPath(null);
        if (context.mounted) showMMToast(context, 'Portrait removed');
    }
  }

  Future<void> _pickFrom(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null || !context.mounted) return;

      final docs = await getApplicationDocumentsDirectory();
      final ext = _extensionOf(picked.name);
      final target = File(
        '${docs.path}/avatar_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(picked.path).copy(target.path);

      final oldPath = Progress.instance.avatarPath;
      Progress.instance.setAvatarPath(target.path);
      if (oldPath != null && oldPath.isNotEmpty && oldPath != target.path) {
        final old = File(oldPath);
        if (old.existsSync()) {
          try {
            await old.delete();
          } catch (_) {}
        }
      }
      Audio.instance.play(Sfx.reward, volume: 0.7);
      if (context.mounted) showMMToast(context, 'Portrait updated');
    } catch (e) {
      if (!context.mounted) return;
      showMMToast(context, 'Could not open $source', good: false);
    }
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.jpg';
    return name.substring(dot).toLowerCase();
  }
}

enum _AvatarChoice { camera, library, remove }

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet();

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (Progress.instance.avatarPath ?? '').isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: GoldPanel(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: MM.gold.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('YOUR PORTRAIT', style: MM.title(16)),
              const SizedBox(height: 4),
              Text(
                'Choose the face that stands beside your masks.',
                textAlign: TextAlign.center,
                style: MM.body(11, color: MM.parchment.withValues(alpha: 0.78)),
              ),
              const SizedBox(height: 14),
              GoldButton(
                label: 'TAKE PHOTO',
                icon: Icons.photo_camera_rounded,
                onTap: () => Navigator.of(context).pop(_AvatarChoice.camera),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'CHOOSE FROM LIBRARY',
                icon: Icons.photo_library_rounded,
                color: MM.amethyst,
                height: 52,
                fontSize: 15,
                onTap: () => Navigator.of(context).pop(_AvatarChoice.library),
              ),
              if (hasAvatar) ...[
                const SizedBox(height: 10),
                GoldButton(
                  label: 'REMOVE PORTRAIT',
                  icon: Icons.delete_outline_rounded,
                  color: MM.crimson,
                  height: 48,
                  fontSize: 13,
                  sound: Sfx.back,
                  onTap: () => Navigator.of(context).pop(_AvatarChoice.remove),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
