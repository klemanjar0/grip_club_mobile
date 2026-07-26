import 'package:equatable/equatable.dart';

/// An image that lives on the server, as `{id, url}`.
///
/// This is the API's shared `Avatar` type, embedded by every entity that can
/// carry an uploaded image, and also the useful half of the `FileResponse` that
/// `POST /files` answers with — both carry an `id` and a `url`, so one model
/// covers the upload and everything that later points at it.
///
/// [url] is an authenticated endpoint, not a public one: fetching it needs the
/// same bearer token as any other call. Loading it through
/// [AuthorizedImages][] is what supplies that header.
///
/// [AuthorizedImages]: ../network/authorized_images.dart
class RemoteImage extends Equatable {
  const RemoteImage({required this.id, required this.url});

  /// `null` for a missing or malformed block, which is how the API says
  /// "no image" — `avatar` is present and `null` until one is set.
  static RemoteImage? fromJson(Object? json) {
    if (json is! Map) return null;

    final id = json['id'];
    final url = json['url'];
    if (id is! String || url is! String || id.isEmpty || url.isEmpty) {
      return null;
    }

    return RemoteImage(id: id, url: url);
  }

  /// The file id. This is what goes into an `avatar_file_id` field.
  final String id;

  /// Absolute URL of the bytes; needs the `Authorization` header.
  final String url;

  @override
  List<Object?> get props => [id, url];
}
