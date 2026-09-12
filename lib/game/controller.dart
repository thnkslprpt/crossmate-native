import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/online_service.dart';
import '../services/settings_service.dart';
import 'ai.dart';
import 'engine.dart';
import 'models.dart';

class CrossmateController extends ChangeNotifier {
  CrossmateController({
    CrossmateEngine? engine,
    CrossmateAi? ai,
    SettingsService? settings,
    OnlineService? online,
  }) : engine = engine ?? CrossmateEngine(),
       ai = ai ?? const CrossmateAi(),
       settings = settings ?? const SettingsService(),
       online = online ?? OnlineService();

  final CrossmateEngine engine;
  final CrossmateAi ai;
  final SettingsService settings;
  final OnlineService online;

  BoardThemeId theme = BoardThemeId.neon;
  AiDifficulty aiDifficulty = AiDifficulty.normal;
  MatchMode mode = MatchMode.local;
  GameState? state;

  int humanPlayer = 1;
  int aiPlayer = 2;
  int localPlayer = 1;

  String aiOpening = 'human';
  int boardSize = 9;

  bool busy = false;
  bool aiThinking = false;
  bool hasOpponent = false;
  bool opponentConnected = false;
  bool onlineExpired = false;

  String? roomCode;
  String? message;
  String? selectedPieceId;

  List<GameMove> selectedMoves = const <GameMove>[];
  List<GameMove> pendingTriangleMoves = const <GameMove>[];
  List<GameMove> pendingEdgeMoves = const <GameMove>[];

  final List<MatchSnapshot> _history = <MatchSnapshot>[];
  int _reviewIndex = -1;

  OnlineRoomHandle? _room;
  StreamSubscription<OnlineRoomUpdate>? _roomSubscription;

  bool _disposed = false;

  List<MatchSnapshot> get history => List<MatchSnapshot>.unmodifiable(_history);

  int get reviewIndex => _reviewIndex;

  bool get isReviewing =>
      _reviewIndex >= 0 && _reviewIndex < _history.length - 1;

  bool get canReviewBack => _reviewIndex > 0;

  bool get canReviewForward =>
      _reviewIndex >= 0 && _reviewIndex < _history.length - 1;

  GameState? get displayedState =>
      _reviewIndex >= 0 && _reviewIndex < _history.length
      ? _history[_reviewIndex].state
      : state;

  bool get canAct {
    final current = state;

    if (current == null ||
        current.gameOver ||
        busy ||
        aiThinking ||
        isReviewing) {
      return false;
    }

    return switch (mode) {
      MatchMode.local => true,
      MatchMode.computer => current.currentPlayer == humanPlayer,
      MatchMode.online =>
        hasOpponent && !onlineExpired && current.currentPlayer == localPlayer,
    };
  }

  bool get isOnline => mode == MatchMode.online;
  bool get isComputer => mode == MatchMode.computer;

  Future<void> load() async {
    theme = await settings.loadTheme();
    boardSize = await settings.loadBoardSize();
    aiDifficulty = await settings.loadDifficulty();
    _notify();
  }

  Future<void> setBoardSize(int value) async {
    if (value != 7 && value != 9) return;
    boardSize = value;
    _notify();
    await settings.saveBoardSize(value);
  }

  Future<void> setTheme(BoardThemeId value) async {
    theme = value;
    await settings.saveTheme(value);
    _notify();
  }

  Future<void> startLocal({int? startingPlayer}) async {
    await leaveOnline();

    mode = MatchMode.local;
    humanPlayer = 1;
    aiPlayer = 2;
    hasOpponent = true;
    opponentConnected = true;
    onlineExpired = false;
    roomCode = null;
    message = null;

    _setFreshState(
      engine.initialState(startingPlayer: startingPlayer, boardSize: boardSize),
    );
  }

  Future<void> startComputer({
    required AiDifficulty difficulty,
    String opening = 'human',
  }) async {
    await leaveOnline();

    mode = MatchMode.computer;
    aiDifficulty = difficulty;

    await settings.saveDifficulty(difficulty);
    await settings.saveOpening(opening);

    humanPlayer = 1;
    aiPlayer = 2;
    aiOpening = opening;

    final startingPlayer = _computerStartingPlayer();

    hasOpponent = true;
    opponentConnected = true;
    onlineExpired = false;
    roomCode = null;
    message = null;

    _setFreshState(
      engine.initialState(startingPlayer: startingPlayer, boardSize: boardSize),
    );

    await _runAiIfNeeded();
  }

