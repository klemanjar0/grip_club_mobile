import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/ui/avatar_viewer.dart';

import '../../helpers/avatar_fixtures.dart';

void main() {
  /// A page with one button that opens the viewer, so the test drives it the
  /// way a user would rather than pushing the route by hand.
  Future<void> pumpOpener(
    WidgetTester tester, {
    bool withImage = true,
    String? title,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAvatarViewer(
              context,
              image: withImage ? remoteImage() : null,
              images: stubbedImages(),
              title: title,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  /// Pumps past the fade rather than settling: an image that has not decoded
  /// yet shows a spinner, and `pumpAndSettle` waits for that forever.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('opens the picture over the page it was tapped from', (
    tester,
  ) async {
    await pumpOpener(tester, title: 'Thursday night climb');
    await open(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Thursday night climb'), findsOneWidget);
    // The page underneath is still there — the viewer sits over it.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('closes on a tap anywhere', (tester) async {
    await pumpOpener(tester);
    await open(tester);

    await tester.tap(find.byType(InteractiveViewer));
    await settle(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('closes from the close button', (tester) async {
    await pumpOpener(tester);
    await open(tester);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('does nothing when there is no image to show', (tester) async {
    // Callers wire this up without guarding first, so an entity with no
    // picture must not open an empty black screen.
    await pumpOpener(tester, withImage: false);
    await open(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  test('has no route to push without an image', () {
    expect(avatarViewerRoute(images: stubbedImages()), isNull);
  });
}
