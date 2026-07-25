import 'package:dio/dio.dart';

/// A transport-agnostic failure with a message that is safe to show to the user.
///
/// Everything above the data layer catches this instead of [DioException], so
/// blocs and widgets never import Dio.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  /// Translates a Dio failure into a user-facing message.
  factory ApiException.fromDioException(DioException exception) {
    final statusCode = exception.response?.statusCode;

    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => const ApiException(
        'The server took too long to respond. Please try again.',
      ),
      DioExceptionType.connectionError => const ApiException(
        'No internet connection.',
      ),
      DioExceptionType.badCertificate => const ApiException(
        'The server certificate could not be verified.',
      ),
      DioExceptionType.cancel => const ApiException('Request cancelled.'),
      DioExceptionType.badResponse => _fromResponse(
        exception.response,
        fallback: 'Request failed with status $statusCode.',
      ),
      DioExceptionType.unknown => ApiException(
        exception.message ?? 'Something went wrong.',
        statusCode: statusCode,
      ),
    };
  }

  final String message;
  final int? statusCode;

  /// The API's machine-readable error code (`email_taken`, `not_a_member`, …).
  /// Switch on this, never on [message] — messages are user-facing prose and
  /// may be reworded server-side.
  final String? code;

  /// Per-field validation errors, keyed by JSON field name. Only populated for
  /// `validation_failed`; empty for every other failure.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  bool get isEmailTaken => code == 'email_taken';

  /// Reads the API's error envelope: `{"error": {code, message, details?}}`.
  /// Falls back to a flat `{"message": ...}` and finally to [fallback], so a
  /// proxy or a crash that never reaches the handler still yields something
  /// showable.
  static ApiException _fromResponse(
    Response<dynamic>? response, {
    required String fallback,
  }) {
    final statusCode = response?.statusCode;
    final data = response?.data;

    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        return ApiException(
          error['message'] is String ? error['message'] as String : fallback,
          statusCode: statusCode,
          code: error['code'] is String ? error['code'] as String : null,
          fieldErrors: _readDetails(error['details']),
        );
      }
      if (data['message'] is String) {
        return ApiException(data['message'] as String, statusCode: statusCode);
      }
    }

    return ApiException(fallback, statusCode: statusCode);
  }

  static Map<String, String> _readDetails(Object? details) {
    if (details is! Map) return const {};

    return <String, String>{
      for (final entry in details.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message)';
}
