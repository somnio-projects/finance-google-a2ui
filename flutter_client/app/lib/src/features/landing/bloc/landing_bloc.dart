import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';

import '../repository/landing_repository.dart';
import 'landing_event.dart';
import 'landing_state.dart';

class LandingBloc extends Bloc<LandingEvent, LandingState> {
  LandingBloc({required LandingRepository landingRepository})
    : _repository = landingRepository,
      super(const LandingState()) {
    on<LandingMessageSent>(_onMessageSent);
    on<LandingSurfaceSubmitted>(_onSurfaceSubmitted);
    on<LandingSurfacesChanged>(_onSurfacesChanged);
    on<LandingErrorOccurred>(_onErrorOccurred);
    on<LandingLoadingTextAdvanced>(_onLoadingTextAdvanced);

    _surfaceSub = _repository.surfaceUpdates.listen(
      (_) => _addIfOpen(const LandingSurfacesChanged()),
    );
    _submitSub = _repository.surfaceSubmits.listen(
      (message) => _addIfOpen(LandingSurfaceSubmitted(message)),
    );
    _errorSub = _repository.errors.listen(
      (error) => _addIfOpen(LandingErrorOccurred(error)),
    );
  }

  static const Duration _loadingTextInterval = Duration(seconds: 2);

  final LandingRepository _repository;
  final _logger = Logger('LandingBloc');

  late final StreamSubscription<SurfaceUpdate> _surfaceSub;
  late final StreamSubscription<ChatMessage> _submitSub;
  late final StreamSubscription<Object> _errorSub;

  Future<void> _onMessageSent(
    LandingMessageSent event,
    Emitter<LandingState> emit,
  ) async {
    final String text = event.text.trim();
    if (text.isEmpty) return;
    await _send(ChatMessage.user(text), emit);
  }

  Future<void> _onSurfaceSubmitted(
    LandingSurfaceSubmitted event,
    Emitter<LandingState> emit,
  ) => _send(event.message, emit);

  /// Ignored while a request is already in progress.
  Future<void> _send(ChatMessage message, Emitter<LandingState> emit) async {
    if (state.isLoading) return;
    emit(LandingState(status: .loading, surfaceIds: state.surfaceIds));

    final ticker = Timer.periodic(
      _loadingTextInterval,
      (_) => _addIfOpen(const LandingLoadingTextAdvanced()),
    );
    try {
      await _repository.sendMessage(message);
      emit(
        state.copyWith(
          status: .success,
          surfaceIds: _repository.activeSurfaceIds.toList(),
        ),
      );
    } catch (e, st) {
      _logger.severe('Error sending message', e, st);
      emit(state.copyWith(status: .failure, error: e.toString()));
    } finally {
      ticker.cancel();
    }
  }

  void _onSurfacesChanged(
    LandingSurfacesChanged event,
    Emitter<LandingState> emit,
  ) {
    emit(state.copyWith(surfaceIds: _repository.activeSurfaceIds.toList()));
  }

  void _onErrorOccurred(
    LandingErrorOccurred event,
    Emitter<LandingState> emit,
  ) {
    _logger.severe('Error from agent', event.error);
    emit(state.copyWith(error: event.error.toString()));
  }

  void _onLoadingTextAdvanced(
    LandingLoadingTextAdvanced event,
    Emitter<LandingState> emit,
  ) {
    if (!state.isLoading) return;
    emit(state.copyWith(loadingTextIndex: state.loadingTextIndex + 1));
  }

  void _addIfOpen(LandingEvent event) {
    if (!isClosed) add(event);
  }

  @override
  Future<void> close() async {
    await _surfaceSub.cancel();
    await _submitSub.cancel();
    await _errorSub.cancel();
    return super.close();
  }
}
