import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/domain/lobby_member.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

/// Joining and leaving lobbies, plus everything an admin does to the roster.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class MembershipRepository {
  // Private field formal: callers still pass `dio:`.
  const MembershipRepository({required this._dio});

  final Dio _dio;

  /// `GET /lobbies/{id}/members?status=…` — admin only.
  ///
  /// One roster per [status]; the `approved` one includes the creator. Ordered
  /// by `joined_at` ascending and **not paginated**, so the whole list arrives
  /// at once.
  ///
  /// Fails with `403 admin_only` for a member, `403 not_a_member` for anyone
  /// else, and `404 lobby_not_found`.
  Future<List<LobbyMember>> members(
    String lobbyId, {
    MembershipStatus status = MembershipStatus.approved,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lobbies/$lobbyId/members',
        queryParameters: <String, dynamic>{'status': status.name},
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty roster.');
      }

      return LobbyMember.listFromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

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

  /// `POST /lobbies/{id}/members/{userID}/approve` — admin only.
  ///
  /// Flips a `pending` row to `approved` and notifies the applicant. The body
  /// carries the updated membership.
  ///
  /// Fails with `403 admin_only`, `403 cannot_target_self`, `403 not_a_member`,
  /// `404 member_not_found` or `404 lobby_not_found`.
  Future<Membership> approve(String lobbyId, String userId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lobbies/$lobbyId/members/$userId/approve',
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

  /// `POST /lobbies/{id}/members/{userID}/reject` — admin only, `204`.
  ///
  /// Deletes the pending row rather than marking it, so a decline is not
  /// permanent: the applicant may ask again. Banning is the terminal one.
  ///
  /// Fails with the same codes as [approve].
  Future<void> reject(String lobbyId, String userId) async {
    try {
      await _dio.post<void>('/lobbies/$lobbyId/members/$userId/reject');
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `POST /lobbies/{id}/members/{userID}/ban` — admin only.
  ///
  /// The terminal verdict, and the one thing [reject] and [remove] are not:
  /// it upserts a `banned` row, and a row that exists is what makes rejoining
  /// impossible. Works on anyone, including someone who was never a member.
  ///
  /// Fails with the same codes as [approve].
  Future<Membership> ban(String lobbyId, String userId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lobbies/$lobbyId/members/$userId/ban',
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

  /// `DELETE /lobbies/{id}/members/{userID}` — admin only, `204`.
  ///
  /// Deletes the membership row whatever state it was in, so this both takes an
  /// approved member out and lifts a ban: with no row left, the person may join
  /// again. They are notified either way.
  ///
  /// Fails with the same codes as [approve].
  Future<void> remove(String lobbyId, String userId) async {
    try {
      await _dio.delete<void>('/lobbies/$lobbyId/members/$userId');
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
