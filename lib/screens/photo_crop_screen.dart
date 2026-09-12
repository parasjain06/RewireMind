import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';

/// Framing a photograph inside the circle it will be shown in.
///
/// Built here rather than handed to a cropper plugin, because what is needed is
/// narrow: one fixed circular window, pan and pinch, no aspect ratios and no
/// rotation. The whole thing is an [InteractiveViewer] over a square window,
/// captured at the end — which is also why what comes out is exactly what was
/// on screen, rather than a second guess at the same crop.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.image});

  final Uint8List image;

  /// Returns the framed square as PNG bytes, or null if it was abandoned.
  static Future<Uint8List?> open(BuildContext context, Uint8List image) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => PhotoCropScreen(image: image)),
    );
  }

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final GlobalKey _window = GlobalKey();
  bool _saving = false;

  /// What the saved image is captured at. The circle is shown at roughly 300
  /// points; three times that is enough for the largest place it appears and
  /// still a small file.
  static const double _outputPixels = 900;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final boundary =
        _window.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      Navigator.of(context).pop();
      return;
    }

    final ratio = _outputPixels / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop(bytes?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Scaffold(
      // Dark, whatever the app's palette is doing. A photograph is judged
      // against what surrounds it, and a tinted page would have you framing
      // against the wrong background.
      backgroundColor: const Color(0xFF14181C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppContent.cropTitle,
          style: k.text.sectionTitle.copyWith(
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = [
                    constraints.maxWidth - 40,
                    constraints.maxHeight - 40,
                    340.0,
                  ].reduce((a, b) => a < b ? a : b);

                  return SizedBox(
                    width: side,
                    height: side,
                    child: Stack(
                      children: [
                        // Only the window is captured, so whatever is scrolled
                        // out of it is genuinely not in the saved file.
                        RepaintBoundary(
                          key: _window,
                          child: ClipOval(
                            child: InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              // Lets a tall photograph be dragged past the
                              // edges of the window; without it the corners
                              // cannot be reached at all.
                              boundaryMargin: EdgeInsets.all(side),
                              child: Image.memory(
                                widget.image,
                                width: side,
                                height: side,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // A hairline ring over the top, so the edge of the
                        // circle is visible against a dark photograph.
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              AppContent.cropHint,
              textAlign: TextAlign.center,
              style: k.text.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: k.colors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(k.geometry.pillRadius),
                  ),
                ),
                child: Text(
                  AppContent.cropSave,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
