import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/notifications/home_widget_service.dart';
import 'package:rewiremind/screens/widgets_screen.dart';

import 'helpers.dart';

/// Adding a widget keeps the app open: back to Home, with a word about it.
void main() {
  testWidgets('a placed widget brings you Home and says so', (tester) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    WidgetsScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetsScreen), findsOneWidget);

    // What Android's "added" callback turns into.
    HomeWidgetService.pinned.value = WidgetKind.list;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(WidgetsScreen), findsNothing);
    expect(find.text(AppContent.widgetAdded('list')), findsOneWidget);
    expect(find.text('Habits'), findsWidgets, reason: 'on the Home tab');

    await letToastPass(tester);
    HomeWidgetService.pinned.value = null;
  });
}
