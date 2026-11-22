/// Internal maintenance note. Residents cannot view these under the project's
/// current report_notes SELECT row-level security policy.
class StaffNote {
  const StaffNote({
    required this.id,
    required this.reportId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int reportId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  factory StaffNote.fromJson(Map<String, dynamic> json) => StaffNote(
        id: (json['id'] as num).toInt(),
        reportId: (json['report_id'] as num).toInt(),
        authorId: json['author_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

String validateInternalNote(String raw) {
  final content = raw.trim();
  if (content.isEmpty) {
    throw const FormatException('Write a note before saving.');
  }
  if (content.length > 3000) {
    throw const FormatException('Note is too long (maximum 3,000 characters).');
  }
  return content;
}
