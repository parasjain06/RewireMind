import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../screens/photo_crop_screen.dart';
import 'app_snackbar.dart';

/// The person's own face, where they have given one.
///
/// Falls back to the brain rather than to a grey silhouette: a placeholder
/// that looks like a missing photograph makes the absence of one feel like an
/// omission. The winking brain is the app's own character, and it makes the
/// profile look like somebody's before there is a photo to put there.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({super.key, required this.size, this.onTap});

  final double size;

  /// Given, the circle is tappable and says so. The small copies dotted around
  /// the app are not — there should be one place to change this.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final path = context.select<AppState, String?>((s) => s.profile.photoPath);

    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            k.colors.accent.withValues(alpha: 0.26),
            k.colors.primary.withValues(alpha: 0.38),
          ],
        ),
      ),
      child: path == null
          ? _Mascot(size: size)
          // Keyed on the path so replacing the photograph actually repaints:
          // Flutter caches decoded files by path, and a new file under a new
          // name is the only thing that reliably invalidates that.
          : Image.file(
              File(path),
              key: ValueKey(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A file can go missing — a backup restored from another phone,
              // or storage cleared by the system. Falling back beats a broken
              // image glyph on somebody's own profile.
              errorBuilder: (context, error, stack) => _Mascot(size: size),
            ),
    );

    if (onTap == null) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: circle),
        ),
        // A small camera badge. A circle that merely happens to be tappable is
        // a circle nobody taps.
        Positioned(
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: k.colors.surface,
                border: Border.all(color: k.colors.accent, width: 1.4),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: size * 0.24,
                color: k.colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks a photograph, or takes the current one away.
///
/// The chosen file is copied into the app's own directory. What the picker
/// hands back is a cache path the system is free to delete whenever it likes,
/// so keeping that would mean a profile picture that quietly vanishes.
Future<void> chooseProfilePhoto(BuildContext context) async {
  final state = context.read<AppState>();

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _PhotoSheet(canRemove: state.profile.photoPath != null),
  );
  if (action == null || !context.mounted) return;

  if (action == 'remove') {
    await state.updateProfile(state.profile.copyWith(clearPhoto: true));
    return;
  }

  try {
    final shot = await ImagePicker().pickImage(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      // Big enough to zoom into while framing, small enough that a
      // twelve-megapixel photograph is not carried around whole.
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 88,
    );
    if (shot == null) return;
    // Read before the context is used again, so there is no await between the
    // mounted check and the push.
    final bytes = await shot.readAsBytes();
    if (!context.mounted) return;

    // Framed by hand rather than centre-cropped for them: a photograph of two
    // people cropped to its middle is a photograph of neither.
    final framed = await PhotoCropScreen.open(context, bytes);
    if (framed == null) return;

    final dir = await getApplicationDocumentsDirectory();
    // Stamped, so the name changes every time and Flutter's image cache
    // cannot serve the old picture from the new one's path.
    final at = DateTime.now().millisecondsSinceEpoch;
    final saved = File('${dir.path}/avatar_$at.png');
    await saved.writeAsBytes(framed);

    final previous = state.profile.photoPath;
    await state.updateProfile(state.profile.copyWith(photoPath: saved.path));

    // Only once the new one is safely in place.
    if (previous != null && previous != saved.path) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        // Already gone. Nothing to do, and nothing worth saying about it.
      }
    }
  } catch (_) {
    if (context.mounted) {
      await showAppSnackBar(context, message: AppContent.photoFailed);
    }
  }
}

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.canRemove});

  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: k.colors.accentTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _Row(
              icon: Icons.photo_library_outlined,
              label: AppContent.photoFromGallery,
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            _Row(
              icon: Icons.photo_camera_outlined,
              label: AppContent.photoFromCamera,
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            if (canRemove)
              _Row(
                icon: Icons.delete_outline,
                label: AppContent.photoRemove,
                danger: true,
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tint = danger ? k.colors.danger : k.colors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: 14),
            Text(
              label,
              style: k.text.cardTitle.copyWith(fontSize: 15, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// The default face: the winking brain, framed head to toe in the circle.
class _Mascot extends StatelessWidget {
  const _Mascot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Image.asset(
        'assets/brand/avatar.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
