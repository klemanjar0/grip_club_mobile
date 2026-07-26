import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// What the lobby form holds: a lobby as the user has typed it, before the
/// server has seen it.
///
/// Shared by create and edit. Values arrive normalised — trimmed, with blanks
/// collapsed to `null` — so that comparing a draft against a stored [Lobby]
/// says something true, and an emptied field reads as "clear this" rather than
/// as a change to `""`.
class LobbyDraft extends Equatable {
  const LobbyDraft({
    required this.name,
    required this.country,
    required this.city,
    required this.eventTime,
    required this.visibility,
    this.description,
    this.address,
    this.chatLink,
    this.avatar = const AvatarSelection.unchanged(),
  });

  /// Normalises raw form input.
  factory LobbyDraft.fromInput({
    required String name,
    required String country,
    required String city,
    required DateTime eventTime,
    required LobbyVisibility visibility,
    String? description,
    String? address,
    String? chatLink,
    AvatarSelection avatar = const AvatarSelection.unchanged(),
  }) => LobbyDraft(
    name: name.trim(),
    country: country.trim(),
    city: city.trim(),
    eventTime: eventTime,
    visibility: visibility,
    description: _blankToNull(description),
    address: _blankToNull(address),
    chatLink: _blankToNull(chatLink),
    avatar: avatar,
  );

  /// The starting point when editing: the lobby as it stands.
  factory LobbyDraft.of(Lobby lobby) => LobbyDraft(
    name: lobby.name,
    country: lobby.country,
    city: lobby.city,
    eventTime: lobby.eventTime ?? DateTime.now(),
    visibility: lobby.visibility,
    description: lobby.description,
    address: lobby.address,
    chatLink: lobby.chatLink,
  );

  final String name;
  final String country;
  final String city;
  final DateTime eventTime;
  final LobbyVisibility visibility;

  /// `null` means the field is empty — on an edit, that clears it.
  final String? description;
  final String? address;
  final String? chatLink;

  /// What happened to the picture while the form was open. Untouched on a
  /// draft built from a stored lobby, which is what makes an unedited form
  /// compare equal to it.
  final AvatarSelection avatar;

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    name,
    country,
    city,
    eventTime,
    visibility,
    description,
    address,
    chatLink,
    avatar,
  ];
}
