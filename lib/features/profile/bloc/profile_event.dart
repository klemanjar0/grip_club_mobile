part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// `null` fields are omitted from the request and left unchanged. `''` is a
/// real value: it resets [displayName] or [city] to the empty default.
final class ProfilePreferencesSubmitted extends ProfileEvent {
  const ProfilePreferencesSubmitted({
    this.displayName,
    this.locale,
    this.timezone,
    this.city,
    this.timeFilter,
  });

  final String? displayName;
  final String? locale;
  final String? timezone;
  final String? city;
  final String? timeFilter;

  @override
  List<Object?> get props => [displayName, locale, timezone, city, timeFilter];
}

/// A new picture, or the removal of the current one.
///
/// Its own event rather than a field on [ProfilePreferencesSubmitted]: the
/// picture is edited by tapping it and saves immediately, so it never waits for
/// the Save button under the text fields.
final class ProfileAvatarSubmitted extends ProfileEvent {
  const ProfileAvatarSubmitted(this.selection);

  final AvatarSelection selection;

  @override
  List<Object?> get props => [selection];
}

final class ProfilePasswordSubmitted extends ProfileEvent {
  const ProfilePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  @override
  List<Object?> get props => [currentPassword, newPassword];
}
