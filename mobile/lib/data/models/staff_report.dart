/// Read-only report row shown to authenticated maintenance staff.
/// PostgreSQL row-level security decides which rows the staff member sees.
class StaffReport {
  const StaffReport({
    required this.id,
    required this.residentId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.assignedTo,
    required this.createdAt,
  });

  final int id;
  final String residentId;
  final int categoryId;
  final String title;
  final String description;
  final String location;
  final String status;
  final String? assignedTo;
  final DateTime createdAt;

  bool get isAvailable => status == 'new' && assignedTo == null;

  bool isAssignedTo(String staffId) => assignedTo == staffId;

  /// An assigned-but-still-new report can be claimed by its assigned staff.
  bool canClaim(String staffId) =>
      status == 'new' && (assignedTo == null || assignedTo == staffId);

  bool canResolve(String staffId) =>
      status == 'in_progress' && assignedTo == staffId;

  factory StaffReport.fromJson(Map<String, dynamic> json) => StaffReport(
        id: (json['id'] as num).toInt(),
        residentId: json['resident_id'] as String,
        categoryId: (json['category_id'] as num).toInt(),
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        status: json['status'] as String,
        assignedTo: json['assigned_to'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
