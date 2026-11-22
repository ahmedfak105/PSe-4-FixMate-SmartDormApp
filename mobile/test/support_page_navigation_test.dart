import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fixmate_mobile/features/support/fixmate_support_page.dart';

void main() {
  testWidgets('Lithuanian support tabs open Help and About without changing routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('lt'),
      supportedLocales: [Locale('en'), Locale('lt')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FixMateSupportPage(initialSection: SupportSection.contacts),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bendrabučių kontaktai'), findsOneWidget);

    final helpTab = find.byKey(const Key('support_tab_help'));
    await tester.ensureVisible(helpTab);
    await tester.tap(helpTab);
    await tester.pumpAndSettle();
    expect(find.text('Kaip pranešti apie gedimą?'), findsOneWidget);

    final aboutTab = find.byKey(const Key('support_tab_about'));
    await tester.ensureVisible(aboutTab);
    await tester.tap(aboutTab);
    await tester.pumpAndSettle();
    expect(find.text('Išmani bendrabučio priežiūra'), findsOneWidget);
  });
}
