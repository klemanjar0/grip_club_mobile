import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/photo_picker.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/authorized_images.dart';
import 'package:grip_club_mobile/features/files/data/avatar_uploader.dart';
import 'package:grip_club_mobile/features/files/data/file_repository.dart';

class MockFileRepository extends Mock implements FileRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

class MockAuthorizedImages extends Mock implements AuthorizedImages {}

/// A real [AvatarUploader] over a mocked [FileRepository].
///
/// The real one rather than a mock because it is trivial and because an
/// untouched selection never reaches the repository — most tests can pass this
/// in and stub nothing.
AvatarUploader avatarUploader([FileRepository? files]) =>
    AvatarUploader(files: files ?? MockFileRepository());

/// An image that gets past [LocalImage]'s sniff: a real, if tiny, PNG.
LocalImage testImage({String fileName = 'avatar.png'}) =>
    LocalImage.from(bytes: pngBytes, fileName: fileName);

/// A 1×1 transparent PNG — enough for the magic-number check and small enough
/// that a widget test can decode it.
final Uint8List pngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// An `Avatar` block as the API embeds it in a user or a lobby.
Map<String, dynamic> avatarJson({
  String id = 'f11e0000-0000-4000-8000-000000000001',
  String? url,
}) => <String, dynamic>{
  'id': id,
  'url': url ?? 'https://api.example.test/api/v1/files/$id',
};

RemoteImage remoteImage({String id = 'f11e0000-0000-4000-8000-000000000001'}) =>
    RemoteImage.fromJson(avatarJson(id: id))!;

/// Answers every image request with bytes that decode, so a widget test can
/// render a stored avatar without a network or a session.
MockAuthorizedImages stubbedImages() {
  // `any()` needs a sample value for every non-primitive argument type.
  registerFallbackValue(const RemoteImage(id: '', url: ''));

  final images = MockAuthorizedImages();
  final provider = MemoryImage(pngBytes);

  when(() => images.provider(any())).thenReturn(provider);
  when(() => images.providerForUrl(any())).thenReturn(provider);

  return images;
}
