import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/edit_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

import '../../helpers/avatar_fixtures.dart';
import '../../helpers/lobby_fixtures.dart';

class _MockLobbyRepository extends Mock implements LobbyRepository {}

const _lobbyId = 'a1b2c3d4-0000-4000-8000-000000000001';

/// The admin's own lobby, so the address and chat link are visible and
/// therefore editable.
final _stored = Lobby.fromJson(
  lobbyJson(
    role: 'admin',
    membershipStatus: 'approved',
    canJoin: false,
    address: '12 Khreshchatyk',
    chatLink: 'https://chat.example/abc',
  ),
);

/// The form as it opens: exactly the stored lobby.
final _unchanged = LobbyDraft.of(_stored);

void main() {
  late LobbyRepository repository;
  late MockFileRepository files;

  setUpAll(() {
    registerFallbackValue(_unchanged);
    registerFallbackValue(testImage());
  });

  setUp(() {
    repository = _MockLobbyRepository();
    files = MockFileRepository();
    when(
      () => repository.update(
        any(),
        name: any(named: 'name'),
        country: any(named: 'country'),
        city: any(named: 'city'),
        eventTime: any(named: 'eventTime'),
        visibility: any(named: 'visibility'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        chatLink: any(named: 'chatLink'),
        avatarFileId: any(named: 'avatarFileId'),
      ),
    ).thenAnswer((_) async => _stored);
  });

  EditLobbyBloc build({Lobby? initialLobby = _dontCare}) => EditLobbyBloc(
    lobbyId: _lobbyId,
    repository: repository,
    avatars: avatarUploader(files),
    initialLobby: identical(initialLobby, _dontCare) ? _stored : initialLobby,
  );

  group('EditLobbyStarted', () {
    blocTest<EditLobbyBloc, EditLobbyState>(
      'skips the fetch when the lobby was handed over',
      build: build,
      act: (bloc) => bloc.add(const EditLobbyStarted()),
      expect: () => <EditLobbyState>[],
      verify: (_) => verifyNever(() => repository.byId(any())),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'fetches when opened cold',
      setUp: () => when(
        () => repository.byId(_lobbyId),
      ).thenAnswer((_) async => _stored),
      build: () => build(initialLobby: null),
      act: (bloc) => bloc.add(const EditLobbyStarted()),
      expect: () => [
        const EditLobbyState(isLoading: true),
        EditLobbyState(lobby: _stored),
      ],
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'reports a lobby it cannot load',
      setUp: () => when(
        () => repository.byId(_lobbyId),
      ).thenThrow(const ApiException('No internet connection.')),
      build: () => build(initialLobby: null),
      act: (bloc) => bloc.add(const EditLobbyStarted()),
      skip: 1,
      expect: () => const [
        EditLobbyState(errorMessage: 'No internet connection.'),
      ],
    );
  });

  group('EditLobbySubmitted', () {
    blocTest<EditLobbyBloc, EditLobbyState>(
      'sends only the field that changed',
      build: build,
      act: (bloc) => bloc.add(
        EditLobbySubmitted(
          LobbyDraft.fromInput(
            name: 'Friday night climb',
            country: _stored.country,
            city: _stored.city,
            eventTime: _stored.eventTime!,
            visibility: _stored.visibility,
            description: _stored.description,
            address: _stored.address,
            chatLink: _stored.chatLink,
          ),
        ),
      ),
      // Everything else is absent from the call, so a concurrent edit to those
      // fields survives.
      verify: (_) => verify(
        () => repository.update(
          _lobbyId,
          name: 'Friday night climb',
          country: null,
          city: null,
          eventTime: null,
          visibility: null,
          description: null,
          address: null,
          chatLink: null,
          avatarFileId: null,
        ),
      ).called(1),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'an emptied field is sent as an explicit clear, not as absent',
      build: build,
      act: (bloc) => bloc.add(
        EditLobbySubmitted(
          LobbyDraft.fromInput(
            name: _stored.name,
            country: _stored.country,
            city: _stored.city,
            eventTime: _stored.eventTime!,
            visibility: _stored.visibility,
            description: _stored.description,
            // The admin wiped the address field and left the chat link alone.
            address: '   ',
            chatLink: _stored.chatLink,
          ),
        ),
      ),
      verify: (_) => verify(
        () => repository.update(
          _lobbyId,
          name: null,
          country: null,
          city: null,
          eventTime: null,
          visibility: null,
          description: null,
          address: const Optional<String>.clear(),
          chatLink: null,
          avatarFileId: null,
        ),
      ).called(1),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'never calls the API when nothing was edited',
      build: build,
      act: (bloc) => bloc.add(EditLobbySubmitted(_unchanged)),
      // Saving anyway would notify every approved member of a change that did
      // not happen.
      verify: (_) => verifyNever(
        () => repository.update(
          any(),
          name: any(named: 'name'),
          country: any(named: 'country'),
          city: any(named: 'city'),
          eventTime: any(named: 'eventTime'),
          visibility: any(named: 'visibility'),
          description: any(named: 'description'),
          address: any(named: 'address'),
          chatLink: any(named: 'chatLink'),
          avatarFileId: any(named: 'avatarFileId'),
        ),
      ),
      expect: () => [EditLobbyState(lobby: _stored, savedLobby: _stored)],
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'reports the saved lobby so the page can hand it back',
      setUp: () {
        final renamed = Lobby.fromJson(
          lobbyJson(name: 'Friday night climb', role: 'admin', canJoin: false),
        );
        when(
          () => repository.update(
            any(),
            name: any(named: 'name'),
            country: any(named: 'country'),
            city: any(named: 'city'),
            eventTime: any(named: 'eventTime'),
            visibility: any(named: 'visibility'),
            description: any(named: 'description'),
            address: any(named: 'address'),
            chatLink: any(named: 'chatLink'),
            avatarFileId: any(named: 'avatarFileId'),
          ),
        ).thenAnswer((_) async => renamed);
      },
      build: build,
      act: (bloc) => bloc.add(
        EditLobbySubmitted(
          LobbyDraft.fromInput(
            name: 'Friday night climb',
            country: _stored.country,
            city: _stored.city,
            eventTime: _stored.eventTime!,
            visibility: _stored.visibility,
            description: _stored.description,
            address: _stored.address,
            chatLink: _stored.chatLink,
          ),
        ),
      ),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.savedLobby?.name, 'Friday night climb');
        expect(bloc.state.hasChanges, isTrue);
        expect(bloc.state.isSubmitting, isFalse);
      },
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'hands validation_failed back for the form to place',
      setUp: () =>
          when(
            () => repository.update(
              any(),
              name: any(named: 'name'),
              country: any(named: 'country'),
              city: any(named: 'city'),
              eventTime: any(named: 'eventTime'),
              visibility: any(named: 'visibility'),
              description: any(named: 'description'),
              address: any(named: 'address'),
              chatLink: any(named: 'chatLink'),
              avatarFileId: any(named: 'avatarFileId'),
            ),
          ).thenThrow(
            const ApiException(
              'The request payload is invalid.',
              statusCode: 400,
              code: 'validation_failed',
              fieldErrors: <String, String>{
                'event_time': 'must be in the future',
              },
            ),
          ),
      build: build,
      act: (bloc) => bloc.add(
        EditLobbySubmitted(
          LobbyDraft.fromInput(
            name: _stored.name,
            country: _stored.country,
            city: _stored.city,
            eventTime: DateTime.utc(2020),
            visibility: _stored.visibility,
            description: _stored.description,
            address: _stored.address,
            chatLink: _stored.chatLink,
          ),
        ),
      ),
      skip: 1,
      expect: () => [
        EditLobbyState(
          lobby: _stored,
          errorMessage: 'The request payload is invalid.',
          errorCode: 'validation_failed',
          fieldErrors: const <String, String>{
            'event_time': 'must be in the future',
          },
        ),
      ],
    );
  });

  group('the picture', () {
    /// The form as it opens, with a new image chosen and nothing else touched.
    LobbyDraft withNewPhoto() => LobbyDraft.fromInput(
      name: _stored.name,
      country: _stored.country,
      city: _stored.city,
      eventTime: _stored.eventTime!,
      visibility: _stored.visibility,
      description: _stored.description,
      address: _stored.address,
      chatLink: _stored.chatLink,
      avatar: AvatarSelection.picked(testImage()),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'is uploaded first, then attached by id',
      setUp: () => when(
        () => files.upload(any()),
      ).thenAnswer((_) async => remoteImage(id: 'uploaded-id')),
      build: build,
      act: (bloc) => bloc.add(EditLobbySubmitted(withNewPhoto())),
      verify: (_) => verify(
        () => repository.update(
          _lobbyId,
          name: null,
          country: null,
          city: null,
          eventTime: null,
          visibility: null,
          description: null,
          address: null,
          chatLink: null,
          avatarFileId: const Optional<String>('uploaded-id'),
        ),
      ).called(1),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'counts as a change on its own, so a photo-only edit still saves',
      setUp: () => when(
        () => files.upload(any()),
      ).thenAnswer((_) async => remoteImage(id: 'uploaded-id')),
      build: build,
      act: (bloc) => bloc.add(EditLobbySubmitted(withNewPhoto())),
      skip: 1,
      verify: (bloc) => expect(bloc.state.hasChanges, isTrue),
    );

    blocTest<EditLobbyBloc, EditLobbyState>(
      'removing sends an explicit null and uploads nothing',
      build: build,
      act: (bloc) => bloc.add(
        EditLobbySubmitted(
          LobbyDraft.fromInput(
            name: _stored.name,
            country: _stored.country,
            city: _stored.city,
            eventTime: _stored.eventTime!,
            visibility: _stored.visibility,
            description: _stored.description,
            address: _stored.address,
            chatLink: _stored.chatLink,
            avatar: const AvatarSelection.cleared(),
          ),
        ),
      ),
      verify: (_) {
        verifyNever(() => files.upload(any()));
        verify(
          () => repository.update(
            _lobbyId,
            name: null,
            country: null,
            city: null,
            eventTime: null,
            visibility: null,
            description: null,
            address: null,
            chatLink: null,
            avatarFileId: const Optional<String>.clear(),
          ),
        ).called(1);
      },
    );
  });
}

/// Sentinel: lets [build] tell "no argument" from an explicit `null`.
const Lobby _dontCare = Lobby(
  id: '',
  name: '',
  country: '',
  city: '',
  eventTime: null,
  visibility: LobbyVisibility.public,
  approvedCount: 0,
  creator: LobbyCreator(id: '', displayName: ''),
  viewer: LobbyViewer(role: ViewerRole.outsider, canJoin: false),
);