  Future<void> createOnlineRoom() async {
    await leaveOnline();
    _prepareOnlineTransition();

    busy = true;
    message = 'Creating a secure room…';
    _notify();

    try {
      final handle = await online.createRoom(boardSize: boardSize);
      _attachRoom(handle);
      message = 'Share the room code with Player 2.';
    } on OnlineUnavailableException catch (error) {
      message = error.message;
      rethrow;
    } catch (error) {
      final wrapped = OnlineUnavailableException(
        'Could not connect to online play. Please try again.\n\n$error',
      );
      message = wrapped.message;
      throw wrapped;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> joinOnlineRoom(String code) async {
    await leaveOnline();
    _prepareOnlineTransition();

    busy = true;
    message = 'Joining room…';
    _notify();

    try {
      final handle = await online.joinRoom(code);
      _attachRoom(handle);
      message = 'Connected. The board shows who moves first.';
    } on OnlineUnavailableException catch (error) {
      message = error.message;
      rethrow;
    } catch (error) {
      final wrapped = OnlineUnavailableException(
        'Could not connect to online play. Please try again.\n\n$error',
      );
      message = wrapped.message;
      throw wrapped;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _prepareOnlineTransition() {
    mode = MatchMode.online;
    state = null;

    _history.clear();
    _reviewIndex = -1;

    _clearSelection();

    hasOpponent = false;
    opponentConnected = false;
    onlineExpired = false;
    roomCode = null;
  }

  void _attachRoom(OnlineRoomHandle handle) {
    _room = handle;
    localPlayer = handle.localPlayer;
    roomCode = handle.code;

    hasOpponent = false;
    opponentConnected = false;
    onlineExpired = false;

    _roomSubscription = handle.updates.listen(
      _applyOnlineUpdate,
      onError: (Object error, StackTrace stackTrace) {
        message = error.toString();
        _notify();
      },
    );
  }

  void _applyOnlineUpdate(OnlineRoomUpdate update) {
    hasOpponent = update.hasOpponent;
    opponentConnected = update.opponentConnected;
    onlineExpired = update.expired;
    state = update.state;
    boardSize = update.state.boardSize;

    _clearSelection();

    if (_history.isEmpty ||
        update.state.moveNumber < _history.last.state.moveNumber) {
      _history
        ..clear()
        ..add(MatchSnapshot(state: update.state, description: 'Game started'));
    } else if (update.state.moveNumber == _history.last.state.moveNumber) {
      _history[_history.length - 1] = MatchSnapshot(
        state: update.state,
        description: update.state.moveNumber == 0
            ? 'Game started'
            : engine.describeMove(update.state, update.state.lastMove),
      );
    } else {
      _history.add(
        MatchSnapshot(
          state: update.state,
          description: engine.describeMove(update.state, update.state.lastMove),
        ),
      );
    }

    _reviewIndex = _history.length - 1;

    message = update.expired
        ? 'This room has expired.'
        : (!update.hasOpponent
              ? 'Waiting for Player 2…'
              : (update.opponentConnected
                    ? null
                    : 'Opponent is temporarily offline.'));

    _notify();
  }

  void tapCell(int row, int col) {
    final current = state;

    if (current == null || !canAct) return;

    if (pendingEdgeMoves.isNotEmpty) {
      final target = engine.pieceAt(current, row, col);

      if (target != null) {
        final match = pendingEdgeMoves.cast<GameMove?>().firstWhere(
          (move) => move?.destroyTargetId == target.id,
          orElse: () => null,
        );

        if (match != null) {
          unawaited(commitMove(match));
        }
      }

      return;
    }

    final occupant = engine.pieceAt(current, row, col);

    if (occupant != null &&
        occupant.player == current.currentPlayer &&
        occupant.id != selectedPieceId) {
      selectPiece(occupant.id);
      return;
    }

    if (selectedPieceId == null) return;

    final candidates = selectedMoves
        .where((move) {
          return (move.resolvedLandingRow == row &&
                  move.resolvedLandingCol == col) ||
              (move.toRow == row && move.toCol == col);
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      _clearSelection();
      _notify();
      return;
    }

    final edgeMoves = candidates.where((move) => move.edgeBlast).toList();

    if (edgeMoves.length > 1 ||
        (edgeMoves.length == 1 && candidates.length > 1)) {
      pendingEdgeMoves = edgeMoves;
      pendingTriangleMoves = const <GameMove>[];
      message = 'Choose any non-cross enemy piece to remove.';
      _notify();
      return;
    }

    final triangleMoves = candidates
        .where((move) => move.type == PieceType.triangle)
        .toList(growable: false);

    if (triangleMoves.length > 1) {
      pendingTriangleMoves = triangleMoves;
      pendingEdgeMoves = const <GameMove>[];
      message = 'Choose the triangle’s final direction.';
      _notify();
      return;
    }

    unawaited(commitMove(candidates.first));
  }

  void selectPiece(String pieceId) {
    final current = state;

    if (current == null || !canAct) return;

    final piece = engine.pieceById(current, pieceId);

    if (piece == null ||
        !piece.alive ||
        piece.player != current.currentPlayer) {
      return;
    }

    selectedPieceId = piece.id;
    selectedMoves = engine.legalMovesForPiece(current, piece);
    pendingTriangleMoves = const <GameMove>[];
    pendingEdgeMoves = const <GameMove>[];

    message = selectedMoves.isEmpty ? 'That piece has no legal move.' : null;

    _notify();
  }

  Future<void> chooseTriangle(GameMove move) {
    return commitMove(move);
  }

  Future<void> chooseEdgeTarget(String targetId) async {
    final move = pendingEdgeMoves.cast<GameMove?>().firstWhere(
      (candidate) => candidate?.destroyTargetId == targetId,
      orElse: () => null,
    );

    if (move != null) {
      await commitMove(move);
    }
  }

  void cancelChoice() {
    pendingTriangleMoves = const <GameMove>[];
    pendingEdgeMoves = const <GameMove>[];
    message = null;
    _notify();
  }

  Future<void> commitMove(GameMove move) async {
    final current = state;

    if (current == null || !canAct) return;

    busy = true;
    message = null;
    _notify();

    try {
      if (mode == MatchMode.online) {
        final played = await _room?.play(move) ?? false;

        if (!played) {
          message =
              'The position changed before that move was saved. Try again.';
        }
      } else {
        final next = engine.advance(current, move);

        state = next;

        _history.add(
          MatchSnapshot(
            state: next,
            description: engine.describeMove(next, next.lastMove),
          ),
        );

        _reviewIndex = _history.length - 1;
      }
    } on StateError catch (error) {
      message = error.message;
    } finally {
      _clearSelection();
      busy = false;
      _notify();
    }

    await _runAiIfNeeded();
  }

  Future<void> _runAiIfNeeded() async {
    final current = state;

    if (mode != MatchMode.computer ||
        current == null ||
        current.gameOver ||
        current.currentPlayer != aiPlayer ||
        aiThinking ||
        _disposed) {
      return;
    }

    aiThinking = true;

    message = '${aiDifficulty.label} robot is thinking…';

    _notify();

    await Future<void>.delayed(const Duration(milliseconds: 260));

    try {
      final move = await ai.chooseMove(current, aiDifficulty, aiPlayer);

      if (move != null &&
          !_disposed &&
          state?.moveNumber == current.moveNumber) {
        final next = engine.advance(current, move);

        state = next;

        _history.add(
          MatchSnapshot(
            state: next,
            description: engine.describeMove(next, next.lastMove),
          ),
        );

        _reviewIndex = _history.length - 1;
      }
    } catch (error) {
      message = 'The robot could not complete its move: $error';
    } finally {
      aiThinking = false;

      if (message?.contains('robot is thinking') == true) {
        message = null;
      }

      _notify();
    }
  }

  int _computerStartingPlayer() {
    return switch (aiOpening) {
      'computer' => aiPlayer,
      'random' => Random().nextBool() ? humanPlayer : aiPlayer,
      _ => humanPlayer,
    };
  }

  Future<void> restart() async {
    _clearSelection();

    if (mode == MatchMode.online) {
      busy = true;
      _notify();

      try {
        await _room?.restart();
      } finally {
        busy = false;
        _notify();
      }

      return;
    }

    final startingPlayer = mode == MatchMode.computer
        ? _computerStartingPlayer()
        : null;

    _setFreshState(
      engine.initialState(startingPlayer: startingPlayer, boardSize: boardSize),
    );

    await _runAiIfNeeded();
  }

  void reviewPrevious() {
    if (!canReviewBack) return;

    _reviewIndex -= 1;
    _clearSelection();
    _notify();
  }

  void reviewNext() {
    if (!canReviewForward) return;

    _reviewIndex += 1;
    _clearSelection();
    _notify();
  }

  void returnToLive() {
    if (_history.isEmpty) return;

    _reviewIndex = _history.length - 1;
    _clearSelection();
    _notify();
  }

  void _setFreshState(GameState value) {
    state = value;

    _history
      ..clear()
      ..add(MatchSnapshot(state: value, description: 'Game started'));

    _reviewIndex = 0;

    _clearSelection();

    busy = false;
    aiThinking = false;

    _notify();
  }

  void _clearSelection() {
    selectedPieceId = null;
    selectedMoves = const <GameMove>[];
    pendingTriangleMoves = const <GameMove>[];
    pendingEdgeMoves = const <GameMove>[];
  }

  Future<void> leaveOnline() async {
    await _roomSubscription?.cancel();
    _roomSubscription = null;

    final room = _room;
    _room = null;

    if (room != null) {
      await room.leave();
    }

    roomCode = null;
    hasOpponent = false;
    opponentConnected = false;
    onlineExpired = false;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    unawaited(_roomSubscription?.cancel());
    unawaited(_room?.leave());

    super.dispose();
  }
}
