import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/view/edit_lobby_page.dart';

import '../../helpers/dashboard_harness.dart';
import '../../helpers/lobby_fixtures.dart';

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';

/// Named away from the form's own placeholder text, which is in the tree even
/// while the field has a value.
final _stored = Lobby.fromJson(
  lobbyJson(
    name: 'Morning session',
    role: 'admin',
    membershipStatus: 'approved',
    canJoin: false,
    address: '12 Khreshchatyk',
    chatLink: 'https://chat.example/abc',
  ),
);

void main() {
  late DashboardMocks mocks;

  setUp(() {
    // The whole form is taller than the default 800x600 test surface, and the
    // submit button sits at the bottom of it.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          ..physicalSize = const Size(1000, 2400)
          ..devicePixelRatio = 1;
    addTearDown(() {
      view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    mocks = registerDashboardStubs();
    when(
      () => mocks.lobbies.update(
        any(),
        name: any(named: 'name'),
        country: any(named: 'country'),
        city: any(named: 'city'),
        eventTime: any(named: 'eventTime'),
        visibility: any(named: 'visibility'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        chatLink: any(named: 'chatLink'),
      ),
    ).thenAnswer((_) async => _stored);
  });

  tearDown(() async => getIt.reset());

  late GoRouter router;

  /// Pushes the page onto a placeholder route through a real router: the page
  /// pops with `context.pop`, and saving needs somewhere to land for the
  /// confirmation to survive.
  Future<void> pumpEdit(WidgetTester tester, {Lobby? initialLobby}) async {
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (context, state) => EditLobbyPage(
            lobbyId: _lobbyId,
            initialLobby: initialLobby ?? _stored,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens prefilled with the lobby as it stands', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Morning session'), findsOneWidget);
    expect(find.text('Kyiv'), findsOneWidget);
    // Admins see the address and chat link, so they are editable here.
    expect(find.text('12 Khreshchatyk'), findsOneWidget);
    expect(find.text('https://chat.example/abc'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('sends just the edited field', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Morning session'),
      'Friday night climb',
    );
    await save(tester);

    verify(
      () => mocks.lobbies.update(
        _lobbyId,
        name: 'Friday night climb',
        country: null,
        city: null,
        eventTime: null,
        visibility: null,
        description: null,
        address: null,
        chatLink: null,
      ),
    ).called(1);
    expect(find.text('Changes saved.'), findsOneWidget);
  });

  testWidgets('clearing a field asks the server to erase it', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '12 Khreshchatyk'),
      '',
    );
    await save(tester);

    verify(
      () => mocks.lobbies.update(
        _lobbyId,
        name: null,
        country: null,
        city: null,
        eventTime: null,
        visibility: null,
        description: null,
        address: const Optional<String>.clear(),
        chatLink: null,
      ),
    ).called(1);
  });

  testWidgets('saving an untouched form never reaches the API', (tester) async {
    await pumpEdit(tester);

    await save(tester);

    // Every approved member would be notified of a change that did not happen.
    verifyNever(
      () => mocks.lobbies.update(
        any(),
        name: any(named: 'name'),
        country: any(named: 'country'),
        city: any(named: 'city'),
        eventTime: any(named: 'eventTime'),
        visibility: any(named: 'visibility'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        chatLink: any(named: 'chatLink'),
      ),
    );
    expect(find.text('Nothing to save.'), findsOneWidget);
  });

  testWidgets('a past event stays editable as long as the time is left alone', (
    tester,
  ) async {
    final past = Lobby.fromJson(
      lobbyJson(
        name: 'Morning session',
        role: 'admin',
        canJoin: false,
        eventTime: '2020-08-24T18:30:00Z',
      ),
    );

    await pumpEdit(tester, initialLobby: past);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Morning session'),
      'Renamed after the fact',
    );
    await save(tester);

    // The API only rejects an event_time it is asked to change, so leaving the
    // picker untouched must not trip the "must be in the future" rule.
    expect(find.text('Pick a time in the future'), findsNothing);
    verify(
      () => mocks.lobbies.update(
        _lobbyId,
        name: 'Renamed after the fact',
        country: null,
        city: null,
        eventTime: null,
        visibility: null,
        description: null,
        address: null,
        chatLink: null,
      ),
    ).called(1);
  });

  testWidgets('a lobby it cannot load offers a retry', (tester) async {
    when(
      () => mocks.lobbies.byId(_lobbyId),
    ).thenThrow(const ApiException('No internet connection.'));

    await tester.pumpWidget(
      const MaterialApp(home: EditLobbyPage(lobbyId: _lobbyId)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
