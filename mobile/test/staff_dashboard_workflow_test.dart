import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/resident_profile.dart';
import 'package:fixmate_mobile/data/models/staff_report.dart';
import 'package:fixmate_mobile/data/repositories/staff_reports_repository.dart';
import 'package:fixmate_mobile/features/staff/staff_dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// No real DB or network mutations: the fake repo exercises the Flutter
/// Staff UI response to RPC success/conflict and queue refreshes.
class FakeStaffQueue implements StaffReportsRepository {
  FakeStaffQueue({required this.conflict});
  final bool conflict;
  int listCalls = 0;
  int claimCalls = 0;
  int resolveCalls = 0;
  String state = 'new';
  bool removed = false;

  @override
  Future<List<StaffReport>> listVisibleReports() async {
    listCalls++;
    if (removed) return [];
    return [
      StaffReport(
        id: 77,
        residentId: 'resident-uuid',
        categoryId: 2,
        title: 'Staff UI conflict report',
        description: 'Door needs repair',
        location: 'Room 105',
        status: state,
        assignedTo: state == 'new' ? null : 'staff-a',
        createdAt: DateTime.utc(2026, 11, 20, 14),
        lastStatusUpdatedAt: state == 'new'
            ? null : DateTime.utc(2026, 11, 21, 16, 45),
      ),
    ];
  }

  @override
  Future<bool> claimReport(int reportId) async {
    claimCalls++;
    if (conflict) {
      removed = true; // Another employee won before this RPC finished.
      return false;
    }
    state = 'in_progress';
    return true;
  }

  @override
  Future<bool> resolveReport(int reportId) async {
    resolveCalls++;
    state = 'resolved';
    return true;
  }
}

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://ci-only-placeholder.supabase.co',
      publishableKey: 'sb_publishable_ci_only_nonfunctional',
    );
  });

  const profile = ResidentProfile(
    id: 'staff-a',
    role: 'maintenance_staff',
    fullName: 'Sample Maintenance Employee',
  );

  Future<void> openStaff(WidgetTester tester, FakeStaffQueue repo) async {
    tester.view.physicalSize = const Size(820, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StaffDashboardPage(
      profile: profile,
      repository: repo,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Concurrent claim denial displays clear feedback and refreshes queue',
      (tester) async {
    final repo = FakeStaffQueue(conflict: true);
    await openStaff(tester, repo);
    expect(find.text('Claim report'), findsOneWidget);
    await tester.tap(find.text('Claim report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('was not changed'), findsOneWidget);
    expect(find.text('No available reports right now.'), findsOneWidget);
    expect(repo.claimCalls, 1);
    expect(repo.listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('Claim -> In Progress -> Resolve shows status and timestamp',
      (tester) async {
    final repo = FakeStaffQueue(conflict: false);
    await openStaff(tester, repo);
    expect(find.textContaining('Last status update:'), findsOneWidget);
    await tester.tap(find.text('Claim report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('claimed successfully'), findsOneWidget);
    expect(find.text('Mark resolved'), findsOneWidget);
    expect(find.textContaining('2026-11-21 16:45'), findsOneWidget);
    await tester.tap(find.text('Mark resolved'));
    await tester.pumpAndSettle();

    expect(find.textContaining('marked resolved'), findsOneWidget);
    expect(find.text('resolved'), findsOneWidget);
    expect(repo.claimCalls, 1);
    expect(repo.resolveCalls, 1);
    expect(repo.listCalls, greaterThanOrEqualTo(3));
  });
}
