import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

/// Joining and leaving lobbies.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class MembershipRepository {
  // Private field formal: callers still pass `dio:`.
  const MembershipRepository({required this._dio});

  final Dio _dio;

  /// `POST /lobbies/{id}/join`.
  ///
  /// Both outcomes are a `200`: a public lobby comes back `approved`, a private
  /// one `pending` with the admin notified. Read [Membership.status].
  ///
  /// Fails with `403 banned`, `404 lobby_not_found`, `409 already_member` or
  /// `409 request_pending`.
  Future<Membership> join(String lobbyId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lobbies/$lobbyId/join',
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty membership.');
      }

      return Membership.fromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `DELETE /lobbies/{id}/membership` — leaves a lobby, or withdraws a request
  /// that is still pending.
  ///
  /// Fails with `403 creator_cannot_leave` for the admin: they must delete the
  /// lobby instead.
  Future<void> leave(String lobbyId) async {
    try {
      await _dio.delete<void>('/lobbies/$lobbyId/membership');
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
