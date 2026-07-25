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

import '../../helpers/lobby_fixtures.dart';

class _MockLobbyRepository extends Mock implements LobbyRepository {}

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

  setUp(() => repository = _MockLobbyRepository());

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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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
      build: () => LobbiesBloc(repository: repository),
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

  group('LobbyFeedCleared', () {
    blocTest<LobbiesBloc, LobbyFeedState>(
      'drops everything so the next session starts empty',
      build: () => LobbiesBloc(repository: repository),
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
      build: () => MyLobbiesBloc(repository: repository),
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
