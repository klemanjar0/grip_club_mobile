import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// Talks to the lobby endpoints.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class LobbyRepository {
  // Private field formal: callers still pass `dio:`.
  const LobbyRepository({required this._dio});

  final Dio _dio;

  /// `GET /lobbies` — upcoming public lobbies, soonest first.
  ///
  /// Passing `null` for [city] or [within] **omits the parameter**, which makes
  /// the server fall back to the user's saved preferences. To browse
  /// everywhere, pass an empty [city] instead: `?city=` explicitly overrides a
  /// saved city.
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

  /// `GET /me/lobbies` — created or approved, past events included.
  Future<PageEnvelope<Lobby>> myLobbies({
    int page = 0,
    int pageSize = PageEnvelope.defaultPageSize,
  }) => _page('/me/lobbies', <String, dynamic>{
    'page': page,
    'page_size': pageSize,
  });

  /// `GET /lobbies/{id}` — full detail for admins and approved members.
  ///
  /// `403 not_a_member` for outsiders and pending applicants; `404
  /// lobby_not_found` when the id is unknown or not a UUID.
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

  /// `POST /lobbies` — the caller becomes the admin and is approved at once.
  ///
  /// Blank optional fields are dropped rather than sent as `""`; the server
  /// stores blanks as `null` anyway, and omitting keeps the payload honest.
  Future<Lobby> create({
    required String name,
    required String country,
    required String city,
    required DateTime eventTime,
    required LobbyVisibility visibility,
    String? description,
    String? address,
    String? chatLink,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'country': country.trim(),
      'city': city.trim(),
      'event_time': eventTime.toUtc().toIso8601String(),
      'visibility': visibility.asJson,
      'description': ?_blankToNull(description),
      'address': ?_blankToNull(address),
      'chat_link': ?_blankToNull(chatLink),
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

  /// Trims, then collapses `""` to `null` so the key is dropped entirely.
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic> _require(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ApiException('The server returned an empty response.');
    }

    return data;
  }
}
