import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../content/app_content.dart';
import 'app_snackbar.dart';

/// Turns whatever is inside a [RepaintBoundary] into a PNG and offers it to
/// whatever the phone can send a picture to.
///
/// The board is the one thing in this app worth showing somebody — ten weeks
/// of your own colour, and no explanation needed. What it is not is something
/// anybody can screenshot cleanly: it scrolls in two directions inside a card
/// on a page with a nav bar under it. So the app draws it again, off screen,
/// at whatever size it really is, and hands over the picture.
///
/// A seam for tests, which have no share sheet and no file system worth
/// writing to: when this is false the picture is still rendered and the sheet
/// is simply not opened.
bool boardSharingAvailable = true;

class BoardShare {
  const BoardShare._();

  /// Renders [boundary] and opens the share sheet with it.
  ///
  /// Returns the bytes it produced so a caller can check the work; null when
  /// the boundary was not ready or the render failed.
  static Future<Uint8List?> send(
    BuildContext context, {
    required GlobalKey boundary,
    String? message,
  }) async {
    final bytes = await capture(boundary);
    if (bytes == null) {
      if (context.mounted) {
        await showAppSnackBar(context, message: AppContent.shareFailed);
      }
      return null;
    }
    if (!boardSharingAvailable) return bytes;

    try {
      final dir = await getTemporaryDirectory();
      // Overwritten every time rather than accumulating: this is a picture on
      // its way somewhere, not a file anybody is keeping.
      final file = File('${dir.path}/rewiremind-board.png');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: message ?? AppContent.shareMessage,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        await showAppSnackBar(context, message: AppContent.shareFailed);
      }
    }
    return bytes;
  }

  /// The PNG behind [boundary], at three times its on-screen size.
  ///
  /// Three because the picture leaves the phone: it will be looked at on
  /// somebody else's screen, at whatever size their app decides, and a
  /// one-to-one capture of a 360dp board looks like a thumbnail there.
  static Future<Uint8List?> capture(GlobalKey boundary) async {
    final object = boundary.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    final image = await object.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }
}
