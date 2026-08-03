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
  final Map<String, double> _transposition = <String, double>{};
  late int _timeLimitMs;
  var _nodes = 0;

  GameMove? choose(GameState state) {
    final legal = _engine.allLegalMoves(state, rootPlayer);
    if (legal.isEmpty) return null;
    if (difficulty == AiDifficulty.easy) return _easyMove(state, legal);

    _timeLimitMs = difficulty == AiDifficulty.hard ? 1400 : 450;
    final maxDepth = difficulty == AiDifficulty.hard ? 4 : 2;
    _clock.start();
    GameMove? best = legal.first;

    try {
      for (var depth = 1; depth <= maxDepth; depth += 1) {
        final result = _searchRoot(state, depth);
        if (result.move != null) best = result.move;
      }
    } on _SearchTimeout {
      // Keep the strongest fully or partially completed result.
    }
    return best;
  }

  void _checkTime() {
    _nodes += 1;
    if ((_nodes & 127) == 0 && _clock.elapsedMilliseconds >= _timeLimitMs) {
      throw const _SearchTimeout();
    }
  }

  GameMove _easyMove(GameState state, List<GameMove> legal) {
    final ranked = legal.map((move) {
      final child = _advanceForSearch(state, move);
      final instant =
          _engine.crossFor(child, _engine.otherPlayer(rootPlayer)) == null;
      final centre = 8 - ((move.toRow - 4).abs() + (move.toCol - 4).abs());
      final checkBonus =
          !instant && _engine.isInCheck(child, _engine.otherPlayer(rootPlayer))
          ? 180
          : 0;
      return _RankedMove(
        move,
        instant
            ? mateScore
            : _capturedMaterial(state, move) * 110 +
                  checkBonus +
                  centre * 6 +
                  (_random.nextDouble() - 0.5) * 520,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.first.score >= mateScore / 2) return ranked.first.move;
    final poolSize = min(ranked.length, max(3, (ranked.length * 0.38).ceil()));
    return ranked[_random.nextInt(poolSize)].move;
  }

  _SearchResult _searchRoot(GameState state, int depth) {
    final moves = _orderedMoves(
      state,
      _engine.allLegalMoves(state, rootPlayer),
    );
    var bestScore = double.negativeInfinity;
    final bestMoves = <GameMove>[];

    for (final move in moves) {
      _checkTime();
      final child = _advanceForSearch(state, move);
      final score = _minimax(
        child,
        depth - 1,
        double.negativeInfinity,
        double.infinity,
        1,
      );
      if (score > bestScore + 0.001) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if ((score - bestScore).abs() <= 0.001) {
        bestMoves.add(move);
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
    if (depth <= 0) return _evaluate(state);

    final key = '${_engine.positionKey(state)}|$depth|$rootPlayer';
    final cached = _transposition[key];
    if (cached != null) return cached;

    final maximizing = state.currentPlayer == rootPlayer;
    var best = maximizing ? double.negativeInfinity : double.infinity;
    var localAlpha = alpha;
    var localBeta = beta;
    var cutoff = false;

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
        cutoff = true;
        break;
      }
    }
    if (!cutoff) _transposition[key] = best;
    return best;
  }

  double? _terminalScore(GameState state, int ply, List<GameMove> knownMoves) {
    final rootCross = _engine.crossFor(state, rootPlayer);
    final enemyCross = _engine.crossFor(state, _engine.otherPlayer(rootPlayer));
    if (rootCross == null) return -mateScore + ply;
    if (enemyCross == null) return mateScore - ply;
    if (_engine.onlyCrossesRemain(state) ||
        state.halfmoveClock >= CrossmateEngine.noCaptureLimit) {
      return 0;
    }
    if (knownMoves.isEmpty) {
      if (_engine.isInCheck(state, state.currentPlayer)) {
        return state.currentPlayer == rootPlayer
            ? -mateScore + ply
            : mateScore - ply;
      }
      return 0;
    }
    return null;
  }

  double _evaluate(GameState state) {
    final terminal = _terminalScore(
      state,
      0,
      _engine.allLegalMoves(state, state.currentPlayer),
    );
    if (terminal != null) return terminal;

    var score = 0.0;
    var rootMobility = 0;
    var enemyMobility = 0;
    for (final piece in state.pieces) {
      if (!piece.alive) continue;
      final sign = piece.player == rootPlayer ? 1.0 : -1.0;
      score += sign * piece.type.aiValue;
      final centre = 8 - ((piece.row - 4).abs() + (piece.col - 4).abs());
      if (piece.type != PieceType.cross && piece.type != PieceType.diamond) {
        score += sign * centre * 3;
      }
      if (piece.type == PieceType.circle) {
        final advancement = piece.player == 1 ? 7 - piece.row : piece.row - 1;
        score += sign * advancement * 11;
      }
      score += sign * _fieldInfluence(piece);
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

  int _fieldInfluence(Piece piece) {
    if (piece.type != PieceType.diamond) return 0;
    var score = 0;
    for (var row = piece.row - 1; row <= piece.row + 1; row += 1) {
      for (var col = piece.col - 1; col <= piece.col + 1; col += 1) {
        if (!_engine.inBounds(row, col) ||
            (row == piece.row && col == piece.col)) {
          continue;
        }
        score += 3;
        if (row >= 2 && row <= 6 && col >= 2 && col <= 6) score += 2;
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
    return entries.map((entry) => entry.move).toList(growable: false);
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
