import 'package:dio/dio.dart';

/// A transport-agnostic failure with a message that is safe to show to the user.
///
/// Everything above the data layer catches this instead of [DioException], so
/// blocs and widgets never import Dio.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

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
      DioExceptionType.badResponse => ApiException(
        _messageFromResponse(exception.response) ??
            'Request failed with status $statusCode.',
        statusCode: statusCode,
      ),
      DioExceptionType.unknown => ApiException(
        exception.message ?? 'Something went wrong.',
        statusCode: statusCode,
      ),
    };
  }

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  /// Most APIs (including dummyjson) return `{"message": "..."}` on failure.
  static String? _messageFromResponse(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}
