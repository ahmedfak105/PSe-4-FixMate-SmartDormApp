import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/photo_data.dart';

class ReportAttachment {
  const ReportAttachment({
    required this.id,
    required this.storagePath,
    required this.createdAt,
  });

  final String id;
  final String storagePath;
  final DateTime createdAt;
}

/// Files are private in report-photos; DB stores ONLY their storage paths.
/// RLS policies on storage.objects and report_attachments remain authoritative.
class SupabaseAttachmentRepository {
  SupabaseAttachmentRepository(this.client);

  static const bucket = 'report-photos';
  final SupabaseClient client;

  String _uid() {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in again.');
    return uid;
  }

  int _reportId(String reportId) {
    final parsed = int.tryParse(reportId);
    if (parsed == null || parsed <= 0) {
      throw const FormatException('Invalid report ID.');
    }
    return parsed;
  }

  Future<List<ReportAttachment>> listForReport(String reportId) async {
    _uid();
    final rows = await client
        .from('report_attachments')
        .select('id, storage_path, created_at')
        .eq('report_id', _reportId(reportId))
        .order('created_at');
    return rows.map((row) => ReportAttachment(
      id: '${row['id']}',
      storagePath: row['storage_path'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList(growable: false);
  }

  /// Downloading requires Storage SELECT/RLS; no public URL is generated.
  Future<Uint8List> download(String storagePath) async {
    _uid();
    return client.storage.from(bucket).download(storagePath);
  }

  /// Only the current Resident's own report can receive a photo.
  /// If DB metadata insert fails, try to remove the orphaned storage object.
  Future<void> upload({
    required String reportId,
    required PhotoData photo,
  }) async {
    final uid = _uid();
    final id = _reportId(reportId);
    final record = await client
        .from('maintenance_reports')
        .select('id, resident_id')
        .eq('id', id)
        .eq('resident_id', uid)
        .single();
    if (record['resident_id'] != uid) {
      throw StateError('You cannot attach a photo to this report.');
    }
    // Path convention: user UUID / report ID / unique filename.
    // Existing Storage RLS must allow this convention.
    final random = Random.secure();
    final nonce = random.nextInt(0x7fffffff).toRadixString(16);
    final path = '$uid/$id/${DateTime.now().toUtc().microsecondsSinceEpoch}_$nonce.${photo.extension}';
    final storage = client.storage.from(bucket);
    await storage.uploadBinary(
      path,
      photo.bytes,
      fileOptions: FileOptions(contentType: photo.contentType, upsert: false),
    );
    try {
      await client.from('report_attachments').insert({
        'report_id': id,
        'uploaded_by': uid,
        'storage_path': path,
      });
    } catch (_) {
      try {
        await storage.remove([path]);
      } catch (_) {
        // Cleanup is best effort; surface the original metadata error.
      }
      rethrow;
    }
  }
}
