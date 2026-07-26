import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';

/// Where an image is coming from.
///
/// Two entries because the OS puts images in two different places and offers a
/// different UI for each: the photo library, and the document browser (iCloud
/// Drive, Downloads, Google Drive, …). Neither can reach the other's contents,
/// so the choice is the user's to make.
enum ImagePickSource {
  gallery,
  files;

  String get label => switch (this) {
    ImagePickSource.gallery => 'Choose from photos',
    ImagePickSource.files => 'Browse files',
  };
}

/// Picks one image off the device and hands back validated bytes.
///
/// The two plugins behind it are an implementation detail: everything above
/// sees [ImagePickSource] going in and a [LocalImage] coming back. That is also
/// what makes the widget layer testable — a fake [PhotoPicker] needs no
/// platform channel.
///
/// Returns `null` when the user backs out, and throws [LocalImageException]
/// when what they picked cannot be uploaded.
class PhotoPicker {
  PhotoPicker({ImagePicker? gallery}) : _gallery = gallery ?? ImagePicker();

  /// Long edge the photo library is asked to downscale to.
  ///
  /// Avatars are shown at a few hundred logical pixels at most, and a modern
  /// phone camera produces files that would trip the API's 5 MiB limit on their
  /// own. The document browser gets no such treatment — it hands back the file
  /// as it is, and [LocalImage] refuses it if it is too big.
  static const double maxDimension = 1440;
  static const int quality = 85;

  final ImagePicker _gallery;

  Future<LocalImage?> pick(ImagePickSource source) async => switch (source) {
    ImagePickSource.gallery => _fromGallery(),
    ImagePickSource.files => _fromFiles(),
  };

  Future<LocalImage?> _fromGallery() async {
    final picked = await _gallery.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
    );

    if (picked == null) return null;

    return LocalImage.from(
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
    );
  }

  Future<LocalImage?> _fromFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      // Mobile hands back a path by default; the upload wants bytes, and so
      // does the check that runs before it.
      withData: true,
    );

    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return null;

    final file = files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    return LocalImage.from(bytes: bytes, fileName: file.name);
  }
}
