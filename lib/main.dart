import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/storage.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. Every screen in the app is a single column — the header
  // scene, the habit list, the 21-day path — and none of them has a landscape
  // arrangement worth having. Locking it here as well as in the manifest
  // covers the moment before the manifest applies, and covers iOS later.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storage = await RewireMindStorage.open();
  final state = AppState(storage);
  await state.load();
  // The store, in the background: it answers in its own time and nothing on
  // screen waits for it.
  unawaited(state.startBilling());

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const RewireMindApp(),
    ),
  );
}
