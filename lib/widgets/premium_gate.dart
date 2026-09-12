import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/premium_screen.dart';
import '../state/app_state.dart';

/// Runs [unlocked] if this copy of the app is paid for, and otherwise opens
/// the premium page saying which locked thing was reached for.
///
/// One function rather than a check at each door: every gate then looks the
/// same to whoever adds the next one, and the page always knows why it opened.
Future<void> ifPremium(
  BuildContext context,
  String note,
  FutureOr<void> Function() unlocked,
) async {
  if (context.read<AppState>().isPremium) {
    await unlocked();
    return;
  }
  await PremiumScreen.open(context, note: note);
}
