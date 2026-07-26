import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';

import '../../helpers/avatar_fixtures.dart';

/// Enough of a header for the sniff; nothing reads past it.
Uint8List _bytes(List<int> header, {int padTo = 32}) => Uint8List.fromList([
  ...header,
  ...List<int>.filled(padTo - header.length, 0),
]);

void main() {
  group('type sniffing', () {
    test('accepts a JPEG', () {
      final image = LocalImage.from(
        bytes: _bytes(const [0xFF, 0xD8, 0xFF, 0xE0]),
        fileName: 'photo.jpg',
      );

      expect(image.mimeType, 'image/jpeg');
    });

    test('accepts a PNG', () {
      expect(testImage().mimeType, 'image/png');
    });

    test('accepts a WebP', () {
      final image = LocalImage.from(
        // RIFF, four length bytes, then WEBP.
        bytes: _bytes(const [
          0x52, 0x49, 0x46, 0x46, //
          0x00, 0x00, 0x00, 0x00,
          0x57, 0x45, 0x42, 0x50,
        ]),
        fileName: 'photo.webp',
      );

      expect(image.mimeType, 'image/webp');
    });

    test('goes by the bytes, not the extension', () {
      // The API sniffs too, so a JPEG named `.png` is stored as a JPEG. Saying
      // otherwise here would put the wrong type on the multipart part.
      final image = LocalImage.from(
        bytes: _bytes(const [0xFF, 0xD8, 0xFF, 0xE0]),
        fileName: 'photo.png',
      );

      expect(image.mimeType, 'image/jpeg');
    });

    test('refuses a renamed PDF before it costs an upload', () {
      expect(
        () => LocalImage.from(
          bytes: _bytes(const [0x25, 0x50, 0x44, 0x46]),
          fileName: 'photo.png',
        ),
        throwsA(isA<LocalImageException>()),
      );
    });
  });

  group('size', () {
    test('refuses anything over the API limit', () {
      final tooBig = Uint8List(LocalImage.maxBytes + 1)
        ..setRange(0, 3, const [0xFF, 0xD8, 0xFF]);

      expect(
        () => LocalImage.from(bytes: tooBig, fileName: 'huge.jpg'),
        throwsA(
          isA<LocalImageException>().having(
            (exception) => exception.message,
            'message',
            contains('under 5 MB'),
          ),
        ),
      );
    });

    test('refuses an empty file', () {
      expect(
        () => LocalImage.from(bytes: Uint8List(0), fileName: 'nothing.png'),
        throwsA(isA<LocalImageException>()),
      );
    });
  });
}
