import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'content/app_content.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class RewireMindApp extends StatelessWidget {
  const RewireMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.select<AppState, RewireMindTheme>((s) => s.theme);
    // The one gate in the app. There is no server to sign in to — what an
    // account means here is the name it greets you by — so the whole check is
    // whether anybody has said who they are yet.
    final named = context.select<AppState, bool>(
      (s) => s.profile.name.trim().isNotEmpty,
    );

    return MaterialApp(
      title: AppContent.appName,
      debugShowCheckedModeBanner: false,
      theme: theme.toThemeData(),
      home: named ? const HomeShell() : const SignInScreen(),
    );
  }
}
