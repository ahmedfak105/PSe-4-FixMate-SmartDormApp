import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resident_profile.dart';

/// Only reads the signed-in user's own profile. PostgreSQL RLS must also
/// enforce the ownership rule on public.profiles; the client filter alone
/// is not a security boundary.
class ResidentProfileRepository {
  ResidentProfileRepository(this.client);

  final SupabaseClient client;

  Future<ResidentProfile> getCurrent() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    final row = await client
        .from('profiles')
        .select('id, full_name, role, building, room_number')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw StateError('No profile row is visible for this account');
    }
    return ResidentProfile.fromJson(row);
  }
  /// Only approved editable fields are sent by the client. The database
  /// must additionally enforce column-level UPDATE grants for privileged fields.
  Future<ResidentProfile> updateMyContactDetails({
    required String fullName,
    String? building,
    String? roomNumber,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final name = fullName.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Name must be between 1 and 100 characters.');
    }
    String? optional(String? s) {
      final value = s?.trim() ?? '';
      if (value.length > 80) throw ArgumentError('Location fields must be at most 80 characters.');
      return value.isEmpty ? null : value;
    }
    final updated = await client.from('profiles').update({
      'full_name': name,
      'building': optional(building),
      'room_number': optional(roomNumber),
    }).eq('id', user.id)
      .select('id, full_name, role, building, room_number')
      .single();
    if (client.auth.currentUser?.id != user.id) {
      throw StateError('Session changed while saving profile.');
    }
    return ResidentProfile.fromJson(updated);
  }

}
