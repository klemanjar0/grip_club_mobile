import 'package:bloc/bloc.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/core/pagination/page_envelope.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_event.dart';
import 'package:grip_club_mobile/features/lobbies/bloc/lobby_feed_state.dart';
import 'package:grip_club_mobile/features/lobbies/data/lobby_repository.dart';
import 'package:grip_club_mobile/features/lobbies/domain/lobby.dart';

/// Paging, refreshing and error handling for a feed of lobbies.
///
/// Both feeds behave identically apart from the endpoint they read, so the
/// behaviour lives here once and subclasses only supply [fetchPage].
abstract class LobbyFeedBloc extends Bloc<LobbyFeedEvent, LobbyFeedState> {
  LobbyFeedBloc() : super(const LobbyFeedState()) {
    on<LobbyFeedRequested>(_onRequested);
    on<LobbyFeedRefreshed>(_onRefreshed);
    on<LobbyFeedNextPageRequested>(_onNextPageRequested);
    on<LobbyFeedFilterChanged>(_onFilterChanged);
    on<LobbyFeedCleared>((event, emit) => emit(const LobbyFeedState()));
  }

  /// Reads one page. [state] carries the active filters for the feeds that have
  /// them.
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page);

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
  LobbiesBloc({required this._repository});

  final LobbyRepository _repository;

  @override
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page) =>
      // Null filters are omitted from the query, which makes the server apply
      // the user's saved city and time filter.
      _repository.browse(city: state.city, within: state.within, page: page);
}

/// `GET /me/lobbies` — created or joined, past events included.
class MyLobbiesBloc extends LobbyFeedBloc {
  MyLobbiesBloc({required this._repository});

  final LobbyRepository _repository;

  @override
  Future<PageEnvelope<Lobby>> fetchPage(LobbyFeedState state, int page) =>
      _repository.myLobbies(page: page);
}
