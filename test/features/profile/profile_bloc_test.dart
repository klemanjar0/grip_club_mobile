import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/patch/optional.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/profile/bloc/profile_bloc.dart';
import 'package:grip_club_mobile/features/profile/data/user_repository.dart';

import '../../helpers/avatar_fixtures.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

final _saved = User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'climber',
  city: 'Lviv',
  timeFilter: 'week',
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

void main() {
  late UserRepository users;
  late AuthRepository auth;
  late MockFileRepository files;

  setUpAll(() => registerFallbackValue(testImage()));

  setUp(() {
    users = _MockUserRepository();
    auth = _MockAuthRepository();
    files = MockFileRepository();
  });

  ProfileBloc build() =>
      ProfileBloc(users: users, auth: auth, avatars: avatarUploader(files));

  group('ProfilePreferencesSubmitted', () {
    blocTest<ProfileBloc, ProfileState>(
      'reports the saved user so the app copy can be replaced',
      setUp: () => when(
        () => users.updatePreferences(
          displayName: any(named: 'displayName'),
          locale: any(named: 'locale'),
          timezone: any(named: 'timezone'),
          city: any(named: 'city'),
          timeFilter: any(named: 'timeFilter'),
        ),
      ).thenAnswer((_) async => _saved),
      build: build,
      act: (bloc) => bloc.add(
        const ProfilePreferencesSubmitted(
          displayName: 'climber',
          city: 'Lviv',
          timeFilter: 'week',
        ),
      ),
      expect: () => [
        const ProfileState(isSavingPreferences: true),
        ProfileState(
          updatedUser: _saved,
          outcome: ProfileOutcome.preferencesSaved,
        ),
      ],
      verify: (_) => verify(
        () => users.updatePreferences(
          displayName: 'climber',
          locale: null,
          timezone: null,
          city: 'Lviv',
          timeFilter: 'week',
        ),
      ).called(1),
    );

    blocTest<ProfileBloc, ProfileState>(
      'hands an unknown timezone back as a field error',
      setUp: () =>
          when(
            () => users.updatePreferences(
              displayName: any(named: 'displayName'),
              locale: any(named: 'locale'),
              timezone: any(named: 'timezone'),
              city: any(named: 'city'),
              timeFilter: any(named: 'timeFilter'),
            ),
          ).thenThrow(
            const ApiException(
              'The request payload is invalid.',
              statusCode: 400,
              code: 'validation_failed',
              fieldErrors: <String, String>{'timezone': 'unknown time zone'},
            ),
          ),
      build: build,
      act: (bloc) =>
          bloc.add(const ProfilePreferencesSubmitted(timezone: 'Mars/Olympus')),
      expect: () => const [
        ProfileState(isSavingPreferences: true),
        ProfileState(
          errorMessage: 'The request payload is invalid.',
          fieldErrors: <String, String>{'timezone': 'unknown time zone'},
        ),
      ],
    );
  });

  group('ProfilePasswordSubmitted', () {
    blocTest<ProfileBloc, ProfileState>(
      'confirms the change',
      setUp: () => when(
        () => auth.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(
        const ProfilePasswordSubmitted(
          currentPassword: 'correct-horse',
          newPassword: 'battery-staple',
        ),
      ),
      expect: () => const [
        ProfileState(isChangingPassword: true),
        ProfileState(outcome: ProfileOutcome.passwordChanged),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'keeps invalid_credentials as a code so the form can place it',
      setUp: () =>
          when(
            () => auth.changePassword(
              currentPassword: any(named: 'currentPassword'),
              newPassword: any(named: 'newPassword'),
            ),
          ).thenThrow(
            const ApiException(
              'Your current password is wrong.',
              statusCode: 401,
              code: 'invalid_credentials',
            ),
          ),
      build: build,
      act: (bloc) => bloc.add(
        const ProfilePasswordSubmitted(
          currentPassword: 'wrong',
          newPassword: 'battery-staple',
        ),
      ),
      expect: () => const [
        ProfileState(isChangingPassword: true),
        ProfileState(
          errorMessage: 'Your current password is wrong.',
          errorCode: 'invalid_credentials',
        ),
      ],
    );
  });

  group('ProfileAvatarSubmitted', () {
    /// The picture patch touches nothing else, so every other key is absent.
    void stubAttach({User? returns, Object? throws}) {
      final call = when(
        () => users.updatePreferences(avatarFileId: any(named: 'avatarFileId')),
      );

      if (throws != null) {
        call.thenThrow(throws);
      } else {
        call.thenAnswer((_) async => returns!);
      }
    }

    blocTest<ProfileBloc, ProfileState>(
      'uploads the image, then attaches the id it came back with',
      setUp: () {
        when(
          () => files.upload(any()),
        ).thenAnswer((_) async => remoteImage(id: 'uploaded-id'));
        stubAttach(returns: _saved);
      },
      build: build,
      act: (bloc) =>
          bloc.add(ProfileAvatarSubmitted(AvatarSelection.picked(testImage()))),
      expect: () => [
        const ProfileState(isSavingAvatar: true),
        ProfileState(updatedUser: _saved, outcome: ProfileOutcome.avatarSaved),
      ],
      verify: (_) => verify(
        () => users.updatePreferences(
          avatarFileId: const Optional<String>('uploaded-id'),
        ),
      ).called(1),
    );

    blocTest<ProfileBloc, ProfileState>(
      'removing sends an explicit null and never uploads',
      setUp: () => stubAttach(returns: _saved),
      build: build,
      act: (bloc) =>
          bloc.add(const ProfileAvatarSubmitted(AvatarSelection.cleared())),
      expect: () => [
        const ProfileState(isSavingAvatar: true),
        ProfileState(
          updatedUser: _saved,
          outcome: ProfileOutcome.avatarRemoved,
        ),
      ],
      verify: (_) {
        verifyNever(() => files.upload(any()));
        verify(
          () => users.updatePreferences(
            avatarFileId: const Optional<String>.clear(),
          ),
        ).called(1);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      'does nothing at all when the picker was dismissed',
      build: build,
      act: (bloc) =>
          bloc.add(const ProfileAvatarSubmitted(AvatarSelection.unchanged())),
      expect: () => <ProfileState>[],
      verify: (_) => verifyNever(
        () => users.updatePreferences(avatarFileId: any(named: 'avatarFileId')),
      ),
    );

    blocTest<ProfileBloc, ProfileState>(
      'reports an expired upload instead of leaving the field spinning',
      setUp: () {
        when(
          () => files.upload(any()),
        ).thenAnswer((_) async => remoteImage(id: 'uploaded-id'));
        // The file was reclaimed between the upload and the attach, or it
        // belongs to someone else.
        stubAttach(
          throws: const ApiException(
            'No such file.',
            statusCode: 404,
            code: 'file_not_found',
          ),
        );
      },
      build: build,
      act: (bloc) =>
          bloc.add(ProfileAvatarSubmitted(AvatarSelection.picked(testImage()))),
      expect: () => const [
        ProfileState(isSavingAvatar: true),
        ProfileState(
          errorMessage: 'No such file.',
          errorCode: 'file_not_found',
        ),
      ],
    );
  });
}
