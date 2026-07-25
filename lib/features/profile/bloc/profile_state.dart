part of 'profile_bloc.dart';

/// What succeeded, so the page can confirm it once.
enum ProfileOutcome { preferencesSaved, passwordChanged }

class ProfileState extends Equatable {
  const ProfileState({
    this.isSavingPreferences = false,
    this.isChangingPassword = false,
    this.updatedUser,
    this.outcome,
    this.errorMessage,
    this.errorCode,
    this.fieldErrors = const {},
  });

  final bool isSavingPreferences;
  final bool isChangingPassword;

  /// The profile as the server now has it. The page hands this to `AuthBloc`.
  final User? updatedUser;

  final ProfileOutcome? outcome;
  final String? errorMessage;

  /// `invalid_credentials` when the current password is wrong — the form puts
  /// that on the field rather than in a snackbar.
  final String? errorCode;

  /// From `validation_failed`, keyed by JSON field name (`timezone`,
  /// `new_password`, …).
  final Map<String, String> fieldErrors;

  bool get isBusy => isSavingPreferences || isChangingPassword;

  ProfileState copyWith({
    bool? isSavingPreferences,
    bool? isChangingPassword,
    User? updatedUser,
    ProfileOutcome? outcome,
    String? errorMessage,
    String? errorCode,
    Map<String, String>? fieldErrors,
    bool clearFeedback = false,
  }) => ProfileState(
    isSavingPreferences: isSavingPreferences ?? this.isSavingPreferences,
    isChangingPassword: isChangingPassword ?? this.isChangingPassword,
    updatedUser: updatedUser ?? this.updatedUser,
    outcome: clearFeedback ? null : outcome ?? this.outcome,
    errorMessage: clearFeedback ? null : errorMessage ?? this.errorMessage,
    errorCode: clearFeedback ? null : errorCode ?? this.errorCode,
    fieldErrors: clearFeedback ? const {} : fieldErrors ?? this.fieldErrors,
  );

  @override
  List<Object?> get props => [
    isSavingPreferences,
    isChangingPassword,
    updatedUser,
    outcome,
    errorMessage,
    errorCode,
    fieldErrors,
  ];
}
