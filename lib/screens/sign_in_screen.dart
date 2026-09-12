import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

/// The first screen, and the only thing it asks for is a name.
///
/// There is no server behind RewireMind, no password and nothing to verify —
/// the habits live on this phone and nowhere else. So a sign-in that posted
/// credentials somewhere would be theatre, and a sign-in that demanded an
/// email would be collecting something the app has no use for.
///
/// What an account is here is the name the app greets you by and the photo on
/// your profile, and one field is the whole of it. Everything else can be
/// changed later from Profile; nothing here is a decision anybody has to get
/// right first time.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canGo => _name.text.trim().isNotEmpty;

  Future<void> _go() async {
    if (!_canGo || _busy) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    await state.updateProfile(state.profile.copyWith(name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: k.geometry.screenPadding + 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/brand/icon.png',
                        width: 88,
                        height: 88,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    AppContent.signInTitle,
                    style: k.text.sectionTitle.copyWith(
                      fontSize: 26,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppContent.signInBody,
                    style: k.text.body.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _name,
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _go(),
                    decoration: InputDecoration(
                      hintText: AppContent.signInHint,
                      hintStyle: k.text.caption,
                      filled: true,
                      fillColor: k.colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          k.geometry.innerRadius,
                        ),
                        borderSide: BorderSide(color: k.colors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          k.geometry.innerRadius,
                        ),
                        borderSide: BorderSide(color: k.colors.outline),
                      ),
                    ),
                    style: k.text.body.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canGo && !_busy ? _go : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: k.colors.accent,
                        disabledBackgroundColor: k.colors.accentTrack,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            k.geometry.pillRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        AppContent.signInGo,
                        style: k.text.captionStrong.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Said here rather than buried in a policy, because it is
                  // the reason there is nothing else on this screen.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: k.colors.textMuted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          AppContent.signInPrivacy,
                          style: k.text.caption.copyWith(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
