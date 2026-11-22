import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/support/fixmate_support_page.dart';
import 'package:fixmate_mobile/l10n/fixmate_i18n.dart';

void main() {
  testWidgets('Lithuanian UI words are translated within shared widgets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('lt'),
      supportedLocales: [Locale('en'), Locale('lt')],
      home: Scaffold(body: FixMateText('Contacts')),
    ));
    expect(find.text('Kontaktai'), findsOneWidget);
  });

  testWidgets('Contacts, Help and About are available in Lithuanian',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('lt'),
      supportedLocales: [Locale('en'), Locale('lt')],
      home: FixMateSupportPage(initialSection: SupportSection.contacts),
    ));
    expect(find.text('Kontaktai'), findsWidgets);
    expect(find.text('apgyvendinimas@kaunokolegija.lt'), findsOneWidget);
    expect(find.text('Kopijuoti el. paštą'), findsOneWidget);

    await tester.tap(find.text('Pagalba').first);
    await tester.pumpAndSettle();
    expect(find.text('Kaip pranešti apie gedimą?'), findsOneWidget);
    await tester.tap(find.text('Apie programėlę').first);
    await tester.pumpAndSettle();
    expect(find.text('Išmani bendrabučio priežiūra'), findsOneWidget);
  });

  testWidgets('English support remains readable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('lt')],
      home: FixMateSupportPage(initialSection: SupportSection.help),
    ));
    expect(find.text('How do I report a problem?'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
  });
}
