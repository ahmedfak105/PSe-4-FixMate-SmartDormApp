import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/auth/sign_up_page.dart';
import 'package:fixmate_mobile/features/auth/login_page.dart';

void main() {
  testWidgets('Supabase login provides resident registration navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.ensureVisible(find.byKey(const Key('go_to_signup')));
    await tester.tap(find.byKey(const Key('go_to_signup')));
    await tester.pumpAndSettle();

    expect(find.text('Register for FixMate'), findsOneWidget);
    expect(find.byKey(const Key('signup_email')), findsOneWidget);
  });

  testWidgets('Resident sign-up has no privileged role selector', (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    expect(find.text('Register for FixMate'), findsOneWidget);
    expect(find.byKey(const Key('signup_full_name')), findsOneWidget);
    expect(find.byKey(const Key('signup_email')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField), findsNothing);
  });

  testWidgets('Resident sign-up validates missing required fields', (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.ensureVisible(find.byKey(const Key('signup_submit')));
    await tester.tap(find.byKey(const Key('signup_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('Resident sign-up rejects mismatched passwords', (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.enterText(find.byKey(const Key('signup_full_name')), 'Test Resident');
    await tester.enterText(find.byKey(const Key('signup_email')), 'resident@example.com');
    await tester.enterText(find.byKey(const Key('signup_password')), 'securePass123');
    await tester.enterText(find.byKey(const Key('signup_confirm_password')), 'differentPass123');
    await tester.ensureVisible(find.byKey(const Key('signup_submit')));
    await tester.tap(find.byKey(const Key('signup_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
