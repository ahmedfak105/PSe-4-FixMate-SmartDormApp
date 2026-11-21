/// Database-backed user profile from public.profiles.
class ResidentProfile {
  const ResidentProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.building,
    this.roomNumber,
  });

  final String id;
  final String fullName;
  final String role;
  final String? building;
  final String? roomNumber;

  bool get isResident => role.trim().toLowerCase() == 'resident';

  factory ResidentProfile.fromJson(Map<String, dynamic> json) {
    return ResidentProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      building: json['building'] as String?,
      roomNumber: json['room_number'] as String?,
    );
  }
}
