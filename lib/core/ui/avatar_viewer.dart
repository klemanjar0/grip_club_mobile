import 'package:flutter/material.dart';

import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/authorized_images.dart';
import 'package:grip_club_mobile/core/ui/avatar_image.dart';

/// Opens an avatar full screen, zoomable, over everything else.
///
/// Everywhere an avatar is shown it is cropped square to fit its slot, so the
/// only way to see the whole picture is to open it. Returns as soon as the
/// viewer is dismissed; does nothing at all when there is no image, so callers
/// can wire it up without guarding first.
Future<void> showAvatarViewer(
  BuildContext context, {
  RemoteImage? image,
  LocalImage? preview,
  AuthorizedImages? images,
  String? title,
}) {
  final route = avatarViewerRoute(
    image: image,
    preview: preview,
    images: images,
    title: title,
  );

  return route == null
      ? Future<void>.value()
      : Navigator.of(context, rootNavigator: true).push(route);
}

/// The route behind [showAvatarViewer], for callers that have to capture a
/// navigator before an `await` rather than pass a context after one.
///
/// `null` when there is nothing to show.
PageRoute<void>? avatarViewerRoute({
  RemoteImage? image,
  LocalImage? preview,
  AuthorizedImages? images,
  String? title,
}) {
  final provider = avatarProvider(
    image: image,
    preview: preview,
    images: images,
  );
  if (provider == null) return null;

  return PageRouteBuilder<void>(
    // Over the page rather than instead of it: the fade reads as the picture
    // opening out of what is underneath.
    opaque: false,
    barrierColor: Colors.black,
    fullscreenDialog: true,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AvatarViewer(provider: provider, title: title),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _AvatarViewer extends StatelessWidget {
  const _AvatarViewer({required this.provider, this.title});

  final ImageProvider provider;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The route's own barrier is the background, so the picture sits on black
      // whatever the app's theme is — a photo is judged against neutral, not
      // against a surface colour.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tapping anywhere closes it, the way every photo viewer does.
              // Pinch and drag belong to the InteractiveViewer and never reach
              // this.
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const _ViewerMessage('This image could not be loaded.'),
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) =>
                            wasSynchronouslyLoaded || frame != null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  if (title case final text?)
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}
