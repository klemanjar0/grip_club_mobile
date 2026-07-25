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
