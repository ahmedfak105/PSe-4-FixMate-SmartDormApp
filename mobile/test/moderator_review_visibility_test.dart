import 'package:flutter_test/flutter_test.dart';
import 'package:vp_mobile/features/operations/moderator_operations_page.dart';

void main() {
  final reports = <Map<String, dynamic>>[
    {'id': 1, 'status': 'new', 'assigned_to': null},
    {'id': 2, 'status': 'new', 'assigned_to': null},
    {'id': 3, 'status': 'in_progress', 'assigned_to': 'staff-id'},
    {'id': 4, 'status': 'resolved', 'assigned_to': 'staff-id'},
    {'id': 5, 'status': 'new', 'assigned_to': 'staff-id'},
  ];
  final decisions = <int, Map<String, dynamic>>{
    2: {'outcome': 'valid'},
    3: {'outcome': 'valid'},
    4: {'outcome': 'valid'},
  };

  test('pending tab excludes reviewed, assigned and progressed reports', () {
    final rows = visibleModeratorReports(
      reports: reports, decisions: decisions, reviewedOnly: false);
    expect(rows.map((row) => row['id']), [1]);
  });

  test('reviewed tab retains decisions after claim and resolution', () {
    final rows = visibleModeratorReports(
      reports: reports, decisions: decisions, reviewedOnly: true);
    expect(rows.map((row) => row['id']), [2, 3, 4]);
  });

  test('reviewed tab never shows a report without an audit decision', () {
    final rows = visibleModeratorReports(
      reports: reports, decisions: const {}, reviewedOnly: true);
    expect(rows, isEmpty);
  });
}
