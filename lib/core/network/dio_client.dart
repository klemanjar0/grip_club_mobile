import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/core/network/auth_interceptor.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';

/// Builds the single app-wide [Dio] instance, configured from [AppConfig].
Dio createDio({
  required TokenStorage tokenStorage,
  required void Function() onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      sendTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.connectTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(tokenStorage: tokenStorage, onUnauthorized: onUnauthorized),
  );

  if (AppConfig.enableHttpLogging) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (Object? object) => debugPrint(_redactTokens('$object')),
      ),
    );
  }

  return dio;
}

final RegExp _bearerPattern = RegExp(r'Bearer\s+[\w\-.]+');

/// Keeps session tokens out of the console even with logging enabled.
String _redactTokens(String message) =>
    message.replaceAll(_bearerPattern, 'Bearer <redacted>');
