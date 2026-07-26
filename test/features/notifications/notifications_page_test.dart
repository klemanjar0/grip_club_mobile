import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/app/di/injector.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';
import 'package:grip_club_mobile/features/notifications/domain/app_notification.dart';
import 'package:grip_club_mobile/features/notifications/view/notifications_page.dart';

import '../../helpers/dashboard_harness.dart';

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';
const _userId = 'u0000000-0000-4000-8000-000000000001';

AppNotification _notification({
  String type = 'join_request',
  String? lobbyId = _lobbyId,
  bool withActor = true,
  Map<String, dynamic>? actor,
}) => AppNotification.fromJson(<String, dynamic>{
  'id': 'n1',
  'type': type,
  'read': false,
  'created_at': '2026-08-24T18:30:00Z',
  'lobby': <String, dynamic>{'id': lobbyId, 'name': 'Thursday night climb'},
  'actor': withActor
      ? actor ?? <String, dynamic>{'id': _userId, 'display_name': 'rider'}
      : null,
});

final _approved = Membership(
  lobbyId: _lobbyId,
  userId: _userId,
  status: MembershipStatus.approved,
  joinedAt: DateTime.utc(2026, 8, 24),
);

void main() {
  late DashboardMocks mocks;

  setUp(() {
    mocks = registerDashboardStubs();
    when(() => mocks.notifications.markRead(any())).thenAnswer((_) async {});
  });

  tearDown(() async => getIt.reset());

  void feedWith(AppNotification notification) {
    when(
      () => mocks.notifications.feed(
        unreadOnly: any(named: 'unreadOnly'),
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) async => PageEnvelope<AppNotification>(
        items: [notification],
        page: 0,
        pageSize: 10,
        hasNext: false,
      ),
    );
  }

  /// The page itself needs no router for the sheet, but the fall-through to the
  /// lobby pushes a named route — so everything runs through a real one.
  Future<void> pumpFeed(WidgetTester tester) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/lobbies/:lobbyId',
          name: 'lobby-detail',
          builder: (context, state) =>
              const Scaffold(body: Text('the lobby page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> tapNotification(WidgetTester tester) async {
    await tester.tap(find.textContaining('asked to join'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a join request opens the verdict sheet, not the lobby', (
    tester,
  ) async {
    feedWith(_notification());

    await pumpFeed(tester);
    await tapNotification(tester);

    expect(find.text('rider'), findsOneWidget);
    expect(find.text('wants to join Thursday night climb'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    // The question is answered here, so the lobby is not pushed over it.
    expect(find.text('the lobby page'), findsNothing);
    // Opening it still marks it read.
    verify(() => mocks.notifications.markRead('n1')).called(1);
  });

  testWidgets('approving lets the applicant in and confirms it', (
    tester,
  ) async {
    feedWith(_notification());
    when(
      () => mocks.memberships.approve(_lobbyId, _userId),
    ).thenAnswer((_) async => _approved);

    await pumpFeed(tester);
    await tapNotification(tester);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    verify(() => mocks.memberships.approve(_lobbyId, _userId)).called(1);
    expect(find.text('rider is in.'), findsOneWidget);
    // The sheet is gone.
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('declining turns the request away and confirms it', (
    tester,
  ) async {
    feedWith(_notification());
    when(
      () => mocks.memberships.reject(_lobbyId, _userId),
    ).thenAnswer((_) async {});

    await pumpFeed(tester);
    await tapNotification(tester);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    verify(() => mocks.memberships.reject(_lobbyId, _userId)).called(1);
    expect(find.text('Request from rider declined.'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('a request that is already gone says so instead of failing', (
    tester,
  ) async {
    feedWith(_notification());
    when(() => mocks.memberships.approve(_lobbyId, _userId)).thenThrow(
      const ApiException(
        'No such membership request.',
        statusCode: 404,
        code: 'member_not_found',
      ),
    );

    await pumpFeed(tester);
    await tapNotification(tester);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer waiting'), findsOneWidget);
    // Nothing left to decide, so the verdict buttons are replaced.
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Decline'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Closing is not a verdict — no confirmation is claimed.
    expect(find.text('rider is in.'), findsNothing);
  });

  testWidgets('a failure keeps the sheet open with the reason', (tester) async {
    feedWith(_notification());
    when(() => mocks.memberships.approve(_lobbyId, _userId)).thenThrow(
      const ApiException(
        'Only the organizer can do that.',
        statusCode: 403,
        code: 'admin_only',
      ),
    );

    await pumpFeed(tester);
    await tapNotification(tester);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Only the organizer can do that.'), findsOneWidget);
    // Still answerable — a 403 here may be worth retrying after a refresh.
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('a join request with no actor left falls back to the lobby', (
    tester,
  ) async {
    // The applicant deleted their account, so there is nobody to approve.
    feedWith(_notification(withActor: false));

    await pumpFeed(tester);
    await tester.tap(find.textContaining('asked to join'));
    await tester.pumpAndSettle();

    expect(find.text('the lobby page'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('an actor with no id is treated the same way', (tester) async {
    // A half-empty actor block would otherwise build `/members//approve`.
    feedWith(_notification(actor: <String, dynamic>{'display_name': ''}));

    await pumpFeed(tester);
    await tester.tap(find.textContaining('asked to join'));
    await tester.pumpAndSettle();

    expect(find.text('the lobby page'), findsOneWidget);
    verifyNever(() => mocks.memberships.approve(any(), any()));
  });

  testWidgets('every other notification still opens its lobby', (tester) async {
    feedWith(_notification(type: 'lobby_updated'));

    await pumpFeed(tester);
    await tester.tap(find.textContaining('was updated'));
    await tester.pumpAndSettle();

    expect(find.text('the lobby page'), findsOneWidget);
  });
}
