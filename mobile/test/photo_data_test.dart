import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/data/models/photo_data.dart';
import 'package:fixmate_mobile/data/repositories/report_repository.dart';
import 'package:fixmate_mobile/features/reports/reports_cubit.dart';

void main() {
  test('Recognizes JPEG signature and MIME', () {
    final photo = PhotoData.fromBytes(Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]));
    expect(photo.extension, 'jpg');
    expect(photo.contentType, 'image/jpeg');
  });

  test('Recognizes PNG and WebP magic bytes', () {
    final png = PhotoData.fromBytes(Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]));
    final webp = PhotoData.fromBytes(Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
    ]));
    expect(png.contentType, 'image/png');
    expect(webp.extension, 'webp');
  });

  test('Cubit stores new report ID for photo upload', () async {
    final cubit = ReportsCubit(InMemoryReportRepository());
    final saved = await cubit.create(
      title: 'Photo test', category: 'Electrical',
      location: 'Room 101', description: 'Test description',
    );
    expect(saved, isTrue);
    expect(cubit.lastCreatedReportId, 'FM-003');
    await cubit.close();
  });

  test('Rejects invalid and oversized files', () {
    expect(() => PhotoData.fromBytes(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    expect(() => PhotoData.fromBytes(Uint8List(PhotoData.maxBytes + 1)), throwsFormatException);
  });
}
