import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/resident_profile.dart';

void main() {
  test('Reads resident profile columns from database JSON', () {
    final profile = ResidentProfile.fromJson({
      'id': 'test-user-uuid',
      'full_name': 'Demo Resident',
      'role': 'resident',
      'building': 'A',
      'room_number': '204',
    });
    expect(profile.fullName, 'Demo Resident');
    expect(profile.role, 'resident');
    expect(profile.building, 'A');
    expect(profile.roomNumber, '204');
    expect(profile.isResident, isTrue);
  });

  test('Rejects non-resident role for resident UI', () {
    final profile = ResidentProfile.fromJson({
      'id': 'staff-uuid',
      'full_name': 'Staff Member',
      'role': 'maintenance_staff',
      'building': null,
      'room_number': null,
    });
    expect(profile.isResident, isFalse);
  });
}
