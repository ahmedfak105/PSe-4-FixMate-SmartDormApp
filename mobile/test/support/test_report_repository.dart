import 'package:fixmate_mobile/data/models/maintenance_report.dart';
import 'package:fixmate_mobile/data/repositories/report_repository.dart';

/// Deterministic fake used only by isolated widget/unit tests.
/// This file is outside lib/ and is not included in the installed application.
class TestReportRepository implements ReportRepository {
  static const testCategories = [
    'Plumbing', 'Electrical', 'Heating', 'Furniture',
    'Internet', 'Cleaning', 'Appliances', 'Other',
  ];

  final _reports = <MaintenanceReport>[
    MaintenanceReport(
      id: 'FM-001', title: 'Leaking bathroom tap', category: 'Plumbing',
      location: 'Room 214', description: 'The tap leaks even when turned off.',
      status: MaintenanceStatus.inProgress, createdAt: DateTime(2026, 11, 10),
    ),
    MaintenanceReport(
      id: 'FM-002', title: 'Broken corridor light', category: 'Electrical',
      location: 'Floor 2', description: 'The corridor light is not working.',
      status: MaintenanceStatus.newReport, createdAt: DateTime(2026, 11, 14),
    ),
  ];

  @override
  Future<List<MaintenanceReport>> getMyReports() async => List.unmodifiable(_reports);

  @override
  Future<List<String>> getCategories() async => testCategories;

  @override
  Future<MaintenanceReport> createReport({
    required String title,
    required String category,
    required String location,
    required String description,
  }) async {
    final report = MaintenanceReport(
      id: 'FM-${(_reports.length + 1).toString().padLeft(3, '0')}',
      title: title, category: category, location: location,
      description: description, status: MaintenanceStatus.newReport,
      createdAt: DateTime.now(),
    );
    _reports.insert(0, report);
    return report;
  }
}
