import 'dart:typed_data';

/// Prevalidated photo bytes for browser/mobile upload.
/// The type is detected from file content, not the supplied filename.
class PhotoData {
  PhotoData._(this.bytes, this.extension, this.contentType);

  static const maxBytes = 5 * 1000 * 1000;

  final Uint8List bytes;
  final String extension;
  final String contentType;

  static PhotoData fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw const FormatException('Image is too large (maximum 5 MB).');
    }
    // JPEG
    if (bytes.length >= 3 &&
        bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return PhotoData._(bytes, 'jpg', 'image/jpeg');
    }
    // PNG
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (bytes.length >= png.length &&
        List.generate(png.length, (i) => bytes[i] == png[i]).every((match) => match)) {
      return PhotoData._(bytes, 'png', 'image/png');
    }
    // WebP: RIFF .... WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return PhotoData._(bytes, 'webp', 'image/webp');
    }
    throw const FormatException('Select a JPEG, PNG or WebP photo.');
  }
}
