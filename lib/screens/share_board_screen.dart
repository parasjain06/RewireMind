import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/habit_board.dart';
import '../widgets/share_board.dart';

/// The board, dressed for somebody else's screen.
///
/// Not the same picture as the one on Home. That board is a control — it
/// scrolls, it opens things, it is surrounded by a nav bar — and a capture of
/// it arrives in a chat as a screenshot of an app. This one has a title, a
/// name, the dates it covers and the app it came from, because a picture that
/// leaves the phone has to explain itself to somebody who has never seen this
/// screen.
class ShareBoardScreen extends StatefulWidget {
  const ShareBoardScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ShareBoardScreen()));
  }

  @override
  State<ShareBoardScreen> createState() => _ShareBoardScreenState();
}

class _ShareBoardScreenState extends State<ShareBoardScreen> {
  final _shot = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    await BoardShare.send(context, boundary: _shot);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: k.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            AppContent.shareTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                0,
                k.geometry.screenPadding,
                12,
              ),
              child: Text(AppContent.shareBlurb, style: k.text.caption),
            ),

            // Exactly what gets sent, at the size it gets sent at. A preview
            // that differs from the picture is worse than no preview.
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: k.geometry.screenPadding,
                ),
                child: RepaintBoundary(
                  key: _shot,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    decoration: BoxDecoration(
                      color: k.colors.surface,
                      borderRadius: BorderRadius.circular(
                        k.geometry.cardRadius,
                      ),
                      boxShadow: k.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.profile.name.isEmpty
                              ? AppContent.shareCardTitleAnon
                              : AppContent.shareCardTitle(
                                  state.profile.firstName,
                                ),
                          style: k.text.sectionTitle.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppContent.shareCardSubtitle(
                            state.everyHabit.length,
                            HabitBoard.days,
                          ),
                          style: k.text.caption.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: HabitBoard(
                            // Nothing here goes anywhere: this is a picture.
                            onOpenDay: (_, _) {},
                            onOpenDate: (_) {},
                            showShare: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_outlined,
                              size: 14,
                              color: k.colors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppContent.shareCardFooter,
                              style: k.text.caption.copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                14,
                k.geometry.screenPadding,
                18,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.ios_share, size: 19),
                  label: Text(
                    AppContent.shareAction,
                    style: k.text.captionStrong.copyWith(
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: k.colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        k.geometry.pillRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
