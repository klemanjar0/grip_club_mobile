import 'package:flutter/widgets.dart';

import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/auth_interceptor.dart';
import 'package:grip_club_mobile/core/storage/token_storage.dart';

/// Turns a [RemoteImage] into something an [Image] widget can load.
///
/// `GET /files/{id}` is auth-gated like every other endpoint, so an image URL
/// cannot simply be handed to `Image.network` — it needs the bearer token on
/// the request. This is the one place that knows that, which keeps
/// [TokenStorage] out of the widget layer.
///
/// The bytes at an id never change (the API serves them `immutable` with a year
/// of `max-age`), so Flutter's own [ImageCache], keyed by URL, is free to hold
/// on to a decoded image for as long as it likes.
class AuthorizedImages {
  // Private field formal: callers still pass `tokenStorage:`.
  const AuthorizedImages({required this._tokenStorage});

  final TokenStorage _tokenStorage;

  /// A provider for [image], carrying the current session token.
  ///
  /// Built per call rather than cached: signing out and back in issues a new
  /// token, and a provider that captured the old one would 401 forever.
  ImageProvider provider(RemoteImage image) => providerForUrl(image.url);

  ImageProvider providerForUrl(String url) {
    final token = _tokenStorage.readToken();

    return NetworkImage(
      url,
      headers: <String, String>{
        if (token != null) AuthInterceptor.authorizationHeader: 'Bearer $token',
      },
    );
  }
}
