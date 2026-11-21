import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/app.dart';

void main() {
  Future<void> start(WidgetTester tester) async {
    // Emulate a phone screen: the app uses NavigationRail at widths >= 600.
    // Flutter widget tests use an 800 px logical viewport by default.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FixMateApp());
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(Key('tab_$name')));
    await tester.pumpAndSettle();
  }

  testWidgets('Four resident tabs and home are visible', (tester) async {
    await start(tester);
    expect(find.text('Welcome to FixMate'), findsOneWidget);
    for (final name in ['Home', 'My Reports', 'New Report', 'Profile']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(name)), findsOneWidget);
    }
  });

  testWidgets('Report list and report details use nested navigation', (tester) async {
    await start(tester);
    await tab(tester, 'myReports');
    expect(find.text('Leaking bathroom tap'), findsOneWidget);
    expect(find.textContaining('Submitted on:'), findsNWidgets(2));
    await tester.tap(find.text('Leaking bathroom tap'));
    await tester.pumpAndSettle();
    expect(find.text('The tap leaks even when turned off.'), findsOneWidget);
    expect(find.text('Submitted on'), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tab(tester, 'myReports');
    expect(find.text('Broken corridor light'), findsOneWidget);
  });

  testWidgets('New report validates and appears in My Reports', (tester) async {
    await start(tester);
    await tab(tester, 'newReport');
    await tester.ensureVisible(find.byKey(const Key('submit_report')));
    await tester.tap(find.byKey(const Key('submit_report')));
    await tester.pumpAndSettle();
    expect(find.text('Required field'), findsNWidgets(3));
    await tester.enterText(find.byKey(const Key('report_title')), 'Window is stuck');
    await tester.enterText(find.byKey(const Key('report_location')), 'Room 301');
    await tester.enterText(find.byKey(const Key('report_description')), 'The window cannot be closed.');
    await tester.ensureVisible(find.byKey(const Key('submit_report')));
    await tester.tap(find.byKey(const Key('submit_report')));
    await tester.pumpAndSettle();
    expect(find.text('Window is stuck'), findsOneWidget);
  });
}
