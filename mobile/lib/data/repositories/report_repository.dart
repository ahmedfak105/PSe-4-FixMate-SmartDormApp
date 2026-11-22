import '../models/maintenance_report.dart';

/// Connected report data contract. Live implementations use Supabase Auth/RLS.
abstract class ReportRepository {
  Future<List<MaintenanceReport>> getMyReports();
  Future<List<String>> getCategories();
  Future<MaintenanceReport> createReport({
    required String title,
    required String category,
    required String location,
    required String description,
  });
}
