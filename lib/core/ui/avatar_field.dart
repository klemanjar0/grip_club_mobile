import 'package:flutter/material.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/photo_picker.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/network/authorized_images.dart';
import 'package:grip_club_mobile/core/ui/avatar_image.dart';
import 'package:grip_club_mobile/core/ui/avatar_viewer.dart';

/// The one way an image gets attached to anything in this app.
///
/// A controlled widget: it renders [selection] on top of the stored [current]
/// and reports every change through [onChanged], holding no state of its own.
/// That is what lets it serve both flows without knowing which it is in —
/// a form keeps the selection until the user saves (lobbies), while a page that
/// saves on the spot turns each change straight into a request (profile) and
/// keeps passing [AvatarSelection.unchanged].
///
/// Picking and validating happen here; uploading does not. What comes out is a
/// [LocalImage] that `AvatarUploader` sends when the surrounding save runs, so
/// a user who backs out of a form never leaves a file behind.
class AvatarField extends StatelessWidget {
  const AvatarField({
    required this.selection,
    required this.onChanged,
    this.current,
    this.label,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.isBusy = false,
    this.size = 88,
    this.shape = AvatarShape.circle,
    this.icon = Icons.person_outline,
    this.emptyLabel = 'Add photo',
    this.picker,
    this.images,
    super.key,
  });

  /// What the user has done so far. [AvatarSelection.unchanged] renders
  /// [current].
  final AvatarSelection selection;
  final ValueChanged<AvatarSelection> onChanged;

  /// The image the entity already has, if any.
  final RemoteImage? current;

  final String? label;
  final String? helperText;
  final String? errorText;

  final bool enabled;

  /// An upload or a save is in flight: the field is held shut and shows it.
  final bool isBusy;

  final double size;
  final AvatarShape shape;
  final IconData icon;

  /// Call to action when there is no image yet.
  final String emptyLabel;

  /// Both resolved from the injector by default; passed in by tests, which have
  /// neither platform channels nor a session.
  final PhotoPicker? picker;
  final AuthorizedImages? images;

  /// A cleared selection hides [current] even though the server still has it —
  /// the removal only lands when the surrounding save runs.
  LocalImage? get _preview => switch (selection) {
    AvatarPicked(:final image) => image,
    _ => null,
  };

  RemoteImage? get _stored => selection is AvatarCleared ? null : current;

  bool get _hasImage => _preview != null || _stored != null;

  Future<void> _choose(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Captured up front: both are needed after the sheet has been awaited, and
    // by then this context is on the far side of an async gap.
    final navigator = Navigator.of(context, rootNavigator: true);

    final choice = await showModalBottomSheet<_SheetChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Looking at the picture is the one thing here that changes
            // nothing, so it goes first and is only offered when there is one.
            if (_hasImage)
              ListTile(
                leading: const Icon(Icons.zoom_out_map),
                title: const Text('View photo'),
                onTap: () => Navigator.of(sheetContext).pop(const _ViewPhoto()),
              ),
            for (final source in ImagePickSource.values)
              ListTile(
                leading: Icon(switch (source) {
                  ImagePickSource.gallery => Icons.photo_library_outlined,
                  ImagePickSource.files => Icons.folder_open_outlined,
                }),
                title: Text(source.label),
                onTap: () => Navigator.of(sheetContext).pop(_PickPhoto(source)),
              ),
            // Only offered when there is something to remove — clearing an
            // image that is not there would report a change that did not
            // happen, and on a lobby that means notifying every member.
            if (_hasImage)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _RemovePhoto()),
              ),
          ],
        ),
      ),
    );

    switch (choice) {
      // The sheet was dismissed.
      case null:
        return;

      case _ViewPhoto():
        // Shows whichever the field is showing: the fresh pick if there is
        // one, otherwise what the server has.
        final route = avatarViewerRoute(
          image: _stored,
          preview: _preview,
          images: images,
          title: label,
        );
        if (route != null) await navigator.push(route);

      case _RemovePhoto():
        onChanged(const AvatarSelection.cleared());

      case _PickPhoto(:final source):
        try {
          final image = await (picker ?? getIt<PhotoPicker>()).pick(source);
          // Backed out of the system sheet: nothing to report.
          if (image != null) onChanged(AvatarSelection.picked(image));
        } on LocalImageException catch (exception) {
          // Too big or not an image the API takes. Said here rather than after
          // a pointless upload, and it does not belong on the field's error
          // line — that one is reserved for what the server said about the
          // entity.
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(exception.message)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = enabled && !isBusy;

    final details = <Widget>[
      if (label case final text?) Text(text, style: theme.textTheme.titleSmall),
      TextButton(
        onPressed: isInteractive ? () => _choose(context) : null,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Text(_hasImage ? 'Change photo' : emptyLabel),
      ),
      if (errorText case final text?)
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        )
      else if (helperText case final text?)
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Thumbnail(
          preview: _preview,
          image: _stored,
          size: size,
          shape: shape,
          icon: icon,
          isBusy: isBusy,
          images: images,
          onTap: isInteractive ? () => _choose(context) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: details,
          ),
        ),
      ],
    );
  }
}

/// The image itself, tappable, with an edit badge so it reads as a control
/// rather than as decoration.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.preview,
    required this.image,
    required this.size,
    required this.shape,
    required this.icon,
    required this.isBusy,
    required this.images,
    required this.onTap,
  });

  final LocalImage? preview;
  final RemoteImage? image;
  final double size;
  final AvatarShape shape;
  final IconData icon;
  final bool isBusy;
  final AuthorizedImages? images;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Change photo',
      child: InkWell(
        onTap: onTap,
        customBorder: shape == AvatarShape.circle
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size / 6),
              ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AvatarImage(
              size: size,
              image: image,
              preview: preview,
              shape: shape,
              icon: icon,
              images: images,
            ),
            if (isBusy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.scrim.withValues(alpha: 0.4),
                    shape: shape == AvatarShape.circle
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: shape == AvatarShape.circle
                        ? null
                        : BorderRadius.circular(size / 6),
                  ),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 14,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What came back from the sheet.
sealed class _SheetChoice {
  const _SheetChoice();
}

final class _ViewPhoto extends _SheetChoice {
  const _ViewPhoto();
}

final class _RemovePhoto extends _SheetChoice {
  const _RemovePhoto();
}

final class _PickPhoto extends _SheetChoice {
  const _PickPhoto(this.source);

  final ImagePickSource source;
}
