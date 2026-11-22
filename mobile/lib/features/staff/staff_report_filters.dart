import '../../data/models/staff_report.dart';

/// Applies text/status/category/date filters to *already RLS-authorized*
/// maintenance reports. Never use a client-side filter for authorization.
List<StaffReport> filterStaffVisibleReports(
  List<StaffReport> visible, {
  String query = '',
  String status = 'all',
  String category = 'all',
  String dateRange = 'all',
  DateTime? now,
}) {
  final search = query.trim().toLowerCase();
  final today = (now ?? DateTime.now()).toUtc();
  final DateTime? cutoff = switch (dateRange) {
    'last7' => today.subtract(const Duration(days: 7)),
    'last30' => today.subtract(const Duration(days: 30)),
    _ => null,
  };
  return visible.where((report) {
    if (status != 'all' && report.status != status) return false;
    if (category != 'all' && report.categoryId.toString() != category) {
      return false;
    }
    if (cutoff != null && report.createdAt.toUtc().isBefore(cutoff)) {
      return false;
    }
    if (search.isEmpty) return true;
    final haystack = [
      report.id,
      report.title,
      report.description,
      report.location,
      'category ${report.categoryId}',
    ].join(' ').toLowerCase();
    return haystack.contains(search);
  }).toList(growable: false);
}
