import 'dart:async';

import 'package:flutter/material.dart';

/// Every transient message in the app goes through here.
///
/// `SnackBar.duration` is not honoured on the Flutter version this app is
/// built against — a snackbar shown with a four second duration simply stays
/// on screen until something else replaces it, which reads as a stuck screen
/// and, with an Undo action on it, as an unfinished delete.
///
/// So the timer is ours: the message is closed explicitly once [duration] has
/// passed, unless the user dismissed it or tapped its action first. Any
/// message already showing is cleared, so a run of quick taps leaves one
/// confirmation rather than a queue of them.
Future<void> showAppSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );

  // `closed` completes on tap, dismissal or replacement, in which case the
  // timeout never fires and nothing is closed twice.
  unawaited(
    controller.closed.timeout(
      duration,
      onTimeout: () {
        controller.close();
        return SnackBarClosedReason.timeout;
      },
    ),
  );
}
