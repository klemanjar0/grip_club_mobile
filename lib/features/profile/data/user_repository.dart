import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';

/// Reads and updates the signed-in user's profile.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class UserRepository {
  // Private field formal: callers still pass `dio:`.
  const UserRepository({required this._dio});

  final Dio _dio;

  /// `PATCH /me` — every field is optional and independent.
  ///
  /// Omitted keys are left unchanged server-side, so only non-null arguments go
  /// into the body. None of the text fields are nullable, which is why there is
  /// no way to "clear" one: sending `''` for [displayName] or [city] resets it
  /// to the empty default instead.
  ///
  /// [avatarFileId] is the exception, and the reason it is an [Optional]: an
  /// explicit `null` there *removes* the picture, while leaving the argument
  /// out keeps whatever is on the profile. The id has to come from this user's
  /// own `POST /files`, or the call fails with `404 file_not_found`.
  Future<User> updatePreferences({
    String? displayName,
    String? locale,
    String? timezone,
    String? city,
    String? timeFilter,
    Optional<String>? avatarFileId,
  }) async {
    final body = <String, dynamic>{
      'display_name': ?displayName,
      'locale': ?locale,
      'timezone': ?timezone,
      'city': ?city,
      'time_filter': ?timeFilter,
      // Present-and-null is the whole point here: the key has to be in the body
      // carrying `null`, which `?` would drop.
      if (avatarFileId != null) 'avatar_file_id': avatarFileId.value,
    };

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/me',
        data: body,
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty profile.');
      }

      return User.fromJson(data);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
