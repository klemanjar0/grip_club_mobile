import 'package:flutter/material.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/authorized_images.dart';

/// How an avatar is masked. Round for people, rounded-square for lobbies.
enum AvatarShape { circle, rounded }

/// Resolves what an entity should show into something loadable, or `null` when
/// there is no image at all.
///
/// A freshly picked [preview] beats the stored [image]: a form has to show what
/// was just chosen, not what the server still has. Shared with the fullscreen
/// viewer so a tap opens the same picture the thumbnail was showing.
ImageProvider? avatarProvider({
  RemoteImage? image,
  LocalImage? preview,
  AuthorizedImages? images,
}) {
  if (preview case final picked?) return MemoryImage(picked.bytes);
  if (image case final stored?) {
    return (images ?? getIt<AuthorizedImages>()).provider(stored);
  }

  return null;
}

/// An entity's image, with a placeholder for when there is none.
///
/// Takes either a stored [image] or a freshly picked [preview]; the preview
/// wins, so a form can show what was just chosen before it has been uploaded.
/// When both are absent — or the download fails — it falls back to [icon] on a
/// neutral surface, which is what most lobbies and most profiles will show.
///
/// Comes in two shapes because avatars are used two ways: square at a fixed
/// [AvatarImage.new] size in lists and forms, and as a full-width
/// [AvatarImage.banner] at the top of a page.
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    required double this.size,
    this.image,
    this.preview,
    this.shape = AvatarShape.circle,
    this.icon = Icons.person_outline,
    this.images,
    super.key,
  }) : aspectRatio = null;

  /// As wide as its parent, at [aspectRatio]. Always rounded — a full-width
  /// circle is not a thing.
  const AvatarImage.banner({
    this.aspectRatio = 16 / 9,
    this.image,
    this.preview,
    this.icon = Icons.person_outline,
    this.images,
    super.key,
  }) : size = null,
       shape = AvatarShape.rounded;

  /// Side length, for the square form. `null` on a banner.
  final double? size;

  /// Width over height, for the banner form. `null` on a square.
  final double? aspectRatio;

  /// The stored image. `null` when the entity has none.
  final RemoteImage? image;

  /// A pick that has not been uploaded yet. Shown instead of [image].
  final LocalImage? preview;

  final AvatarShape shape;
  final IconData icon;

  /// Supplies the bearer token the image endpoint needs. Resolved from the
  /// injector by default; passed in by tests, which have no session.
  final AuthorizedImages? images;

  /// Scaled off the square's own size so the rounding looks the same at 56 and
  /// at 96; a banner is too big for that to hold and gets a fixed radius.
  BorderRadius get radius => switch ((shape, size)) {
    (AvatarShape.circle, final side?) => BorderRadius.circular(side),
    (_, final side?) => BorderRadius.circular(side / 6),
    _ => BorderRadius.circular(16),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final framed = ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: _content(colors),
      ),
    );

    return size == null
        ? AspectRatio(aspectRatio: aspectRatio!, child: framed)
        : SizedBox.square(dimension: size, child: framed);
  }

  Widget _content(ColorScheme colors) {
    final placeholder = _Placeholder(
      icon: icon,
      color: colors.onSurfaceVariant,
    );

    final provider = avatarProvider(
      image: image,
      preview: preview,
      images: images,
    );
    if (provider == null) return placeholder;

    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // A broken or expired image is not worth an error state of its own —
      // the entity is still perfectly usable without it.
      errorBuilder: (context, error, stackTrace) => placeholder,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : placeholder,
    );
  }
}

/// Fills whatever box it is given, so it works for both shapes.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Icon(
          icon,
          size: constraints.biggest.shortestSide * 0.4,
          color: color,
        ),
      ),
    );
  }
}
