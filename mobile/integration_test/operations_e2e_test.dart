import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixmate_mobile/app.dart';

/// End-to-end integration in a *real Chrome browser* using Supabase CLI.
/// This test refuses all remote or non-local databases. Synthetic accounts
/// and role grants are provided by the local Supabase API smoke setup.
/// Never run these tests against the populated university/demo project.
const _url = String.fromEnvironment('SUPABASE_TEST_URL');
const _key = String.fromEnvironment('SUPABASE_TEST_ANON_KEY');
const _password = 'LocalSmoke-Only-Password-2026!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_url != 'http://127.0.0.1:54321' &&
        _url != 'http://localhost:54321') {
      throw StateError('Refusing a remote Supabase integration-test URL: $_url');
    }
    if (_key.isEmpty || _key.startsWith('sb_secret_')) {
      throw StateError('Only the disposable local Supabase anon key is permitted');
    }
    await Supabase.initialize(url: _url, publishableKey: _key);
  });

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    String? reason,
  }) async {
    for (var i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure(reason ?? 'Timed out waiting for a Flutter UI element');
  }

  Future<void> loginAs(WidgetTester tester, String email) async {
    // Dispose old AuthGate before changing the global Auth session.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) await auth.signOut();
      await auth.signInWithPassword(email: email, password: _password);
    });
    await tester.pumpWidget(const FixMateApp(
      requireLogin: true,
      operationsOnly: true,
    ));
  }

  Future<int> createTestReport(String title) async {
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await client.auth.signInWithPassword(
      email: 'resident.a.fixmate@example.com',
      password: _password,
    );
    final categories = await client.from('maintenance_categories')
        .select('id').eq('name', 'Plumbing').limit(1);
    if (categories.isEmpty) throw StateError('Plumbing seed is missing');
    final created = await client.from('maintenance_reports').insert({
      'resident_id': client.auth.currentUser!.id,
      'category_id': categories.first['id'],
      'title': title,
      'description': 'Flutter Chrome integration smoke (local only)',
      'location': 'Room 105',
      'status': 'new',
    }).select('id').single();
    await client.auth.signOut();
    return (created['id'] as num).toInt();
  }

  testWidgets('Resident cannot enter the privileged Flutter Web workspace',
      (tester) async {
    await loginAs(tester, 'resident.b.fixmate@example.com');
    await waitFor(tester,
        find.text('Account role not permitted in this workspace'));
    expect(find.textContaining('Maintenance Staff, Moderators and System Admins'),
        findsOneWidget);
  });

  testWidgets('Admin loads the real Supabase operations dashboard',
      (tester) async {
    await loginAs(tester, 'admin.fixmate@example.com');
    await waitFor(tester, find.text('FixMate · Flutter Web Admin'));
    await waitFor(tester, find.textContaining('Welcome,'));
    expect(find.text('All reports'), findsWidgets);
    expect(find.text('Assignments'), findsWidgets);
    expect(find.text('People'), findsWidgets);
  });

  testWidgets('Maintenance Staff claims and resolves a report in Flutter UI',
      (tester) async {
    const title = 'FLUTTER_WEB_E2E_STAFF';
    final id = (await tester.runAsync(() => createTestReport(title)))!;
    await loginAs(tester, 'staff.fixmate@example.com');

    final heading = find.text('#$id  $title');
    await waitFor(tester, heading, reason: 'Staff did not load the report');
    final reportCard = find.ancestor(of: heading, matching: find.byType(Card));
    final claimButton = find.descendant(
        of: reportCard, matching: find.text('Claim report'));
    await tester.ensureVisible(claimButton);
    await tester.tap(claimButton);
    await waitFor(tester, find.textContaining('claimed successfully'));

    final resolveButton = find.descendant(
        of: reportCard, matching: find.text('Mark resolved'));
    await waitFor(tester, resolveButton);
    await tester.ensureVisible(resolveButton);
    await tester.tap(resolveButton);
    await waitFor(tester, find.textContaining('marked resolved'));

    final state = await tester.runAsync(() async {
      return Supabase.instance.client.from('maintenance_reports')
          .select('status').eq('id', id).single();
    });
    expect(state?['status'], 'resolved');
  });

  testWidgets('Moderator reviews and persists a valid report in Flutter UI',
      (tester) async {
    const title = 'FLUTTER_WEB_E2E_MODERATOR';
    final id = (await tester.runAsync(() => createTestReport(title)))!;
    await loginAs(tester, 'moderator.fixmate@example.com');

    final heading = find.text('#$id  $title');
    await waitFor(tester, heading, reason: 'Moderator report not visible');
    final reportCard = find.ancestor(of: heading, matching: find.byType(Card));
    final reviewButton = find.descendant(
        of: reportCard, matching: find.text('Review report'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);

    await waitFor(tester, find.text('Review report #$id'));
    await tester.tap(find.text('Save decision'));
    await waitFor(tester, find.textContaining('Review saved for report #$id'));

    final review = await tester.runAsync(() async {
      return Supabase.instance.client.from('report_reviews')
          .select('outcome').eq('report_id', id).single();
    });
    expect(review?['outcome'], 'valid');
  });
}
