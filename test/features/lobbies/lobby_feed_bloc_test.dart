import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_state.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';
import 'package:grip_club_mobile/features/members/domain/membership.dart';

import '../../helpers/lobby_fixtures.dart';

class _MockLobbyRepository extends Mock implements LobbyRepository {}

class _MockMembershipRepository extends Mock implements MembershipRepository {}

final _first = lobby(name: 'Morning session');
final _second = lobby(
  id: 'a1b2c3d4-0000-4000-8000-000000000002',
  name: 'Evening session',
);

PageEnvelope<Lobby> _page(
  List<Lobby> items, {
  int page = 0,
  bool hasNext = false,
}) => PageEnvelope<Lobby>(
  items: items,
  page: page,
  pageSize: 10,
  hasNext: hasNext,
);

void main() {
  late LobbyRepository repository;
  late MembershipRepository memberships;

  setUp(() {
    repository = _MockLobbyRepository();
    memberships = _MockMembershipRepository();
  });

  void stubBrowse(PageEnvelope<Lobby> page) => when(
    () => repository.browse(
      city: any(named: 'city'),
      within: any(named: 'within'),
      page: any(named: 'page'),
    ),
  ).thenAnswer((_) async => page);

  group('LobbyFeedRequested', () {
    blocTest<LobbiesBloc, LobbyFeedState>(
      'loads the first page with no filters, so the server uses saved defaults',
      setUp: () => stubBrowse(_page([_first], hasNext: true)),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      act: (bloc) => bloc.add(const LobbyFeedRequested()),
      expect: () => [
        const LobbyFeedState(status: LobbyFeedStatus.loading),
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first],
          hasNext: true,
        ),
      ],
      verify: (_) => verify(
        () => repository.browse(city: null, within: null, page: 0),
      ).called(1),
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'does not refetch a feed that is already loaded',
      setUp: () => stubBrowse(_page([_first])),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () =>
          LobbyFeedState(status: LobbyFeedStatus.ready, lobbies: [_first]),
      act: (bloc) => bloc.add(const LobbyFeedRequested()),
      expect: () => <LobbyFeedState>[],
      verify: (_) => verifyNever(
        () => repository.browse(
          city: any(named: 'city'),
          within: any(named: 'within'),
          page: any(named: 'page'),
        ),
      ),
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'reports a failed first load',
      setUp: () => when(
        () => repository.browse(
          city: any(named: 'city'),
          within: any(named: 'within'),
          page: any(named: 'page'),
        ),
      ).thenThrow(const ApiException('No internet connection.')),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      act: (bloc) => bloc.add(const LobbyFeedRequested()),
      expect: () => const [
        LobbyFeedState(status: LobbyFeedStatus.loading),
        LobbyFeedState(
          status: LobbyFeedStatus.failure,
          errorMessage: 'No internet connection.',
        ),
      ],
    );
  });

  group('LobbyFeedNextPageRequested', () {
    blocTest<LobbiesBloc, LobbyFeedState>(
      'appends the next page',
      setUp: () => stubBrowse(_page([_second], page: 1)),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first],
        hasNext: true,
      ),
      act: (bloc) => bloc.add(const LobbyFeedNextPageRequested()),
      expect: () => [
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first],
          hasNext: true,
          isLoadingMore: true,
        ),
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first, _second],
          page: 1,
        ),
      ],
      verify: (_) => verify(
        () => repository.browse(city: null, within: null, page: 1),
      ).called(1),
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'ignores the request when there is no next page',
      setUp: () => stubBrowse(_page([_second], page: 1)),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () =>
          LobbyFeedState(status: LobbyFeedStatus.ready, lobbies: [_first]),
      // The scroll listener fires on every frame near the bottom; dropping the
      // extra ones here is what keeps that from stampeding the API.
      act: (bloc) => bloc
        ..add(const LobbyFeedNextPageRequested())
        ..add(const LobbyFeedNextPageRequested()),
      expect: () => <LobbyFeedState>[],
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'keeps the loaded pages when the next one fails',
      setUp: () => when(
        () => repository.browse(
          city: any(named: 'city'),
          within: any(named: 'within'),
          page: any(named: 'page'),
        ),
      ).thenThrow(const ApiException('The server took too long to respond.')),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first],
        hasNext: true,
      ),
      act: (bloc) => bloc.add(const LobbyFeedNextPageRequested()),
      skip: 1,
      expect: () => [
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first],
          hasNext: true,
          errorMessage: 'The server took too long to respond.',
        ),
      ],
    );
  });

  group('LobbyFeedFilterChanged', () {
    blocTest<LobbiesBloc, LobbyFeedState>(
      'sends the new filters and resets to page 0',
      setUp: () => stubBrowse(_page([_second])),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first],
        page: 3,
        hasNext: true,
      ),
      act: (bloc) =>
          bloc.add(const LobbyFeedFilterChanged(city: '', within: 'week')),
      verify: (_) => verify(
        () => repository.browse(city: '', within: 'week', page: 0),
      ).called(1),
      expect: () => [
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first],
          page: 3,
          hasNext: true,
          city: '',
          within: 'week',
        ),
        LobbyFeedState(
          status: LobbyFeedStatus.loading,
          lobbies: [_first],
          page: 3,
          hasNext: true,
          city: '',
          within: 'week',
        ),
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_second],
          city: '',
          within: 'week',
        ),
      ],
    );
  });

  group('LobbyFeedJoinRequested', () {
    Membership membershipOf(MembershipStatus status) => Membership(
      lobbyId: _first.id,
      userId: 'u1',
      status: status,
      joinedAt: DateTime.utc(2026, 8, 24),
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'a public lobby is joined and the card becomes a member card',
      setUp: () => when(
        () => memberships.join(_first.id),
      ).thenAnswer((_) async => membershipOf(MembershipStatus.approved)),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first, _second],
      ),
      act: (bloc) => bloc.add(LobbyFeedJoinRequested(_first.id)),
      skip: 1,
      verify: (bloc) {
        final joined = bloc.state.lobbies.first;
        expect(joined.viewer.role, ViewerRole.member);
        expect(joined.viewer.canJoin, isFalse);
        // The count moves too: an approval adds the caller.
        expect(joined.approvedCount, _first.approvedCount + 1);
        expect(bloc.state.joinOutcome, LobbyJoinOutcome.joined);
        expect(bloc.state.joiningLobbyId, isNull);
        // Only the joined card changes; the rest of the page is untouched.
        expect(bloc.state.lobbies.last, _second);
        // No refetch — a reload would throw away the reader's scroll position.
        verifyNever(
          () => repository.browse(
            city: any(named: 'city'),
            within: any(named: 'within'),
            page: any(named: 'page'),
          ),
        );
      },
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'a private lobby only leaves a pending request',
      setUp: () => when(
        () => memberships.join(_first.id),
      ).thenAnswer((_) async => membershipOf(MembershipStatus.pending)),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () =>
          LobbyFeedState(status: LobbyFeedStatus.ready, lobbies: [_first]),
      act: (bloc) => bloc.add(LobbyFeedJoinRequested(_first.id)),
      skip: 1,
      verify: (bloc) {
        final requested = bloc.state.lobbies.single;
        expect(requested.viewer.role, ViewerRole.pending);
        expect(requested.viewer.canJoin, isFalse);
        // Pending is not approved: the head count stays where it was.
        expect(requested.approvedCount, _first.approvedCount);
        expect(bloc.state.joinOutcome, LobbyJoinOutcome.requestSent);
      },
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'reports a rejected join and leaves the card alone',
      setUp: () => when(() => memberships.join(_first.id)).thenThrow(
        const ApiException(
          'You are banned from this lobby.',
          statusCode: 403,
          code: 'banned',
        ),
      ),
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () =>
          LobbyFeedState(status: LobbyFeedStatus.ready, lobbies: [_first]),
      act: (bloc) => bloc.add(LobbyFeedJoinRequested(_first.id)),
      skip: 1,
      expect: () => [
        LobbyFeedState(
          status: LobbyFeedStatus.ready,
          lobbies: [_first],
          errorMessage: 'You are banned from this lobby.',
        ),
      ],
    );

    blocTest<LobbiesBloc, LobbyFeedState>(
      'ignores a second tap while a join is in flight',
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first],
        joiningLobbyId: _first.id,
      ),
      act: (bloc) => bloc.add(LobbyFeedJoinRequested(_first.id)),
      expect: () => <LobbyFeedState>[],
      verify: (_) => verifyNever(() => memberships.join(any())),
    );
  });

  group('LobbyFeedCleared', () {
    blocTest<LobbiesBloc, LobbyFeedState>(
      'drops everything so the next session starts empty',
      build: () =>
          LobbiesBloc(repository: repository, memberships: memberships),
      seed: () => LobbyFeedState(
        status: LobbyFeedStatus.ready,
        lobbies: [_first],
        city: 'Kyiv',
      ),
      act: (bloc) => bloc.add(const LobbyFeedCleared()),
      expect: () => const [LobbyFeedState()],
    );
  });

  group('MyLobbiesBloc', () {
    blocTest<MyLobbiesBloc, LobbyFeedState>(
      'reads /me/lobbies and ignores filters',
      setUp: () => when(
        () => repository.myLobbies(page: any(named: 'page')),
      ).thenAnswer((_) async => _page([_first])),
      build: () =>
          MyLobbiesBloc(repository: repository, memberships: memberships),
      act: (bloc) => bloc.add(const LobbyFeedRequested()),
      verify: (_) {
        verify(() => repository.myLobbies(page: 0)).called(1);
        verifyNever(
          () => repository.browse(
            city: any(named: 'city'),
            within: any(named: 'within'),
            page: any(named: 'page'),
          ),
        );
      },
      expect: () => [
        const LobbyFeedState(status: LobbyFeedStatus.loading),
        LobbyFeedState(status: LobbyFeedStatus.ready, lobbies: [_first]),
      ],
    );
  });
}
