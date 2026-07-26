import 'package:dio/dio.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';

/// Uploads images and hands back the id everything else refers to them by.
///
/// Throws [ApiException] only — [DioException] never escapes this layer.
class FileRepository {
  // Private field formal: callers still pass `dio:`.
  const FileRepository({required this._dio});

  /// An upload is a body, not a handshake: a 5 MiB file on a slow connection
  /// needs longer than the app-wide send timeout allows.
  static const Duration uploadTimeout = Duration(minutes: 2);

  final Dio _dio;

  /// `POST /files` — `multipart/form-data` with the image in a part named
  /// `file`.
  ///
  /// The returned file is not attached to anything yet: pass its [RemoteImage.id]
  /// as `avatar_file_id` to `PATCH /me`, `POST /lobbies` or
  /// `PATCH /lobbies/{id}`. Anything left unattached is reclaimed server-side
  /// after 24 hours, which is why uploading belongs inside a save flow rather
  /// than at pick time.
  ///
  /// [LocalImage] has already refused anything over the size limit or of the
  /// wrong type, so `413` and `415` should not reach here.
  Future<RemoteImage> upload(LocalImage image) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        image.bytes,
        filename: image.fileName,
        contentType: DioMediaType.parse(image.mimeType),
      ),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files',
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: uploadTimeout,
          receiveTimeout: uploadTimeout,
        ),
      );

      final uploaded = RemoteImage.fromJson(response.data);
      if (uploaded == null) {
        throw const ApiException('The upload did not come back with a file.');
      }

      return uploaded;
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
