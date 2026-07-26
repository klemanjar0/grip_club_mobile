import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

class LobbyRepository {
  // Private field formal: callers still pass `dio:`.
  const LobbyRepository({required this._dio});

  final Dio _dio;

  Future<PageEnvelope<Lobby>> browse({
    String? city,
    String? within,
    int page = 0,
    int pageSize = PageEnvelope.defaultPageSize,
  }) => _page('/lobbies', <String, dynamic>{
    'city': ?city,
    'within': ?within,
    'page': page,
    'page_size': pageSize,
  });

  Future<PageEnvelope<Lobby>> myLobbies({
    int page = 0,
    int pageSize = PageEnvelope.defaultPageSize,
  }) => _page('/me/lobbies', <String, dynamic>{
    'page': page,
    'page_size': pageSize,
  });

  Future<Lobby> byId(String lobbyId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lobbies/$lobbyId',
      );
      return Lobby.fromJson(_require(response.data));
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `POST /lobbies` — the caller becomes the admin.
  ///
  /// [avatarFileId] has to be a file this user uploaded through `POST /files`,
  /// or the call fails with `404 file_not_found`. There is nothing to clear on
  /// a lobby that does not exist yet, which is why this one is a plain
  /// nullable while the same field on [update] is an `Optional`.
  Future<Lobby> create(LobbyDraft draft, {String? avatarFileId}) async {
    final body = <String, dynamic>{
      'name': draft.name,
      'country': draft.country,
      'city': draft.city,
      'event_time': draft.eventTime.toUtc().toIso8601String(),
      'visibility': draft.visibility.asJson,
      'description': ?draft.description,
      'address': ?draft.address,
      'chat_link': ?draft.chatLink,
      'avatar_file_id': ?avatarFileId,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lobbies',
        data: body,
      );
      return Lobby.fromJson(_require(response.data));
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `DELETE /lobbies/{id}` — admin only, answers `204` with no body.
  ///
  /// Every approved member is notified server-side, and the memberships and
  /// notifications cascade, so there is nothing left to clean up here.
  ///
  /// Fails with `403 admin_only`, `403 not_a_member` or `404 lobby_not_found`.
  Future<void> deleteLobby(String lobbyId) async {
    try {
      await _dio.delete<void>('/lobbies/$lobbyId');
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<Lobby> update(
    String lobbyId, {
    String? name,
    String? country,
    String? city,
    DateTime? eventTime,
    LobbyVisibility? visibility,
    Optional<String>? description,
    Optional<String>? address,
    Optional<String>? chatLink,
    Optional<String>? avatarFileId,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'country': ?country,
      'city': ?city,
      'event_time': ?eventTime?.toUtc().toIso8601String(),
      'visibility': ?visibility?.asJson,
      // Present-and-null is the whole point here: the key has to be in the body
      // carrying `null`, which `?` would drop.
      if (description != null) 'description': description.value,
      if (address != null) 'address': address.value,
      if (chatLink != null) 'chat_link': chatLink.value,
      // Clearing this one also releases the file: the server deletes it unless
      // something else still points at it.
      if (avatarFileId != null) 'avatar_file_id': avatarFileId.value,
    };

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lobbies/$lobbyId',
        data: body,
      );
      return Lobby.fromJson(_require(response.data));
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<PageEnvelope<Lobby>> _page(
    String path,
    Map<String, dynamic> queryParameters,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return PageEnvelope<Lobby>.fromJson(
        _require(response.data),
        Lobby.fromJson,
      );
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  static Map<String, dynamic> _require(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ApiException('The server returned an empty response.');
    }

    return data;
  }
}
