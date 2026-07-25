import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/create_lobby_bloc.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby_draft.dart';

import '../../helpers/lobby_fixtures.dart';

class _MockLobbyRepository extends Mock implements LobbyRepository {}

final _created = lobby(role: 'admin', canJoin: false);

final _draft = LobbyDraft.fromInput(
  name: 'Thursday night climb',
  country: 'Ukraine',
  city: 'Kyiv',
  eventTime: DateTime.utc(2099, 8, 24, 18, 30),
  visibility: LobbyVisibility.public,
);

final _submitted = CreateLobbySubmitted(_draft);

void main() {
  late LobbyRepository repository;

  // `any()` needs a sample value for every non-primitive argument type.
  setUpAll(() => registerFallbackValue(_draft));

  setUp(() => repository = _MockLobbyRepository());

  void stubCreate({Object? throws, Lobby? returns}) {
    final call = when(() => repository.create(any()));

    if (throws != null) {
      call.thenThrow(throws);
    } else {
      call.thenAnswer((_) async => returns!);
    }
  }

  blocTest<CreateLobbyBloc, CreateLobbyState>(
    'emits submitting then the created lobby',
    setUp: () => stubCreate(returns: _created),
    build: () => CreateLobbyBloc(repository: repository),
    act: (bloc) => bloc.add(_submitted),
    expect: () => [
      const CreateLobbyState.submitting(),
      CreateLobbyState.success(_created),
    ],
    verify: (_) => verify(() => repository.create(_draft)).called(1),
  );

  blocTest<CreateLobbyBloc, CreateLobbyState>(
    'hands validation_failed details back for the form to place',
    setUp: () => stubCreate(
      throws: const ApiException(
        'The request payload is invalid.',
        statusCode: 400,
        code: 'validation_failed',
        fieldErrors: <String, String>{'event_time': 'must be in the future'},
      ),
    ),
    build: () => CreateLobbyBloc(repository: repository),
    act: (bloc) => bloc.add(_submitted),
    expect: () => const [
      CreateLobbyState.submitting(),
      CreateLobbyState.failure(
        errorMessage: 'The request payload is invalid.',
        fieldErrors: <String, String>{'event_time': 'must be in the future'},
      ),
    ],
  );

  blocTest<CreateLobbyBloc, CreateLobbyState>(
    'reports a transport failure with no field errors',
    setUp: () =>
        stubCreate(throws: const ApiException('No internet connection.')),
    build: () => CreateLobbyBloc(repository: repository),
    act: (bloc) => bloc.add(_submitted),
    expect: () => const [
      CreateLobbyState.submitting(),
      CreateLobbyState.failure(errorMessage: 'No internet connection.'),
    ],
  );
}
