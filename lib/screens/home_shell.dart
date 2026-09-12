import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../notifications/home_widget_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/coach_marks.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/plus_hint.dart';
import 'account_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'onboarding_screen.dart';
import 'share_board_screen.dart';
import 'calendar_screen.dart';
import 'habit_editor_sheet.dart';
import 'habit_library_screen.dart';
import 'roadmap_screen.dart';
import 'habit_detail_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'widgets_screen.dart';
import 'progress_screen.dart';
import '../content/premium_content.dart';
import '../models/premium.dart';
import 'premium_screen.dart';

/// Opens the walkthrough on a first launch.
///
/// Off under `flutter test`: a route that pushes itself over the app on the
/// first frame would land on top of every widget test in the suite.
bool showTutorialOnFirstRun = true;

/// Root scaffold holding the four tabs.
/// Asks the shell to run the Home tour again — bumped by Help's "Show me
/// around". A notifier rather than a callback threaded through every screen
/// in between, because Help is three pushes away from the shell that owns
/// the keys.
final ValueNotifier<int> homeTourRequests = ValueNotifier<int>(0);

/// Asks the shell to show Home — the habit list. Used by screens several
/// pushes away, like Notifications' "Go to habits".
final ValueNotifier<int> homeTabRequests = ValueNotifier<int>(0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  /// Honours `?tab=N` so a specific tab can be opened directly. Handy when
  /// running on web during development; ignored elsewhere.
  int _index = switch (int.tryParse(Uri.base.queryParameters['tab'] ?? '')) {
    final i? when i >= 0 && i < 4 => i,
    _ => 0,
  };

  static const _destinations = [
    NavDestination(AppContent.navHome, Icons.home_outlined),
    NavDestination(AppContent.navCalendar, Icons.calendar_month_outlined),
    NavDestination(AppContent.navProgress, Icons.bar_chart),
    NavDestination(
      AppContent.navProfile,
      Icons.person_outline,
      showBadge: true,
    ),
  ];

  /// What the Home tour points at.
  final HomeTourKeys _tour = HomeTourKeys();

  /// Taps on the home screen widget, which always land on Home.
  StreamSubscription<Uri?>? _fromWidget;

  @override
  void initState() {
    super.initState();
    _listenForNotificationOpens();

    // A widget tap resumes the existing task, so without this it drops you on
    // whatever tab you last left open — which is not what somebody pressing a
    // card showing today's progress is asking for.
    //
    // Gated on the same flag the widget service uses. There is no such channel
    // under `flutter test` or on the web, and an unguarded listen throws a
    // MissingPluginException on the first frame of every widget test.
    if (HomeWidgetService.available) {
      _fromWidget = HomeWidget.widgetClicked.listen((uri) {
        if (mounted) _goToTab(_tabFor(uri));
      });
      unawaited(
        HomeWidget.initiallyLaunchedFromHomeWidget()
            .then((uri) {
              if (uri != null && mounted) _goToTab(_tabFor(uri));
            })
            .catchError((_) {}),
      );
    }
    // On the very first launch, say what the app is for before handing over an
    // empty list of habits. An empty screen with a plus sign on it explains
    // nothing, and the walkthrough exists either way — it just was not being
    // shown at the one moment somebody actually needs it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _introduce();
      _openDirect();
    });
    WidgetsBinding.instance.addObserver(this);
    homeTourRequests.addListener(_onTourRequest);
    homeTabRequests.addListener(_onHomeRequest);
    HomeWidgetService.listenForPins();
    HomeWidgetService.pinned.addListener(_onWidgetPinned);
  }

  /// A widget has just landed on the home screen: back to Home, and say so.
  /// Closing whatever is on top also finishes the first-launch widget step.
  void _onWidgetPinned() {
    final kind = HomeWidgetService.pinned.value;
    if (kind == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _goToTab(0);
    showAppSnackBar(
      context,
      message: AppContent.widgetAdded(kind.name),
      duration: const Duration(seconds: 4),
    );
  }

  /// Companion to `?tab=`: opens one of the pushed screens straight away, so a
  /// page that normally takes two taps to reach can be looked at in the web
  /// preview. Ignored everywhere else — `Uri.base` has no query on a device.
  void _openDirect() {
    if (!mounted) return;
    switch (Uri.base.queryParameters['open']) {
      case 'path':
        RoadmapScreen.open(context);
      case 'library':
        HabitLibraryScreen.open(context);
      case 'editor':
        HabitEditorSheet.show(context);
      case 'notifications':
        NotificationsScreen.open(context);
      case 'account':
        AccountScreen.open(context);
      case 'help':
        HelpScreen.open(context);
      case 'about':
        AboutScreen.open(context);
      case 'onboarding':
        OnboardingScreen.open(context);
      case 'share':
        ShareBoardScreen.open(context);
      case 'widgets':
        WidgetsScreen.open(context);
      case 'detail':
        final state = context.read<AppState>();
        if (state.habits.isNotEmpty) {
          HabitDetailScreen.open(
            context,
            habitId: state.habits.first.id,
            day: state.today,
          );
        }
    }
  }

  /// The once-a-day walk up the path.
  ///
  /// Keeping a day earns the next stop, and this is where somebody is shown
  /// arriving at it: the first time the app is opened on a new day, the path
  /// opens itself and the trail climbs. Never on the first day — starting the
  /// challenge records day one as already reached — and never twice, because
  /// the walk marks itself seen the moment it is shown rather than when it is
  /// watched to the end. Somebody who backs straight out has still been shown
  /// it, and an animation that reappears until you sit through it is one
  /// people learn to dread.
  ///
  /// Runs after the first-launch tour, not instead of it: on the day the
  /// challenge is started there is nothing to walk anyway.
  Future<void> _walkThePath() async {
    if (!mounted || !showTutorialOnFirstRun) return;
    final state = context.read<AppState>();
    final from = state.challengeAdvanceFrom;
    if (from == null) return;

    await state.markChallengeStopSeen();
    if (!mounted) return;
    await RoadmapScreen.open(context, walkFrom: from);
  }

  Future<void> _introduce() async {
    if (!mounted || !showTutorialOnFirstRun) return;
    final state = context.read<AppState>();
    if (!state.needsTutorial) {
      await _walkThePath();
      return;
    }

    // Marked before it opens, not after. Somebody who backs out of the tour
    // has still been offered it, and a tour that reappears until it is watched
    // to the end is a tour people uninstall the app to escape.
    await state.markTutorialSeen();
    if (!mounted) return;
    await OnboardingScreen.open(context, offerTour: false);

    // Then straight into a look round Home itself — pointed out on the real
    // screen rather than described on a separate one, with Skip on every
    // step. It follows on by itself: the slides are about the idea, this is
    // about where things are, and nobody should have to go looking for it.
    // A moment first, for the slides to fade off the screen being toured.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted) await _runHomeTour();

    // And last, the widget. This is the one moment it is worth asking: the
    // widget is what makes somebody see the app on a day they would not have
    // opened it, and asked about later — from a settings screen nobody
    // visits — it never gets added at all.
    if (mounted && HomeWidgetService.supported) {
      await WidgetsScreen.open(context, onboarding: true);
    }
  }

  /// Comes back to the path when a phone that was left open crosses midnight.
  ///
  /// Without this, somebody who never actually closes the app would only ever
  /// see the walk after a cold start — which on a phone with plenty of memory
  /// can be weeks.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle == AppLifecycleState.resumed) unawaited(_walkThePath());
  }

  void _onHomeRequest() {
    if (mounted) _goToTab(0);
  }

  void _onTourRequest() {
    if (!mounted) return;
    _goToTab(0);
    // After the switch to Home has been drawn, or the keys point at nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runHomeTour());
  }

  /// Points out the parts of Home, one at a time. Anything not on screen —
  /// a habit list that is still empty, say — is passed over.
  Future<void> _runHomeTour() {
    return CoachMarks.show(context, [
      CoachStep(
        target: _tour.hero,
        title: AppContent.coachHeroTitle,
        body: AppContent.coachHeroBody,
      ),
      CoachStep(
        target: _tour.stats,
        title: AppContent.coachStatsTitle,
        body: AppContent.coachStatsBody,
      ),
      CoachStep(
        target: _tour.week,
        title: AppContent.coachWeekTitle,
        body: AppContent.coachWeekBody,
      ),
      CoachStep(
        target: _tour.habits,
        title: AppContent.coachHabitsTitle,
        body: AppContent.coachHabitsBody,
      ),
      CoachStep(
        target: _tour.journal,
        title: AppContent.coachJournalTitle,
        body: AppContent.coachJournalBody,
      ),
      CoachStep(
        target: _tour.add,
        title: AppContent.coachAddTitle,
        body: AppContent.coachAddBody,
      ),
      CoachStep(
        target: _tour.tabs,
        title: AppContent.coachTabsTitle,
        body: AppContent.coachTabsBody,
      ),
    ]);
  }

  @override
  void dispose() {
    AppState.openHabitRequests.removeListener(_openRequestedHabit);
    WidgetsBinding.instance.removeObserver(this);
    HomeWidgetService.pinned.removeListener(_onWidgetPinned);
    homeTourRequests.removeListener(_onTourRequest);
    homeTabRequests.removeListener(_onHomeRequest);
    _fromWidget?.cancel();
    super.dispose();
  }

  void _goToTab(int index) => setState(() => _index = index);

  /// Which tab a widget tap opens: the week and month widgets open the
  /// Calendar they are a piece of, everything else opens Home.
  static int _tabFor(Uri? uri) => uri?.host == 'calendar' ? 1 : 0;

  /// Opens the habit library, asking first when Home is showing an earlier day.
  ///
  /// A habit only counts from the day it starts. Added while looking back at
  /// last Tuesday it used to start today regardless, so it simply was not
  /// there on the day you were looking at — the list did not change, and the
  /// obvious conclusion was that adding it had failed.
  ///
  /// Now the day is the question, and the answer is carried all the way into
  /// `addHabit`: start it back there and every day since counts, missed ones
  /// included, because that is what a start date means everywhere else in the
  /// app and inventing an exception here would make the numbers lie.
  /// Goes to Home, showing [day].
  ///
  /// Every way into a day — a date on the month grid, a date over the board,
  /// a date over the overview — lands here. Adding a habit for a day gone by
  /// is Home's job: it is the screen with the + on it, and it already knows
  /// to ask whether a new habit starts on the day being looked at.
  void _showDayOnHome(DateTime day) {
    context.read<AppState>().viewDay(day);
    _goToTab(0);
  }

  /// Opens the habit a notification was about, on today.
  void _listenForNotificationOpens() {
    AppState.openHabitRequests.addListener(_openRequestedHabit);
    // A tap that started the app asked for its habit before this screen
    // existed, so the request is already sitting there when we arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestedHabit());
  }

  void _openRequestedHabit() {
    final id = AppState.openHabitRequests.value;
    if (id == null || !mounted) return;
    AppState.openHabitRequests.value = null;
    final state = context.read<AppState>();
    _goToTab(0);
    HabitDetailScreen.open(context, habitId: id, day: state.today);
  }

  Future<void> _addHabit(BuildContext context) async {
    final state = context.read<AppState>();

    // Five habits is the free tier. The sixth is where somebody has decided
    // the app is theirs, which is the moment to ask.
    if (!state.canAddHabit) {
      await PremiumScreen.open(
        context,
        note: PremiumContent.lockedHabits(kFreeHabitLimit),
      );
      return;
    }

    var startOn = state.today;

    if (_index == 0 && state.viewedDay.isBefore(state.today)) {
      final then = await _confirmBackdate(context, state.viewedDay);
      if (then == null || !context.mounted) return;
      if (then) startOn = state.viewedDay;
    }

    if (context.mounted) {
      await HabitLibraryScreen.open(
        context,
        startOn: startOn == state.today ? null : startOn,
      );
    }
  }

  /// True to start on [day], false to start today, null to do neither.
  Future<bool?> _confirmBackdate(BuildContext context, DateTime day) {
    final k = context.k;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(
          AppContent.backdateTitle(DateFormat('EEE d MMM').format(day)),
          style: k.text.cardTitle,
        ),
        content: Text(
          AppContent.backdateBody(DateFormat('EEE d MMM').format(day)),
          style: k.text.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppContent.backdateStartToday,
              style: k.text.captionStrong.copyWith(
                fontSize: 13,
                color: k.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppContent.backdateStartThen(DateFormat('d MMM').format(day)),
              style: k.text.captionStrong.copyWith(
                fontSize: 13,
                color: k.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                HomeScreen(onOpenCalendar: () => _goToTab(1), tourKeys: _tour),
                // A date anywhere on the Calendar opens that day on Home:
                // one place where habits are ticked and added, rather than
                // three that each do a little of it.
                CalendarScreen(onOpenDay: _showDayOnHome),
                const ProgressScreen(),
                const ProfileScreen(),
              ],
            ),
            // With nothing tracked yet, Home points at the one button that
            // starts everything.
            if (_index == 0 &&
                context.select<AppState, bool>((s) => s.everyHabit.isEmpty))
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(child: PlusHint()),
              ),
          ],
        ),
        bottomNavigationBar: RewireMindBottomNav(
          destinations: _destinations,
          currentIndex: _index,
          onSelect: _goToTab,
          onAdd: () => _addHabit(context),
          addKey: _tour.add,
          tabsKey: _tour.tabs,
        ),
      ),
    );
  }
}
