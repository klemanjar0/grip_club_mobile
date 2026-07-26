part of 'join_request_bloc.dart';

/// The verdict the admin reached, once the server has accepted it.
enum JoinRequestDecision { approved, rejected }

class JoinRequestState extends Equatable {
  const JoinRequestState({
    this.isSubmitting = false,
    this.pending,
    this.decision,
    this.errorMessage,
    this.errorCode,
  });

  final bool isSubmitting;

  /// Which button is waiting on the server, so only that one shows a spinner.
  /// Cleared when the call fails; [decision] takes over when it succeeds.
  final JoinRequestDecision? pending;

  /// Set once, and never unset — the request is settled and the sheet closes.
  final JoinRequestDecision? decision;

  final String? errorMessage;

  /// `member_not_found` means the request is already gone: withdrawn, or
  /// answered by someone else. Switch on this, never on [errorMessage].
  final String? errorCode;

  /// The request was already dealt with, so there is nothing left to decide.
  bool get isSettledElsewhere => errorCode == 'member_not_found';

  JoinRequestState copyWith({
    bool? isSubmitting,
    JoinRequestDecision? pending,
    JoinRequestDecision? decision,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    bool clearPending = false,
  }) => JoinRequestState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    pending: clearPending ? null : pending ?? this.pending,
    decision: decision ?? this.decision,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );

  @override
  List<Object?> get props => [
    isSubmitting,
    pending,
    decision,
    errorMessage,
    errorCode,
  ];
}
