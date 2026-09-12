import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'models.dart';

class CrossmateAi {
  const CrossmateAi();

  Future<GameMove?> chooseMove(
    GameState state,
    AiDifficulty difficulty,
    int player,
  ) async {
    if (state.gameOver || state.currentPlayer != player) return null;
    final payload = <String, Object?>{
      'state': state.toJson(),
      'difficulty': difficulty.name,
      'player': player,
    };
    final result = await compute(_searchEntry, payload);
    if (result == null) return null;
    return GameMove.fromJson(result);
  }
}

Map<String, Object?>? _searchEntry(Map<String, Object?> payload) {
  final rawState = payload['state'];
  if (rawState is! Map) return null;
  final state = GameState.fromJson(Map<Object?, Object?>.from(rawState));
  final difficulty = AiDifficulty.values.firstWhere(
    (candidate) => candidate.name == payload['difficulty'],
    orElse: () => AiDifficulty.normal,
  );
  final player = (payload['player'] as num?)?.toInt() ?? 2;
  final search = _AiSearch(difficulty: difficulty, rootPlayer: player);
  return search.choose(state)?.toJson();
}

class _SearchTimeout implements Exception {
  const _SearchTimeout();
}

class _AiSearch {
  _AiSearch({required this.difficulty, required this.rootPlayer})
    : _engine = CrossmateEngine(random: Random(0)),
      _random = Random();

  static const double mateScore = 1000000;

  final AiDifficulty difficulty;
  final int rootPlayer;
  final CrossmateEngine _engine;
  final Random _random;
  final Stopwatch _clock = Stopwatch();
  final Map<String, _SearchEntry> _transposition = {};
  String? _preferredRootMove;
  late int _timeLimitMs;
  var _nodes = 0;

  GameMove? choose(GameState state) {
    final legal = _engine.allLegalMoves(state, rootPlayer);
    if (legal.isEmpty) return null;
    if (difficulty == AiDifficulty.easy) return _easyMove(state, legal);

    final (timeLimit, maxDepth) = switch (difficulty) {
      AiDifficulty.easy => (0, 0),
      AiDifficulty.normal => (450, 2),
      AiDifficulty.hard => (1400, 4),
      AiDifficulty.expert => (2800, 6),
      AiDifficulty.master => (5000, 8),
    };
    _timeLimitMs = timeLimit;
    _clock.start();
    GameMove? best = _orderedMoves(state, legal).first;

    try {
      for (var depth = 1; depth <= maxDepth; depth += 1) {
        final result = _searchRoot(state, depth);
        if (result.move != null) {
          best = result.move;
          _preferredRootMove = best!.signature;
        }
        if (result.score.abs() >= mateScore - 100) break;
      }
    } on _SearchTimeout {
      // Keep the strongest fully completed iteration.
    }
    return best;
  }

  void _checkTime() {
    _nodes += 1;
    if ((_nodes & 7) == 0 && _clock.elapsedMilliseconds >= _timeLimitMs) {
      throw const _SearchTimeout();
    }
  }

  GameMove _easyMove(GameState state, List<GameMove> legal) {
    // Usually play without looking ahead, giving beginners room to experiment.
    if (_random.nextDouble() < 0.85) {
      return legal[_random.nextInt(legal.length)];
    }
    return _orderedMoves(state, legal).first;
  }

