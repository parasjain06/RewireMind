import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/theme/app_theme.dart';
import 'package:rewiremind/widgets/quote_carousel.dart';

import 'helpers.dart';

/// The carousel is the one place in the app with a repeating timer, so it is
/// worth proving it both advances and shuts down cleanly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every quote the header can show, whatever the hour.
  ///
  /// The pools are chosen by the time of day now, and these tests are about
  /// the carousel's timer rather than about which pool it landed on — so they
  /// recognise a quote by "is this one of ours" rather than by naming one.
  final everyQuote = {
    ...AppContent.homeQuotesMorning,
    ...AppContent.homeQuotesDay,
    ...AppContent.homeQuotesNight,
  };

  Widget host(Widget child) => MaterialApp(
    theme: RewireMindTheme.forest.toThemeData(),
    home: Scaffold(body: SizedBox(width: 220, child: child)),
  );

  testWidgets('advances to the next quote on its own', (tester) async {
    quoteAutoAdvance = true;
    addTearDown(disableQuoteAutoAdvance);

    await tester.pumpWidget(
      host(const QuoteCarousel(interval: Duration(seconds: 2))),
    );
    await tester.pump();

    final first = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .firstWhere((d) => everyQuote.contains(d));

    // Let the timer fire, then let the page settle.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));

    final showing = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => everyQuote.contains(d))
        .toList();

    expect(showing, isNotEmpty);
    expect(
      showing.contains(first) && showing.length == 1,
      isFalse,
      reason: 'the carousel should have moved on',
    );
  });

  testWidgets('cancels its timer when disposed', (tester) async {
    quoteAutoAdvance = true;
    addTearDown(disableQuoteAutoAdvance);

    await tester.pumpWidget(
      host(const QuoteCarousel(interval: Duration(seconds: 1))),
    );
    await tester.pump();

    // Replacing the tree disposes the carousel. A leaked timer makes the test
    // framework fail with "a Timer is still pending".
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(QuoteCarousel), findsNothing);
  });

  testWidgets('stays put when auto-advance is off', (tester) async {
    disableQuoteAutoAdvance();

    await tester.pumpWidget(
      host(const QuoteCarousel(interval: Duration(milliseconds: 200))),
    );
    await tester.pumpAndSettle();

    final before = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .firstWhere((d) => everyQuote.contains(d));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .firstWhere((d) => everyQuote.contains(d));

    expect(after, before);
  });

  testWidgets('each time of day gets its own quotes', (tester) async {
    // The point of splitting the pool. "Start before you feel ready" is a
    // morning sentence and reads as a reproach at eleven at night.
    disableQuoteAutoAdvance();

    for (final (phase, pool) in [
      (DayPhase.earlyMorning, AppContent.homeQuotesMorning),
      (DayPhase.day, AppContent.homeQuotesDay),
      (DayPhase.night, AppContent.homeQuotesNight),
    ]) {
      // Keyed, exactly as Home keys it: the pool is read once per State, so
      // without a key the second pump reuses the first phase's carousel.
      await tester.pumpWidget(
        host(QuoteCarousel(key: ValueKey(phase), phase: phase)),
      );
      await tester.pumpAndSettle();

      final showing = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where(everyQuote.contains);

      expect(showing, isNotEmpty, reason: 'no quote on screen for $phase');
      for (final quote in showing) {
        expect(pool, contains(quote), reason: '$quote is not a $phase quote');
      }
    }
  });

  test('no quote is longer than the header can hold', () {
    // The header gives this a column a little over half the width and about
    // two lines of it. Anything longer wraps to three and pushes into the
    // artwork, which is how the pool ended up full of paragraphs before.
    for (final pool in [
      AppContent.homeQuotesMorning,
      AppContent.homeQuotesDay,
      AppContent.homeQuotesNight,
    ]) {
      expect(pool, hasLength(greaterThanOrEqualTo(4)));
      for (final quote in pool) {
        expect(quote.length, lessThanOrEqualTo(34), reason: quote);
      }
    }
  });

  test('the profile library offers every quote the app knows', () {
    final library = AppContent.profileQuoteLibrary;
    expect(library.toSet(), hasLength(library.length), reason: 'duplicates');
    for (final pool in [
      AppContent.homeQuotesMorning,
      AppContent.homeQuotesDay,
      AppContent.homeQuotesNight,
    ]) {
      expect(library, containsAll(pool));
    }
    // The default a fresh profile ships with has to be in the list, or the
    // picker opens with nothing ticked on a profile nobody has edited.
    expect(library, contains('Progress, not perfection.'));
  });

  testWidgets('Home shows the carousel and no header icons', (tester) async {
    await pumpSeededApp(tester);

    expect(find.byType(QuoteCarousel), findsOneWidget);
    // The bell and avatar moved off the header entirely.
    expect(find.byIcon(Icons.notifications_none), findsNothing);
  });
}
