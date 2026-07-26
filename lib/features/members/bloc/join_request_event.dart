part of 'join_request_bloc.dart';

sealed class JoinRequestEvent extends Equatable {
  const JoinRequestEvent();

  @override
  List<Object?> get props => [];
}

/// Lets the applicant in. They are notified and gain the address and chat link.
final class JoinRequestApprovalRequested extends JoinRequestEvent {
  const JoinRequestApprovalRequested();
}

/// Declines the request. Reversible by the applicant — the row is deleted, so
/// they may ask again. Banning, which is terminal, is not offered here.
final class JoinRequestRejectionRequested extends JoinRequestEvent {
  const JoinRequestRejectionRequested();
}
