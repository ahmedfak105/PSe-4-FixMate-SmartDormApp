enum MaintenanceStatus { newReport, inProgress, resolved, unknown }

/// A maintenance report visible to a Resident. The id displayed in the UI
/// is the database bigint as text; test-only records are created in test/.
class MaintenanceReport {
  const MaintenanceReport({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String location;
  final String description;
  final MaintenanceStatus status;
  final DateTime createdAt;

  static MaintenanceStatus parseDbStatus(String value) {
    return switch (value.trim().toLowerCase()) {
      'new' => MaintenanceStatus.newReport,
      'in_progress' || 'in progress' => MaintenanceStatus.inProgress,
      'resolved' => MaintenanceStatus.resolved,
      _ => MaintenanceStatus.unknown,
    };
  }

  /// Interpret DB JSON without assuming category.name is joined into the
  /// result; the repository resolves category_id using its category query.
  factory MaintenanceReport.fromDatabase(
    Map<String, dynamic> row, {
    required String categoryName,
  }) {
    return MaintenanceReport(
      id: '${row['id']}',
      title: row['title'] as String,
      category: categoryName,
      location: row['location'] as String? ?? '',
      description: row['description'] as String? ?? '',
      status: parseDbStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
