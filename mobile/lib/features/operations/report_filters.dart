/// Presentation-only filtering of reports already returned by the server.
/// Authorization must remain enforced by the underlying Supabase RLS policy.
/// Never use this function to decide which rows a user is allowed to fetch.
List<Map<String, dynamic>> filterVisibleReports(
  List<Map<String, dynamic>> visibleReports, {
  required Map<int, String> categoryNames,
  String text = '',
  String status = 'all',
  String category = 'all',
  String dateRange = 'all',
  DateTime? now,
  bool assignmentsOnly = false,
}) {
  final needle = text.trim().toLowerCase();
  final dateNow = (now ?? DateTime.now()).toUtc();
  final DateTime? cutoff = switch (dateRange) {
    'last7' => dateNow.subtract(const Duration(days: 7)),
    'last30' => dateNow.subtract(const Duration(days: 30)),
    _ => null,
  };

  return visibleReports.where((report) {
    if (assignmentsOnly &&
        (report['status'] != 'new' || report['assigned_to'] != null)) {
      return false;
    }
    if (status != 'all' && report['status'] != status) return false;

    final rawCategory = report['category_id'];
    final categoryId = rawCategory is num ? rawCategory.toInt() : null;
    if (category != 'all' && categoryId?.toString() != category) return false;

    if (cutoff != null) {
      final rawDate = report['created_at'];
      final date = rawDate is DateTime ? rawDate
          : DateTime.tryParse(rawDate?.toString() ?? '');
      if (date == null || date.toUtc().isBefore(cutoff)) return false;
    }

    if (needle.isEmpty) return true;
    final searchable = [
      report['id'],
      report['title'],
      report['description'],
      report['location'],
      categoryNames[categoryId],
    ].map((part) => part?.toString() ?? '').join(' ').toLowerCase();
    return searchable.contains(needle);
  }).toList(growable: false);
}
