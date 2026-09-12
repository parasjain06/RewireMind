import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/app.dart';
import 'package:rewiremind/data/seed_data.dart';
import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/notifications/home_widget_service.dart';
import 'package:rewiremind/notifications/path_sound.dart';
import 'package:rewiremind/notifications/notification_service.dart';
import 'package:rewiremind/screens/home_screen.dart';
import 'package:rewiremind/screens/home_shell.dart';
import 'package:rewiremind/models/user_profile.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/widgets/share_board.dart';
import 'package:rewiremind/widgets/quote_carousel.dart';
import 'package:rewiremind/models/premium.dart';

/// Test fixtures.
///
/// Tests seed storage themselves rather than relying on `seedDemoData`, so
/// flipping that production flag can never quietly change what they assert.

/// The quote carousel's repeating timer schedules frames forever, which
/// would stop `pumpAndSettle` from ever settling. Widget tests turn it off.
void disableQuoteAutoAdvance() => quoteAutoAdvance = false;

/// The Home header's character paces back and forth for ever, so
/// `pumpAndSettle` would never settle while it is running.
void disableHeroWalk() => heroWalks = false;

/// The walkthrough opens itself over the app on a first launch, which under
/// test means over whatever the test was about to look at.
void disableFirstRunTutorial() => showTutorialOnFirstRun = false;

/// AppState re-checks the clock on a repeating timer so the page can roll into
/// the next time of day. Same problem: `pumpAndSettle` would never settle.
void disableLivePhaseTicker() => livePhaseTick = null;

/// The notification plugin has no platform binding under `flutter test`, so
/// every call into it throws. Scheduling is verified by
/// `notification_planner_test.dart`, which needs no plugin at all.
void disableNotificationPlugin() {
  notificationsAvailable = false;
  // No share sheet and no temp directory worth writing to under test; the
  // picture is still rendered, it just is not handed anywhere.
  boardSharingAvailable = false;
  // Same story for the home screen widget: no platform channel under test.
  HomeWidgetService.available = false;
  // And the one sound the app makes, which the path plays on arrival.
  PathSound.available = false;
}

/// Lets a transient message finish and its dismiss timer fire.
///
/// `showAppSnackBar` schedules its own timer, because SnackBar.duration is not
/// honoured on this Flutter version. A test that ends while a message is still
/// on screen trips the framework's "timer still pending" assertion, so any
/// test that triggers one has to let it pass.
Future<void> letToastPass(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// An AppState pre-populated with the demo habits and their history.
/// The name the fixtures sign in with.
///
/// The app is gated on having one: a profile with no name lands on the
/// sign-in screen, which is right for a real first launch and wrong for every
/// test that is about something else. Tests that are about signing in start
/// from a nameless profile deliberately.
const String kTestName = 'Ada';

Future<AppState> seededState() async {
  disableLivePhaseTicker();
  disableNotificationPlugin();
  SharedPreferences.setMockInitialValues({});
  final storage = await RewireMindStorage.open();
  final now = DateTime.now();
  final habits = seedHabits(now);
  await storage.saveHabits(habits);
  await storage.saveLogs(seedLogs(habits, now));
  await storage.saveProfile(const UserProfile(name: kTestName));
  await storage.markSeeded();

  final state = AppState(storage);
  await state.load();
  // Paid for: the fixtures are a full app — six habits, a journal, the
  // challenge — and a test about the board or the evening nudge should not
  // have to buy its way past the paywall first. The free tier has its own
  // tests, which start from [emptyState].
  await state.unlockPremium(PremiumPlan.lifetime, source: 'test');
  return state;
}

/// Makes [day] a perfect day, whatever the seeded history happened to roll.
///
/// The seed's odds depend on the weekday, so whether yesterday came out
/// perfect changes with the calendar — and a test that quietly relies on it
/// passes on a Thursday and fails on a Friday. Tests that need a run behind
/// them should say so with this rather than hope.
Future<void> keepDay(AppState state, DateTime day) async {
  for (final habit in state.scheduledOn(day)) {
    await state.setValue(habit, day, habit.target);
    // A cut-back habit is kept by staying under, not by reaching.
    if (!state.isComplete(habit, day)) await state.setValue(habit, day, 0);
  }
}

/// An AppState with no habits at all — what a fresh install looks like when
/// `seedDemoData` is off.
Future<AppState> emptyState() async {
  disableLivePhaseTicker();
  disableNotificationPlugin();
  SharedPreferences.setMockInitialValues({});
  final storage = await RewireMindStorage.open();
  // Mark seeded so load() does not repopulate, whatever the flag says.
  await storage.saveProfile(const UserProfile(name: kTestName));
  await storage.markSeeded();

  final state = AppState(storage);
  await state.load();
  return state;
}

/// Reopens the same underlying store, to prove something persisted.
Future<AppState> reopen() async {
  disableLivePhaseTicker();
  disableNotificationPlugin();
  final state = AppState(await RewireMindStorage.open());
  await state.load();
  return state;
}

/// Pumps the real app at phone size around [state].
Future<void> pumpAppWith(WidgetTester tester, AppState state) async {
  disableQuoteAutoAdvance();
  disableHeroWalk();
  disableFirstRunTutorial();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const RewireMindApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Seeded state plus a pumped app — the common case.
Future<AppState> pumpSeededApp(WidgetTester tester) async {
  final state = await seededState();
  await pumpAppWith(tester, state);
  return state;
}

/// Opens the habit library from the raised plus.
///
/// `.first` because habit rows carry their own plus: on Home with a list
/// already on screen, a bare `byIcon(Icons.add)` is ambiguous.
Future<void> openHabitLibrary(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add).first);
  await tester.pumpAndSettle();
}
