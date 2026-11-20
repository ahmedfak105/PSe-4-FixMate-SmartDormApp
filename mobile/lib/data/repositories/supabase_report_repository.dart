import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/maintenance_report.dart';
import 'report_repository.dart';

/// Resident-specific implementation. RLS in PostgreSQL is mandatory:
/// client-side .eq('resident_id', ...) is NOT a security boundary.
class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository({
    required this.client,
    required this.residentId,
  });

  final SupabaseClient client;
  final String residentId;
  List<_Category>? _categories;

  void _checkSession() {
    if (client.auth.currentUser?.id != residentId) {
      throw StateError('Resident session changed. Please sign in again.');
    }
  }

  Future<List<_Category>> _getAllCategories() async {
    _checkSession();
    if (_categories != null) return _categories!;
    final rows = await client
        .from('maintenance_categories')
        .select('id, name, is_active')
        .order('name');
    final parsed = rows.map((row) => _Category.fromJson(row)).toList();
    _categories = parsed;
    return parsed;
  }

  @override
  Future<List<String>> getCategories() async {
    final categories = await _getAllCategories();
    return categories
        .where((category) => category.isActive)
        .map((category) => category.name)
        .toList(growable: false);
  }

  @override
  Future<List<MaintenanceReport>> getMyReports() async {
    _checkSession();
    final categories = await _getAllCategories();
    final namesById = {for (final category in categories) category.id: category.name};
    final rows = await client
        .from('maintenance_reports')
        .select('id, resident_id, category_id, title, description, location, status, created_at')
        .eq('resident_id', residentId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final categoryId = (row['category_id'] as num).toInt();
      return MaintenanceReport.fromDatabase(
        row,
        categoryName: namesById[categoryId] ?? 'Category #$categoryId',
      );
    }).toList(growable: false);
  }

  @override
  Future<MaintenanceReport> createReport({
    required String title,
    required String category,
    required String location,
    required String description,
  }) async {
    _checkSession();
    final categories = await _getAllCategories();
    final matching = categories.where(
      (entry) => entry.isActive && entry.name == category,
    );
    if (matching.isEmpty) {
      throw StateError('Selected category is no longer available. Refresh the form.');
    }
    final categoryId = matching.first.id;
    // id, status & created_at: DB values are returned after insert.
    // No elevated client key, no staff assignment in Resident app.
    final row = await client.from('maintenance_reports').insert({
      'resident_id': residentId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'location': location,
      'status': 'new',
    }).select('id, resident_id, category_id, title, description, location, status, created_at').single();
    return MaintenanceReport.fromDatabase(row, categoryName: category);
  }
}

class _Category {
  const _Category({required this.id, required this.name, required this.isActive});
  final int id;
  final String name;
  final bool isActive;

  factory _Category.fromJson(Map<String, dynamic> row) => _Category(
    id: (row['id'] as num).toInt(),
    name: row['name'] as String,
    isActive: row['is_active'] as bool,
  );
}
