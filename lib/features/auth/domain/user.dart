import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/images/remote_image.dart';

/// The signed-in user, as returned by `GET /me`.
///
/// Mirrors the API's `UserResponse`. [locale] and [timeFilter] stay as strings
/// rather than enums: they are server-defined vocabularies, and nothing in the
/// app branches on them yet.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.locale = 'en',
    this.timezone = 'UTC',
    this.city = '',
    this.timeFilter = 'all',
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    // The server guarantees a non-empty display name (it falls back to the
    // email local part), but a missing key must not blank the UI.
    displayName: switch (json['display_name']) {
      final String name when name.isNotEmpty => name,
      _ => json['email'] as String? ?? '',
    },
    locale: json['locale'] as String? ?? 'en',
    timezone: json['timezone'] as String? ?? 'UTC',
    city: json['city'] as String? ?? '',
    timeFilter: json['time_filter'] as String? ?? 'all',
    avatar: RemoteImage.fromJson(json['avatar']),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );

  final String id;
  final String email;
  final String displayName;

  /// `en` | `ru`.
  final String locale;

  /// IANA timezone name.
  final String timezone;

  /// Saved browsing default; `''` means everywhere.
  final String city;

  /// Saved browsing default: `day` | `week` | `month` | `all`.
  final String timeFilter;

  /// The uploaded profile picture. `null` until one is set.
  final RemoteImage? avatar;

  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    locale,
    timezone,
    city,
    timeFilter,
    avatar,
    createdAt,
  ];
}