  _SearchResult _searchRoot(GameState state, int depth) {
    final moves = _orderedMoves(
      state,
      _engine.allLegalMoves(state, rootPlayer),
    );
    final preferred = moves.indexWhere(
      (move) => move.signature == _preferredRootMove,
    );
    if (preferred > 0) moves.insert(0, moves.removeAt(preferred));
    var bestScore = double.negativeInfinity;
    final bestMoves = <GameMove>[];

    for (final move in moves) {
      _checkTime();
      final child = _advanceForSearch(state, move);
      final score = _minimax(child, depth - 1, bestScore, double.infinity, 1);
      if (score > bestScore + 0.001) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      }
    }
    return _SearchResult(
      bestMoves.isEmpty ? null : bestMoves[_random.nextInt(bestMoves.length)],
      bestScore,
    );
  }

  double _minimax(
    GameState state,
    int depth,
    double alpha,
    double beta,
    int ply,
  ) {
    _checkTime();
    final moves = _engine.allLegalMoves(state, state.currentPlayer);
    final terminal = _terminalScore(state, ply, moves);
    if (terminal != null) return terminal;
    if (depth <= 0) {
      if (difficulty == AiDifficulty.expert ||
          difficulty == AiDifficulty.master) {
        return _quiescence(state, moves, alpha, beta, ply, 3);
      }
      return _evaluate(state);
    }

    final key =
        '${_engine.positionKey(state)}|${state.halfmoveClock}|${state.scores}|$depth|$ply';
    final cached = _transposition[key];
    if (cached != null) {
      if (cached.bound == 0) return cached.score;
      if (cached.bound > 0 && cached.score >= beta) return cached.score;
      if (cached.bound < 0 && cached.score <= alpha) return cached.score;
    }

    final maximizing = state.currentPlayer == rootPlayer;
    var best = maximizing ? double.negativeInfinity : double.infinity;
    var localAlpha = alpha;
    var localBeta = beta;

    for (final move in _orderedMoves(state, moves)) {
      final child = _advanceForSearch(state, move);
      final score = _minimax(child, depth - 1, localAlpha, localBeta, ply + 1);
      if (maximizing) {
        best = max(best, score);
        localAlpha = max(localAlpha, best);
      } else {
        best = min(best, score);
        localBeta = min(localBeta, best);
      }
      if (localBeta <= localAlpha) {
        break;
      }
    }
    _transposition[key] = _SearchEntry(
      best,
      best <= alpha
          ? -1
          : best >= beta
          ? 1
          : 0,
    );
    return best;
  }

  double _quiescence(
    GameState state,
    List<GameMove> moves,
    double alpha,
    double beta,
    int ply,
    int remaining,
  ) {
    _checkTime();
    final terminal = _terminalScore(state, ply, moves);
    if (terminal != null) return terminal;
    final maximizing = state.currentPlayer == rootPlayer;
    final checked = _engine.isInCheck(state, state.currentPlayer);
    final staticScore = _evaluate(state);
    if (remaining == 0) return staticScore;
    var best = checked
        ? (maximizing ? double.negativeInfinity : double.infinity)
        : staticScore;
    if (!checked) {
      if (maximizing) {
        if (best >= beta) return best;
        alpha = max(alpha, best);
      } else {
        if (best <= alpha) return best;
        beta = min(beta, best);
      }
    }
    final tactical = checked
        ? moves
        : moves.where((move) => move.isCapture).toList();
    for (final move in _orderedMoves(state, tactical)) {
      final child = _advanceForSearch(state, move);
      final score = _quiescence(
        child,
        _engine.allLegalMoves(child, child.currentPlayer),
        alpha,
        beta,
        ply + 1,
        remaining - 1,
      );
      if (maximizing) {
        best = max(best, score);
        alpha = max(alpha, best);
      } else {
        best = min(best, score);
        beta = min(beta, best);
      }
      if (alpha >= beta) break;
    }
    return best;
  }

  double? _terminalScore(GameState state, int ply, List<GameMove> knownMoves) {
    final rootCross = _engine.crossFor(state, rootPlayer);
    final enemyCross = _engine.crossFor(state, _engine.otherPlayer(rootPlayer));
    if (rootCross == null) return -mateScore + ply;
    if (enemyCross == null) return mateScore - ply;
    if (knownMoves.isEmpty) {
      return state.currentPlayer == rootPlayer
          ? -mateScore + ply
          : mateScore - ply;
    }
    if (_engine.onlyCrossesRemain(state) ||
        state.halfmoveClock >= CrossmateEngine.noCaptureLimit) {
      return 0;
    }
    return null;
  }

  double _evaluate(GameState state) {
    var score = 0.0;
    var rootMobility = 0;
    var enemyMobility = 0;
    for (final piece in state.pieces) {
      if (!piece.alive) continue;
      final sign = piece.player == rootPlayer ? 1.0 : -1.0;
      score += sign * piece.type.aiValue;
      final centre =
          state.boardSize -
          1 -
          ((piece.row - state.boardSize ~/ 2).abs() +
              (piece.col - state.boardSize ~/ 2).abs());
      if (piece.type != PieceType.cross && piece.type != PieceType.diamond) {
        score += sign * centre * 3;
      }
      if (piece.type == PieceType.circle) {
        final advancement = piece.player == 1
            ? state.boardSize - 2 - piece.row
            : piece.row - 1;
        score += sign * advancement * 11;
      }
      score += sign * _fieldInfluence(state, piece);
      if (piece.type != PieceType.cross) {
        final pseudo = min(
          18,
          _engine.pseudoMovesForPiece(state, piece).length,
        );
        if (piece.player == rootPlayer) {
          rootMobility += pseudo;
        } else {
          enemyMobility += pseudo;
        }
      }
    }
    score += (rootMobility - enemyMobility) * 1.6;
    if (_engine.isInCheck(state, rootPlayer)) score -= 145;
    if (_engine.isInCheck(state, _engine.otherPlayer(rootPlayer))) score += 125;
    score +=
        ((state.scores[rootPlayer] ?? 0) -
            (state.scores[_engine.otherPlayer(rootPlayer)] ?? 0)) *
        5;
    return score;
  }

  int _fieldInfluence(GameState state, Piece piece) {
    if (piece.type != PieceType.diamond) return 0;
    var score = 0;
    for (var row = piece.row - 1; row <= piece.row + 1; row += 1) {
      for (var col = piece.col - 1; col <= piece.col + 1; col += 1) {
        if (!_engine.inBounds(state, row, col) ||
            (row == piece.row && col == piece.col)) {
          continue;
        }
        score += 3;
        if (row >= 2 &&
            row <= state.boardSize - 3 &&
            col >= 2 &&
            col <= state.boardSize - 3) {
          score += 2;
        }
      }
    }
    return score;
  }

  int _capturedMaterial(GameState state, GameMove move) {
    var total = 0;
    for (final id in move.captures) {
      final captured = _engine.pieceById(state, id);
      if (captured != null) total += captured.type.aiValue;
    }
    return total;
  }

  List<GameMove> _orderedMoves(GameState state, List<GameMove> moves) {
    final entries =
        moves.map((move) {
          var score = _capturedMaterial(state, move) * 12.0;
          score -= move.isCapture
              ? (_engine.pieceById(state, move.pieceId)?.type.aiValue ?? 0) *
                    0.1
              : 0;
          for (final id in move.captures) {
            final captured = _engine.pieceById(state, id);
            if (captured?.type == PieceType.cross) score += mateScore;
          }
          if (move.edgeBlast) score += 180;
          if (move.diamondCapture) score += 120;
          if (_engine.pieceById(state, move.pieceId)?.type ==
              PieceType.diamond) {
            score += 18;
          }
          return _RankedMove(
            move,
            state.currentPlayer == rootPlayer ? score : -score,
          );
        }).toList()..sort(
          (a, b) => state.currentPlayer == rootPlayer
              ? b.score.compareTo(a.score)
              : a.score.compareTo(b.score),
        );
    return entries.map((entry) => entry.move).toList();
  }

  GameState _advanceForSearch(GameState state, GameMove move) {
    final mover = state.currentPlayer;
    var points = 0;
    for (final id in move.captures) {
      final captured = _engine.pieceById(state, id);
      if (captured != null && captured.player != mover) {
        points += captured.type.pointValue;
      }
    }
    final moved = _engine.simulateMove(state, move);
    final scores = <int, int>{1: state.scores[1] ?? 0, 2: state.scores[2] ?? 0};
    scores[mover] = (scores[mover] ?? 0) + points;
    return moved.copyWith(
      currentPlayer: _engine.otherPlayer(mover),
      scores: scores,
      moveNumber: state.moveNumber + 1,
      halfmoveClock: move.isCapture ? 0 : state.halfmoveClock + 1,
      lastMove: LastMoveSummary(move: move, mover: mover, pointsGained: points),
    );
  }
}

class _RankedMove {
  const _RankedMove(this.move, this.score);

  final GameMove move;
  final double score;
}

class _SearchResult {
  const _SearchResult(this.move, this.score);

  final GameMove? move;
  final double score;
}

class _SearchEntry {
  const _SearchEntry(this.score, this.bound);
  final double score;
  // -1: upper bound, 0: exact, 1: lower bound.
  final int bound;
}
