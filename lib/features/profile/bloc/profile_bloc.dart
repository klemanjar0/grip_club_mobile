import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/files/data/avatar_uploader.dart';
import 'package:grip_club_mobile/features/profile/data/user_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// The write actions on the Profile tab: saving preferences, changing the
/// picture, and changing the password.
///
/// The signed-in [User] itself lives in `AuthBloc`; this bloc only reports the
/// updated one, and the page forwards it there.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required this._users,
    required this._auth,
    required this._avatars,
  }) : super(const ProfileState()) {
    on<ProfilePreferencesSubmitted>(_onPreferencesSubmitted);
    on<ProfileAvatarSubmitted>(_onAvatarSubmitted);
    on<ProfilePasswordSubmitted>(_onPasswordSubmitted);
  }

  final UserRepository _users;
  final AuthRepository _auth;
  final AvatarUploader _avatars;

  Future<void> _onPreferencesSubmitted(
    ProfilePreferencesSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isSavingPreferences: true, clearFeedback: true));

    try {
      final user = await _users.updatePreferences(
        displayName: event.displayName,
        locale: event.locale,
        timezone: event.timezone,
        city: event.city,
        timeFilter: event.timeFilter,
      );

      emit(
        state.copyWith(
          isSavingPreferences: false,
          updatedUser: user,
          outcome: ProfileOutcome.preferencesSaved,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isSavingPreferences: false,
          errorMessage: exception.message,
          fieldErrors: exception.fieldErrors,
        ),
      );
    }
  }

  /// The picture saves on its own, without the Save button underneath it.
  ///
  /// Two round trips hide behind this: the image goes to `POST /files` first,
  /// and only the id it comes back with is attached to the profile. A failure
  /// in either leaves the stored picture exactly as it was.
  Future<void> _onAvatarSubmitted(
    ProfileAvatarSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    final avatarFileId = await _avatars.resolve(event.selection);
    // Nothing actually changed — the user opened the sheet and backed out.
    if (avatarFileId == null) return;

    emit(state.copyWith(isSavingAvatar: true, clearFeedback: true));

    try {
      emit(
        state.copyWith(
          isSavingAvatar: false,
          updatedUser: await _users.updatePreferences(
            avatarFileId: avatarFileId,
          ),
          outcome: avatarFileId.isClearing
              ? ProfileOutcome.avatarRemoved
              : ProfileOutcome.avatarSaved,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isSavingAvatar: false,
          errorMessage: exception.message,
          errorCode: exception.code,
        ),
      );
    }
  }

  Future<void> _onPasswordSubmitted(
    ProfilePasswordSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isChangingPassword: true, clearFeedback: true));

    try {
      await _auth.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      emit(
        state.copyWith(
          isChangingPassword: false,
          outcome: ProfileOutcome.passwordChanged,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          isChangingPassword: false,
          errorMessage: exception.message,
          errorCode: exception.code,
          fieldErrors: exception.fieldErrors,
        ),
      );
    }
  }
}
