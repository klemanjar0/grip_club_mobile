import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';

/// Reads and mutates the notification feed. Notifications are polled — there is
/// no push delivery yet.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class NotificationRepository {
  // Private field formal: callers still pass `dio:`.
  const NotificationRepository({required this._dio});

  final Dio _dio;

  /// `GET /notifications`, newest first.
  ///
  /// Only the literal string `true` filters to unread server-side, so the flag
  /// is sent as a string rather than a bool.
  Future<PageEnvelope<AppNotification>> feed({
    bool unreadOnly = false,
    int page = 0,
    int pageSize = PageEnvelope.defaultPageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: <String, dynamic>{
          'unread': ?(unreadOnly ? 'true' : null),
          'page': page,
          'page_size': pageSize,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty feed.');
      }

      return PageEnvelope<AppNotification>.fromJson(
        data,
        AppNotification.fromJson,
      );
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `GET /notifications/unread-count` — cheap enough to poll for the badge.
  Future<int> unreadCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications/unread-count',
      );

      return response.data?['unread'] as int? ?? 0;
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// `POST /notifications/{id}/read`.
  ///
  /// The endpoint answers `404 not_found` when the notification was *already*
  /// read, so it is not idempotent server-side. That case is swallowed here:
  /// for the caller, "it is read now" is the outcome either way.
  Future<void> markRead(String notificationId) async {
    try {
      await _dio.post<void>('/notifications/$notificationId/read');
    } on DioException catch (exception) {
      final failure = ApiException.fromDioException(exception);
      if (failure.statusCode == 404) return;

      throw failure;
    }
  }

  /// `POST /notifications/read-all` → how many rows flipped.
  Future<int> markAllRead() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/notifications/read-all',
      );

      return response.data?['marked'] as int? ?? 0;
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
