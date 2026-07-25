import 'package:bloc/bloc.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_state.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';
import 'package:grip_club_mobile/features/members/data/membership_repository.dart';

/// Paging, refreshing and error handling for a feed of lobbies.
///
/// Both feeds behave identically apart from the endpoint they read, so the
/// behaviour lives here once and subclasses only supply [fetchPage].
abstract class LobbyFeedBloc extends Bloc<LobbyFeedEvent, LobbyFeedState> {
  LobbyFeedBloc({required this._memberships}) : super(const LobbyFeedState()) {
    on<LobbyFeedRequested>(_onRequested);
    on<LobbyFeedRefreshed>(_onRefreshed);
    on<LobbyFeedNextPageRequested>(_onNextPageRequested);
    on<LobbyFeedFilterChanged>(_onFilterChanged);
    on<LobbyFeedJoinRequested>(_onJoinRequested);
    on<LobbyFeedCleared>((event, emit) => emit(const LobbyFeedState()));
  }

  final MembershipRepository _memberships;

  /// Reads one page. [state] carries the active filters for the feeds that have
  /// them.
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page);

  /// Joins a lobby from its card in the list.
  ///
  /// The row is patched in place from the membership the server returns rather
  /// than re-reading the page: a refresh would jump the reader back to the top,
  /// and a private lobby cannot be re-read at all once the caller is merely
  /// pending on it.
  Future<void> _onJoinRequested(
    LobbyFeedJoinRequested event,
    Emitter<LobbyFeedState> emit,
  ) async {
    if (state.joiningLobbyId != null) return;

    emit(
      state.copyWith(
        joiningLobbyId: event.lobbyId,
        clearJoining: false,
        clearError: true,
      ),
    );

    try {
      final membership = await _memberships.join(event.lobbyId);

      emit(
        state.copyWith(
          lobbies: [
            for (final lobby in state.lobbies)
              lobby.id == event.lobbyId
                  ? lobby.withMembership(membership.status)
                  : lobby,
          ],
          clearJoining: true,
          joinOutcome: membership.isApproved
              ? LobbyJoinOutcome.joined
              : LobbyJoinOutcome.requestSent,
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(clearJoining: true, errorMessage: exception.message));
    }
  }

  Future<void> _onRequested(
    LobbyFeedRequested event,
    Emitter<LobbyFeedState> emit,
  ) async {
    // Returning to a tab must not refetch what is already on screen.
    if (state.status == LobbyFeedStatus.ready) return;

    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    LobbyFeedRefreshed event,
    Emitter<LobbyFeedState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _onFilterChanged(
    LobbyFeedFilterChanged event,
    Emitter<LobbyFeedState> emit,
  ) async {
    emit(state.copyWith(city: event.city, within: event.within));

    await _loadFirstPage(emit);
  }

  Future<void> _onNextPageRequested(
    LobbyFeedNextPageRequested event,
    Emitter<LobbyFeedState> emit,
  ) async {
    if (!state.hasNext ||
        state.isLoadingMore ||
        state.status != LobbyFeedStatus.ready) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, clearError: true));

    try {
      final page = await fetchPage(state, state.page + 1);

      emit(
        state.copyWith(
          lobbies: [...state.lobbies, ...page.items],
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (exception) {
      // The loaded pages stay on screen; the view shows the message and the
      // scroll listener will retry on the next scroll.
      emit(
        state.copyWith(isLoadingMore: false, errorMessage: exception.message),
      );
    }
  }

  Future<void> _loadFirstPage(Emitter<LobbyFeedState> emit) async {
    emit(state.copyWith(status: LobbyFeedStatus.loading, clearError: true));

    try {
      final page = await fetchPage(state, 0);

      emit(
        state.copyWith(
          status: LobbyFeedStatus.ready,
          lobbies: page.items,
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      );
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: LobbyFeedStatus.failure,
          lobbies: const [],
          hasNext: false,
          isLoadingMore: false,
          errorMessage: exception.message,
        ),
      );
    }
  }
}

/// `GET /lobbies` — upcoming public lobbies, filtered by city and time window.
class LobbiesBloc extends LobbyFeedBloc {
  LobbiesBloc({required this._repository, required super.memberships});

  final LobbyRepository _repository;

  @override
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page) =>
      // Null filters are omitted from the query, which makes the server apply
      // the user's saved city and time filter.
      _repository.browse(city: state.city, within: state.within, page: page);
}

/// `GET /me/lobbies` — created or joined, past events included.
///
/// Inherits joining without offering it: every lobby in this feed is one the
/// caller is already in, so no card here shows a join button.
class MyLobbiesBloc extends LobbyFeedBloc {
  MyLobbiesBloc({required this._repository, required super.memberships});

  final LobbyRepository _repository;

  @override
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page) =>
      _repository.myLobbies(page: page);
}
