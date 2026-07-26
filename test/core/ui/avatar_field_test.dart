import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/images/photo_picker.dart';
import 'package:grip_club_mobile/core/images/remote_image.dart';
import 'package:grip_club_mobile/core/ui/avatar_field.dart';

import '../../helpers/avatar_fixtures.dart';

void main() {
  late MockPhotoPicker picker;
  late List<AvatarSelection> reported;

  setUpAll(() => registerFallbackValue(ImagePickSource.gallery));

  setUp(() {
    picker = MockPhotoPicker();
    reported = <AvatarSelection>[];
  });

  Future<void> pump(
    WidgetTester tester, {
    AvatarSelection selection = const AvatarSelection.unchanged(),
    RemoteImage? current,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AvatarField(
          selection: selection,
          current: current,
          picker: picker,
          images: stubbedImages(),
          onChanged: reported.add,
        ),
      ),
    ),
  );

  /// Opens the sheet the way a user does — by tapping the image itself.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
  }

  testWidgets('reports the picked image without uploading it', (tester) async {
    final image = testImage();
    when(() => picker.pick(any())).thenAnswer((_) async => image);

    await pump(tester);
    await openSheet(tester);
    await tester.tap(find.text(ImagePickSource.gallery.label));
    await tester.pumpAndSettle();

    expect(reported.single, AvatarSelection.picked(image));
    verify(() => picker.pick(ImagePickSource.gallery)).called(1);
  });

  testWidgets('offers both places an image can come from', (tester) async {
    await pump(tester);
    await openSheet(tester);

    expect(find.text(ImagePickSource.gallery.label), findsOneWidget);
    expect(find.text(ImagePickSource.files.label), findsOneWidget);
  });

  testWidgets('says nothing happened when the picker is dismissed', (
    tester,
  ) async {
    when(() => picker.pick(any())).thenAnswer((_) async => null);

    await pump(tester);
    await openSheet(tester);
    await tester.tap(find.text(ImagePickSource.files.label));
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
  });

  testWidgets('shows why a file was refused instead of reporting it', (
    tester,
  ) async {
    when(
      () => picker.pick(any()),
    ).thenThrow(const LocalImageException('Images have to be under 5 MB.'));

    await pump(tester);
    await openSheet(tester);
    await tester.tap(find.text(ImagePickSource.gallery.label));
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
    expect(find.text('Images have to be under 5 MB.'), findsOneWidget);
  });

  group('viewing', () {
    testWidgets('opens the picture full screen without changing it', (
      tester,
    ) async {
      await pump(tester, current: remoteImage());
      await openSheet(tester);
      await tester.tap(find.text('View photo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(reported, isEmpty);
    });

    testWidgets('shows the fresh pick rather than the stored image', (
      tester,
    ) async {
      // Nothing has been uploaded yet, so the stored image is not what the
      // field — or the viewer — should be showing.
      await pump(
        tester,
        current: remoteImage(),
        selection: AvatarSelection.picked(testImage()),
      );
      await openSheet(tester);
      await tester.tap(find.text('View photo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final viewer = tester.widget<Image>(
        find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.byType(Image),
        ),
      );
      expect(viewer.image, isA<MemoryImage>());
    });

    testWidgets('is not offered when there is no picture', (tester) async {
      await pump(tester);
      await openSheet(tester);

      expect(find.text('View photo'), findsNothing);
    });
  });

  group('removing', () {
    testWidgets('is offered once there is an image to remove', (tester) async {
      await pump(tester, current: remoteImage());
      await openSheet(tester);
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(reported.single, const AvatarSelection.cleared());
    });

    testWidgets('is not offered when there is nothing there', (tester) async {
      // Clearing an image that is not set would report a change that did not
      // happen — on a lobby, that means notifying every member.
      await pump(tester);
      await openSheet(tester);

      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('is not offered again once the image is cleared', (
      tester,
    ) async {
      await pump(
        tester,
        current: remoteImage(),
        selection: const AvatarSelection.cleared(),
      );
      await openSheet(tester);

      expect(find.text('Remove photo'), findsNothing);
    });
  });
}
