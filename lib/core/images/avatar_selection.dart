import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';

/// What the user did to an entity's image while a form was open.
///
/// Three outcomes, because the API's `avatar_file_id` has three: leave the key
/// out, send an explicit `null` to clear it, or send the id of a fresh upload.
/// Keeping them apart in one type is what lets a form report "nothing happened
/// here" instead of guessing from a nullable field.
///
/// `AvatarUploader` turns one of these into the value a request body wants; it
/// is the only place that has to know an upload happens first.
sealed class AvatarSelection extends Equatable {
  const AvatarSelection();

  /// The stored image, whatever it is, stays as it is.
  const factory AvatarSelection.unchanged() = AvatarUnchanged;

  /// The stored image is removed. The API deletes the file once nothing else
  /// points at it.
  const factory AvatarSelection.cleared() = AvatarCleared;

  /// A newly picked image replaces whatever was there.
  const factory AvatarSelection.picked(LocalImage image) = AvatarPicked;

  @override
  List<Object?> get props => [];
}

final class AvatarUnchanged extends AvatarSelection {
  const AvatarUnchanged();
}

final class AvatarCleared extends AvatarSelection {
  const AvatarCleared();
}

final class AvatarPicked extends AvatarSelection {
  const AvatarPicked(this.image);

  final LocalImage image;

  @override
  List<Object?> get props => [image];
}
