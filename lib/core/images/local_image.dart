import 'dart:typed_data';

/// An image the user has chosen on the device and that has not been uploaded
/// yet.
///
/// Held as bytes rather than as a path because that is the one shape both
/// sources agree on — a photo-library entry and a document both come back as a
/// readable stream, and the multipart upload wants bytes anyway.
///
/// Deliberately not [Equatable]: two instances are equal only if they are the
/// same pick, which is what identity already says. It also keeps a draft
/// comparison from walking several megabytes.
class LocalImage {
  const LocalImage._({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Checks the bytes the way the server will and wraps them, or throws
  /// [LocalImageException] with something showable.
  ///
  /// Doing this here rather than letting `POST /files` answer `413` or `415`
  /// saves the round trip *and* the user's data plan — a 12 MB photo would
  /// otherwise be uploaded in full before being refused.
  factory LocalImage.from({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (bytes.isEmpty) {
      throw const LocalImageException('That file is empty.');
    }

    if (bytes.lengthInBytes > maxBytes) {
      throw const LocalImageException(
        'Images have to be under $maxMegabytes MB. Pick a smaller one.',
      );
    }

    final mimeType = _sniff(bytes);
    if (mimeType == null) {
      throw const LocalImageException(
        'Only JPEG, PNG and WebP images can be uploaded.',
      );
    }

    return LocalImage._(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  /// `UPLOAD_MAX_BYTES` server-side.
  static const int maxBytes = 5 * 1024 * 1024;
  static const int maxMegabytes = maxBytes ~/ (1024 * 1024);

  final Uint8List bytes;

  /// Sent as the multipart filename. Cosmetic — the server sniffs the bytes and
  /// ignores both this and the `Content-Type` we declare.
  final String fileName;

  /// Sniffed from the bytes, so it agrees with what the server will decide.
  final String mimeType;

  int get sizeBytes => bytes.lengthInBytes;

  /// The same magic-number check the server runs on the first 512 bytes, so a
  /// `.png` that is really a JPEG is accepted (and stored as a JPEG) while a
  /// renamed PDF is refused here instead of at the API.
  static String? _sniff(Uint8List bytes) {
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';

    if (_startsWith(bytes, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }

    // RIFF????WEBP — the four length bytes in between are not part of the tag.
    if (bytes.length >= 12 &&
        _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    return null;
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;

    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }

    return true;
  }
}

/// A pick that cannot be uploaded — too big, or not an image the API accepts.
///
/// Carries a message that is safe to put in front of the user, the same
/// contract `ApiException` has, so the UI can show either without knowing which
/// it caught.
class LocalImageException implements Exception {
  const LocalImageException(this.message);

  final String message;

  @override
  String toString() => 'LocalImageException($message)';
}
