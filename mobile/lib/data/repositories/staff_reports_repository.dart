import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_report.dart';

/// RPC operations are enforced in PostgreSQL (fixmate_private SECURITY
/// DEFINER functions). This client must NEVER use a service-role key.
abstract class StaffReportsRepository {
  Future<List<StaffReport>> listVisibleReports();
  Future<bool> claimReport(int reportId);
  Future<bool> resolveReport(int reportId);
}

class SupabaseStaffReportsRepository implements StaffReportsRepository {
  SupabaseStaffReportsRepository({
    required this.client,
    required this.staffId,
  });

  final SupabaseClient client;
  final String staffId;

  void _checkSession() {
    if (client.auth.currentUser?.id != staffId) {
      throw StateError('Your login session has changed. Please sign in again.');
    }
  }

  @override
  Future<List<StaffReport>> listVisibleReports() async {
    _checkSession();
    // RLS: staff sees available NEW reports and reports assigned to them.
    // No client-side filter is a substitute for PostgreSQL RLS.
    final rows = await client
        .from('maintenance_reports')
        .select('id, resident_id, category_id, title, description, '
            'location, status, assigned_to, created_at')
        .order('created_at', ascending: false);
    return rows.map((row) => StaffReport.fromJson(row)).toList(growable: false);
  }

  Future<bool> _runRpc(String functionName, int reportId) async {
    _checkSession();
    final result = await client.rpc(
      functionName,
      params: {'p_report_id': reportId},
    );
    if (result is! bool) {
      throw StateError('$functionName returned an unexpected response: $result');
    }
    return result;
  }

  @override
  Future<bool> claimReport(int reportId) =>
      _runRpc('claim_maintenance_report', reportId);

  @override
  Future<bool> resolveReport(int reportId) =>
      _runRpc('resolve_maintenance_report', reportId);
}
