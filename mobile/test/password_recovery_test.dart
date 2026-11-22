import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/auth/password_recovery_page.dart';
import 'package:fixmate_mobile/features/auth/password_recovery_links.dart';

void main() {
  test('Android callback uses the registered app deep link', () {
    // Flutter widget/unit tests run on VM, not the web platform.
    expect(fixMatePasswordRecoveryRedirect(),
        'com.fixmate.smartdorm://reset-password');
  });

  test('web marker needs an exact value', () {
    expect(isFixMateRecoveryLanding(
        Uri.parse('https://example.com/fixmate/?fixmate_recovery=1')), isTrue);
    expect(isFixMateRecoveryLanding(
        Uri.parse('https://example.com/fixmate/?fixmate_recovery=0')), isFalse);
  });

  testWidgets('Recovery form rejects invalid email before sending',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(home: PasswordRecoveryRequestPage(
      sendResetEmail: (email, redirect) async { requests++; },
    )));
    await tester.tap(find.byKey(const Key('recovery_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('Recovery request uses neutral response for any email',
      (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(MaterialApp(home: PasswordRecoveryRequestPage(
      initialEmail: 'unlisted@example.com',
      sendResetEmail: (email, redirect) async {
        requests.add(email);
        expect(redirect, isNotEmpty);
      },
    )));
    await tester.tap(find.byKey(const Key('recovery_submit')));
    await tester.pumpAndSettle();
    expect(requests, ['unlisted@example.com']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('If an account matches'), findsOneWidget);
    expect(find.textContaining('No account'), findsNothing);
  });

  testWidgets('Error text does not identify account existence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: PasswordRecoveryRequestPage(
      initialEmail: 'unknown@example.com',
      sendResetEmail: (email, redirect) async {
        throw Exception('Simulated provider failure');
      },
    )));
    await tester.tap(find.byKey(const Key('recovery_submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be processed right now'),
        findsOneWidget);
    expect(find.textContaining('Simulated provider'), findsNothing);
  });

  testWidgets('Expired recovery link never submits a password', (tester) async {
    var updates = 0;
    await tester.pumpWidget(MaterialApp(home: PasswordResetPage(
      hasRecoverySession: () => false,
      updatePassword: (value) async { updates++; },
      signOut: () async {},
      onCompleted: () {},
    )));
    expect(find.textContaining('invalid or expired'), findsOneWidget);
    expect(find.byKey(const Key('recovery_update_password')), findsNothing);
    expect(updates, 0);
  });

  testWidgets('Recovery password validates, updates, signs out', (tester) async {
    String? changedTo;
    var signOuts = 0;
    var completions = 0;
    await tester.pumpWidget(MaterialApp(home: PasswordResetPage(
      hasRecoverySession: () => true,
      updatePassword: (value) async { changedTo = value; },
      signOut: () async { signOuts++; },
      onCompleted: () { completions++; },
    )));
    await tester.enterText(
        find.byKey(const Key('recovery_new_password')), 'short');
    await tester.enterText(
        find.byKey(const Key('recovery_confirm_password')), 'different');
    await tester.tap(find.byKey(const Key('recovery_update_password')));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(changedTo, isNull);

    await tester.enterText(
        find.byKey(const Key('recovery_new_password')), 'New-Strong-Password-2026!');
    await tester.enterText(
        find.byKey(const Key('recovery_confirm_password')), 'New-Strong-Password-2026!');
    await tester.tap(find.byKey(const Key('recovery_update_password')));
    await tester.pumpAndSettle();
    expect(changedTo, 'New-Strong-Password-2026!');
    expect(signOuts, 1);
    expect(completions, 1);
  });
}
