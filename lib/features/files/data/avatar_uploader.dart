import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/files/data/file_repository.dart';

/// Turns what the user did to an image into the `avatar_file_id` a request body
/// wants, uploading first when there is something new to upload.
///
/// This is the seam that keeps the two-step nature of attaching an image out of
/// every feature: a bloc hands over the [AvatarSelection] its form produced and
/// gets back a value it can pass straight to a repository. Profile and lobbies
/// share it because the API's field is the same in both places.
///
/// The result reads exactly the way the API does:
///
/// | Selection | Result | Body |
/// |---|---|---|
/// | [AvatarUnchanged] | `null` | key omitted — leave it alone |
/// | [AvatarCleared] | `Optional.clear()` | `"avatar_file_id": null` — remove it |
/// | [AvatarPicked] | `Optional(id)` | the id of the fresh upload |
///
/// Throws [ApiException] when the upload fails; the calling bloc already
/// handles that for the save itself.
class AvatarUploader {
  // Private field formal: callers still pass `files:`.
  const AvatarUploader({required this._files});

  final FileRepository _files;

  /// `null` means "leave this key out of the body entirely".
  Future<Optional<String>?> resolve(AvatarSelection selection) async =>
      switch (selection) {
        AvatarUnchanged() => null,
        AvatarCleared() => const Optional<String>.clear(),
        AvatarPicked(:final image) => Optional<String>(
          (await _files.upload(image)).id,
        ),
      };
}
