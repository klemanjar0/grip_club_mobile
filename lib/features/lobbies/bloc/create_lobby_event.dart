part of 'create_lobby_bloc.dart';

sealed class CreateLobbyEvent extends Equatable {
  const CreateLobbyEvent();

  @override
  List<Object?> get props => [];
}

/// The form passes raw values; trimming and dropping blanks is the
/// repository's job.
final class CreateLobbySubmitted extends CreateLobbyEvent {
  const CreateLobbySubmitted({
    required this.name,
    required this.country,
    required this.city,
    required this.eventTime,
    required this.visibility,
    this.description,
    this.address,
    this.chatLink,
  });

  final String name;
  final String country;
  final String city;
  final DateTime eventTime;
  final LobbyVisibility visibility;
  final String? description;
  final String? address;
  final String? chatLink;

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
  ];
}
