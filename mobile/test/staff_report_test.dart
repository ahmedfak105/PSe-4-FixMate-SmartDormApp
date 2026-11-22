import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/staff_report.dart';
import 'package:fixmate_mobile/data/models/resident_profile.dart';

StaffReport report({String status = 'new', String? assignedTo}) =>
    StaffReport.fromJson({
      'id': 9,
      'resident_id': 'resident-uuid',
      'category_id': 2,
      'title': 'Broken bathroom light',
      'description': 'The light is not working',
      'location': 'Dorm A - Room 101',
      'status': status,
      'assigned_to': assignedTo,
      'created_at': '2026-11-19T11:37:55+00:00',
    });

void main() {
  test('Staff model displays the most recent backend status timestamp', () {
    final map = {
      'id': 9,
      'resident_id': 'resident-uuid',
      'category_id': 2,
      'title': 'Broken bathroom light',
      'description': 'The light is not working',
      'location': 'Dorm A - Room 101',
      'status': 'in_progress',
      'assigned_to': 'staff-a',
      'created_at': '2026-11-19T11:37:55+00:00',
      'last_status_updated_at': '2026-11-20T12:30:00+00:00',
    };
    final item = StaffReport.fromJson(map);
    expect(item.lastStatusUpdatedAt?.toUtc().toIso8601String(),
        '2026-11-20T12:30:00.000Z');
    expect(report().lastStatusUpdatedAt, isNull);
  });

  test('Staff model maps Supabase report #9 with all required fields', () {
    final item = report();
    expect(item.id, 9);
    expect(item.categoryId, 2);
    expect(item.title, 'Broken bathroom light');
    expect(item.isAvailable, isTrue);
  });

  test('Only eligible reports show claim or resolve actions', () {
    expect(report().canClaim('staff-a'), isTrue);
    expect(report(assignedTo: 'staff-a').canClaim('staff-a'), isTrue);
    expect(report(assignedTo: 'staff-b').canClaim('staff-a'), isFalse);
    expect(report(status: 'in_progress', assignedTo: 'staff-a').canClaim('staff-a'), isFalse);
    expect(report(status: 'in_progress', assignedTo: 'staff-a').canResolve('staff-a'), isTrue);
    expect(report(status: 'in_progress', assignedTo: 'staff-b').canResolve('staff-a'), isFalse);
    expect(report(status: 'resolved', assignedTo: 'staff-a').canResolve('staff-a'), isFalse);
  });

  test('Staff profile is not a resident; staff role remains unchanged', () {
    final profile = ResidentProfile.fromJson({
      'id': 'staff-a',
      'full_name': '',
      'role': 'maintenance_staff',
      'building': null,
      'room_number': null,
    });
    expect(profile.role, 'maintenance_staff');
    expect(profile.isResident, isFalse);
  });
}
