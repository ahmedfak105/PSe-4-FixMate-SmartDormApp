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
}
