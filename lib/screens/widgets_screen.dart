import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/day_phase.dart';
import '../notifications/home_widget_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/completion_effects.dart';
import '../widgets/widget_previews.dart';
import '../content/premium_content.dart';
import 'premium_screen.dart';

/// The four things a widget can show.
enum WidgetView { mascot, list, week, month }

/// Choosing a home screen widget, and adding it.
///
/// Laid out like a phone's own widget gallery: the widget itself, drawn with
/// your habits in it, on a stage at the top; what it shows underneath; and
/// one button. The previous page described three shapes in words next to a
/// brain emoji, which is a lot of reading to choose a rectangle.
class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key, this.onboarding = false});

  /// True when this is the last step of a first launch. The screen then has no
  /// back arrow and a "Not now" at the foot instead — a step you finish rather
  /// than a settings page you wandered into.
  final bool onboarding;

  static Future<void> open(BuildContext context, {bool onboarding = false}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WidgetsScreen(onboarding: onboarding)),
    );
  }

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  WidgetView _view = WidgetView.mascot;

  /// Which mascot size, remembered while you look at the other views.
  WidgetKind _mascotSize = WidgetKind.medium;

  WidgetKind get _kind => switch (_view) {
    WidgetView.mascot => _mascotSize,
    WidgetView.list => WidgetKind.list,
    WidgetView.week => WidgetKind.week,
    WidgetView.month => WidgetKind.month,
  };

  Future<void> _add() async {
    if (_view != WidgetView.mascot && !context.read<AppState>().isPremium) {
      await PremiumScreen.open(context, note: PremiumContent.lockedWidget);
      return;
    }
    final pinned = await HomeWidgetService.requestPin(_kind);
    if (!mounted || pinned) return;
    // Launchers are allowed to refuse, and some older ones have no such
    // gesture at all — so say how to do it by hand rather than nothing.
    await showAppSnackBar(
      context,
      message: AppContent.widgetManual,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: widget.onboarding
              ? null
              : IconButton(
                  icon: Icon(Icons.arrow_back, color: k.colors.primary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: Text(
            AppContent.widgetsTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            k.geometry.screenPadding,
            0,
            k.geometry.screenPadding,
            24,
          ),
          children: [
            Text(
              AppContent.widgetTitle,
              style: k.text.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            _Stage(kind: _kind),
            const SizedBox(height: 14),
            _ViewPicker(
              selected: _view,
              onSelect: (view) => setState(() => _view = view),
            ),
            // The mascot comes in three sizes; the other views each have the
            // one shape that suits them, and say so in the same place.
            const SizedBox(height: 10),
            _SizePicker(
              sizes: _view == WidgetView.mascot
                  ? const [
                      WidgetKind.strip,
                      WidgetKind.small,
                      WidgetKind.medium,
                    ]
                  : [_kind],
              selected: _kind,
              onSelect: (size) => setState(() => _mascotSize = size),
            ),
            const SizedBox(height: 12),
            Text(
              AppContent.widgetViewLine(_view.name),
              textAlign: TextAlign.center,
              style: k.text.caption.copyWith(color: k.colors.textSecondary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _add,
                style: FilledButton.styleFrom(
                  backgroundColor: k.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(k.geometry.innerRadius),
                  ),
                  textStyle: k.text.bodyStrong,
                ),
                icon: const Icon(Icons.add_to_home_screen_rounded, size: 20),
                label: const Text(AppContent.widgetAdd),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppContent.widgetHint,
              textAlign: TextAlign.center,
              style: k.text.caption.copyWith(
                fontSize: 11.5,
                color: k.colors.textMuted,
              ),
            ),
            if (widget.onboarding) ...[
              const SizedBox(height: 6),
              // A way past it, but a quiet one. Nobody can be made to add a
              // widget — the launcher decides — so the honest thing is to ask
              // once, plainly, and let it be declined.
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    AppContent.widgetSkip,
                    style: k.text.captionStrong.copyWith(
                      color: k.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The widget, on a stand-in for a home screen.
///
/// A fixed height, tall enough for the month, so choosing a shorter view
/// does not pull everything under it up the page.
class _Stage extends StatelessWidget {
  const _Stage({required this.kind});

  final WidgetKind kind;

  static const double height = 304;

  /// A wallpaper for each time of day: mid-tone, so the light panels and the
  /// dark one both stand off it the way they would on a real home screen.
  static const _wallpaper = {
    DayPhase.earlyMorning: [
      Color(0xFFE9A07A),
      Color(0xFFB9867F),
      Color(0xFF6F6F8C),
    ],
    DayPhase.day: [Color(0xFF3F8FB5), Color(0xFF4E9D9A), Color(0xFF2F6F6A)],
    DayPhase.night: [Color(0xFF0A1322), Color(0xFF15294A), Color(0xFF2A4670)],
  };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();

    final Widget preview = switch (kind) {
      WidgetKind.list => ChecklistPreview(state: state),
      WidgetKind.week => WeekPreview(state: state),
      WidgetKind.month => MonthPreview(state: state),
      _ => MascotPreview(state: state, kind: kind),
    };

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _wallpaper[state.activePhase]!,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(kind), child: preview),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home screen cells, wide by tall, as each provider asks for them.
(int, int) _cellsOf(WidgetKind kind) => switch (kind) {
  WidgetKind.strip => (4, 1),
  WidgetKind.small => (2, 2),
  WidgetKind.medium => (4, 2),
  WidgetKind.list => (3, 2),
  WidgetKind.week => (4, 1),
  WidgetKind.month => (3, 2),
};

/// Mascot, Checklist, Week, Month — four tiles, one selected.
class _ViewPicker extends StatelessWidget {
  const _ViewPicker({required this.selected, required this.onSelect});

  final WidgetView selected;
  final ValueChanged<WidgetView> onSelect;

  static const _icons = {
    WidgetView.mascot: Icons.emoji_emotions_outlined,
    WidgetView.list: Icons.checklist_rounded,
    WidgetView.week: Icons.view_week_outlined,
    WidgetView.month: Icons.calendar_month_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      children: [
        for (final view in WidgetView.values) ...[
          if (view != WidgetView.values.first) const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              icon: _icons[view]!,
              label: AppContent.widgetViewName(view.name),
              selected: view == selected,
              onTap: () => onSelect(view),
              k: k,
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.k,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final RewireMindTheme k;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(k.geometry.innerRadius);
    final fg = selected ? Colors.white : k.colors.textPrimary;

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? k.colors.primary : k.colors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? k.colors.primary : k.colors.outline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : k.colors.accent,
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: k.text.captionStrong.copyWith(
                        fontSize: 12,
                        color: fg,
                      ),
                    ),
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

/// Strip, Square, Wide — a segmented control for the mascot's size.
class _SizePicker extends StatelessWidget {
  const _SizePicker({
    required this.sizes,
    required this.selected,
    required this.onSelect,
  });

  final List<WidgetKind> sizes;
  final WidgetKind selected;
  final ValueChanged<WidgetKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      ),
      child: Row(
        children: [
          for (final size in sizes)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: size == selected
                        ? k.colors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      k.geometry.innerRadius - 3,
                    ),
                    boxShadow: size == selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppContent.widgetSizeName(size.name),
                          style: k.text.captionStrong.copyWith(
                            fontSize: 12.5,
                            color: size == selected
                                ? k.colors.primary
                                : k.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_cellsOf(size).$1}×${_cellsOf(size).$2}',
                          style: k.text.caption.copyWith(
                            fontSize: 10.5,
                            color: k.colors.textMuted,
                          ),
                        ),
                      ],
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
