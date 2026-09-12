import 'dart:math';

import 'models.dart';

class BoardVector {
  const BoardVector(this.dr, this.dc);

  final int dr;
  final int dc;
}

class CrossmateEngine {
  CrossmateEngine({Random? random}) : _random = random ?? Random();

  static const int noCaptureLimit = 60;
  static const List<BoardVector> cardinalDirections = <BoardVector>[
    BoardVector(-1, 0),
    BoardVector(0, 1),
    BoardVector(1, 0),
    BoardVector(0, -1),
  ];
  static const List<BoardVector> allDirections = <BoardVector>[
    BoardVector(-1, 0),
    BoardVector(1, 0),
    BoardVector(0, -1),
    BoardVector(0, 1),
    BoardVector(-1, -1),
    BoardVector(-1, 1),
    BoardVector(1, -1),
    BoardVector(1, 1),
  ];
  static const List<PieceType?> backRow = <PieceType?>[
    PieceType.diamond,
    PieceType.square,
    PieceType.triangle,
    null,
    PieceType.cross,
    null,
    PieceType.triangle,
    PieceType.square,
    PieceType.diamond,
  ];

  final Random _random;

  GameState initialState({int? startingPlayer, int boardSize = 9}) {
    if (boardSize != 7 && boardSize != 9) {
      throw ArgumentError.value(boardSize, 'boardSize', 'Must be 7 or 9');
    }
    final size = boardSize;
    final formation = size == 7
        ? backRow.whereType<PieceType>().toList()
        : backRow;
    final pieces = <Piece>[];
    var id = 1;

    for (var col = 0; col < size; col += 1) {
      final backPiece = formation[col];
      if (backPiece != null) {
        pieces.add(
          Piece(
            id: 'p$id',
            type: backPiece,
            player: 2,
            row: 0,
            col: col,
            facing: backPiece == PieceType.triangle ? 2 : 0,
          ),
        );
        id += 1;
      }
      pieces.add(
        Piece(
          id: 'p$id',
          type: PieceType.circle,
          player: 2,
          row: 1,
          col: col,
          facing: 2,
        ),
      );
      id += 1;
      pieces.add(
        Piece(
          id: 'p$id',
          type: PieceType.circle,
          player: 1,
          row: size - 2,
          col: col,
          facing: 0,
        ),
      );
      id += 1;
      if (backPiece != null) {
        pieces.add(
          Piece(
            id: 'p$id',
            type: backPiece,
            player: 1,
            row: size - 1,
            col: col,
            facing: 0,
          ),
        );
        id += 1;
      }
    }

    final player = startingPlayer == 1 || startingPlayer == 2
        ? startingPlayer!
        : (_random.nextBool() ? 1 : 2);
    var state = GameState(
      boardSize: boardSize,
      pieces: pieces,
      currentPlayer: player,
      halfmoveClock: 0,
      positionCounts: const <String, int>{},
      gameOver: false,
      result: null,
      scores: const <int, int>{1: 0, 2: 0},
      lastMove: null,
      moveNumber: 0,
    );
    final key = positionKey(state);
    state = state.copyWith(positionCounts: <String, int>{key: 1});
    return state;
  }

  int otherPlayer(int player) => player == 1 ? 2 : 1;

  bool inBounds(GameState state, int row, int col) =>
      row >= 0 && row < state.boardSize && col >= 0 && col < state.boardSize;

  int mod4(int value) => (value % 4 + 4) % 4;

  bool isAdjacent(int row1, int col1, int row2, int col2) =>
      max((row1 - row2).abs(), (col1 - col2).abs()) == 1;

  Piece? pieceAt(GameState state, int row, int col) {
    for (final piece in state.pieces) {
      if (piece.alive && piece.row == row && piece.col == col) return piece;
    }
    return null;
  }

  Piece? pieceById(GameState state, String id) {
    for (final piece in state.pieces) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  Piece? crossFor(GameState state, int player) {
    for (final piece in state.pieces) {
      if (piece.alive &&
          piece.player == player &&
          piece.type == PieceType.cross) {
        return piece;
      }
    }
    return null;
  }

  bool isForcefieldSquare(
    GameState state,
    int owner,
    int row,
    int col, {
    String? ignoredDiamondId,
    int? transparentForcefieldPlayer,
  }) {
    if (transparentForcefieldPlayer == owner) return false;
    for (final piece in state.pieces) {
      if (piece.alive &&
          piece.player == owner &&
          piece.type == PieceType.diamond &&
          piece.id != ignoredDiamondId &&
          isAdjacent(piece.row, piece.col, row, col)) {
        return true;
      }
    }
    return false;
  }

  bool isEnemyForcefield(
    GameState state,
    int player,
    int row,
    int col, {
    String? ignoredDiamondId,
    int? transparentForcefieldPlayer,
  }) {
    return isForcefieldSquare(
      state,
      otherPlayer(player),
      row,
      col,
      ignoredDiamondId: ignoredDiamondId,
      transparentForcefieldPlayer: transparentForcefieldPlayer,
    );
  }

  bool diamondCanCreateField(GameState state, Piece diamond, int row, int col) {
    if (pieceAt(state, row, col) != null) return false;
    if (isEnemyForcefield(state, diamond.player, row, col)) return false;

    for (final piece in state.pieces) {
      if (!piece.alive || piece.id == diamond.id) continue;
      if (isAdjacent(row, col, piece.row, piece.col) &&
          piece.player != diamond.player) {
        return false;
      }
    }
    return true;
  }

  GameMove _move(
    Piece piece,
    int toRow,
    int toCol, {
    List<String> captures = const <String>[],
    int? newFacing,
    int? landingRow,
    int? landingCol,
    int distance = 0,
    int turn = 0,
    int preTurn = 0,
    int? travelFacing,
    bool jumped = false,
    bool diamondCapture = false,
    bool edgeBlast = false,
    String? destroyTargetId,
    bool selfDestruct = false,
    String? arrivalKey,
    bool edgeFallback = false,
  }) {
    return GameMove(
      pieceId: piece.id,
      player: piece.player,
      type: piece.type,
      fromRow: piece.row,
      fromCol: piece.col,
      toRow: toRow,
      toCol: toCol,
      captures: List<String>.unmodifiable(captures),
      newFacing: newFacing ?? piece.facing,
      landingRow: landingRow ?? toRow,
      landingCol: landingCol ?? toCol,
      distance: distance,
      turn: turn,
      preTurn: preTurn,
      travelFacing: travelFacing ?? piece.facing,
      jumped: jumped,
      diamondCapture: diamondCapture,
      edgeBlast: edgeBlast,
      destroyTargetId: destroyTargetId,
      selfDestruct: selfDestruct,
      arrivalKey: arrivalKey,
      edgeFallback: edgeFallback,
    );
  }

  void _addCircleArrivalMoves(
    GameState state,
    Piece piece,
    GameMove baseMove,
    List<GameMove> moves,
  ) {
    final arrivalKey = <Object>[
      piece.id,
      baseMove.toRow,
      baseMove.toCol,
      baseMove.captures.join(','),
    ].join(':');
    final targets = state.pieces.where((candidate) {
      return candidate.alive &&
          candidate.player != piece.player &&
          candidate.type != PieceType.cross &&
          !baseMove.captures.contains(candidate.id);
    });

    for (final target in targets) {
      moves.add(
        _move(
          piece,
          baseMove.toRow,
          baseMove.toCol,
          captures: <String>[...baseMove.captures, target.id],
          distance: baseMove.distance,
          edgeBlast: true,
          destroyTargetId: target.id,
          selfDestruct: true,
          arrivalKey: arrivalKey,
        ),
      );
    }
    moves.add(
      _move(
        piece,
        baseMove.toRow,
        baseMove.toCol,
        captures: baseMove.captures,
        distance: baseMove.distance,
        edgeFallback: true,
        arrivalKey: arrivalKey,
      ),
    );
  }

  void _addCircleMove(
    GameState state,
    Piece piece,
    List<GameMove> moves,
    int toRow,
    int toCol, {
    List<String> captures = const <String>[],
    int distance = 0,
  }) {
    final baseMove = _move(
      piece,
      toRow,
      toCol,
      captures: captures,
      distance: distance,
    );
    final reachedFarEdge =
        (piece.player == 1 && toRow == 0) ||
        (piece.player == 2 && toRow == state.boardSize - 1);
    if (reachedFarEdge) {
      _addCircleArrivalMoves(state, piece, baseMove, moves);
    } else {
      moves.add(baseMove);
    }
  }

  List<GameMove> _circleMoves(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    for (final step in const <int>[-1, 1]) {
      for (var distance = 1; distance <= 2; distance += 1) {
        final row = piece.row + step * distance;
        if (!inBounds(state, row, piece.col)) break;
        if (isEnemyForcefield(
          state,
          piece.player,
          row,
          piece.col,
          transparentForcefieldPlayer: transparentForcefieldPlayer,
        )) {
          break;
        }
        if (pieceAt(state, row, piece.col) != null) break;
        _addCircleMove(state, piece, moves, row, piece.col, distance: distance);
      }
    }

    final forward = piece.player == 1 ? -1 : 1;
    for (final dc in const <int>[-1, 1]) {
      final row = piece.row + forward;
      final col = piece.col + dc;
      if (!inBounds(state, row, col) ||
          isEnemyForcefield(
            state,
            piece.player,
            row,
            col,
            transparentForcefieldPlayer: transparentForcefieldPlayer,
          )) {
        continue;
      }
      final occupant = pieceAt(state, row, col);
      if (occupant != null &&
          occupant.player != piece.player &&
          occupant.type != PieceType.diamond) {
        _addCircleMove(
          state,
          piece,
          moves,
          row,
          col,
          captures: <String>[occupant.id],
          distance: 1,
        );
      }
    }
    return moves;
  }

  List<GameMove> _diamondMoves(GameState state, Piece piece) {
    final moves = <GameMove>[];
    for (final direction in allDirections) {
      final row = piece.row + direction.dr;
      final col = piece.col + direction.dc;
      if (inBounds(state, row, col) &&
          diamondCanCreateField(state, piece, row, col)) {
        moves.add(_move(piece, row, col, distance: 1));
      }
    }
    return moves;
  }

  List<GameMove> _triangleMoves(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    final direction = cardinalDirections[piece.facing];
    final frontRow = piece.row + direction.dr;
    final frontCol = piece.col + direction.dc;
    final front = pieceAt(state, frontRow, frontCol);

    for (final turn in const <int>[-1, 1, 2]) {
      moves.add(
        _move(
          piece,
          piece.row,
          piece.col,
          newFacing: mod4(piece.facing + turn),
          turn: turn,
        ),
      );
    }
    if (inBounds(state, frontRow, frontCol) &&
        front == null &&
        !isEnemyForcefield(
          state,
          piece.player,
          frontRow,
          frontCol,
          transparentForcefieldPlayer: transparentForcefieldPlayer,
        )) {
      moves.add(_move(piece, frontRow, frontCol, distance: 1));
    }

    void addCapture(int row, int col, {bool clearFront = false}) {
      if (!inBounds(state, row, col)) return;
      final target = pieceAt(state, row, col);
      if (target == null || target.player == piece.player) return;
      if (clearFront && front != null) return;
      final ignored = target.type == PieceType.diamond ? target.id : null;
      if (clearFront &&
          isEnemyForcefield(
            state,
            piece.player,
            frontRow,
            frontCol,
            ignoredDiamondId: ignored,
            transparentForcefieldPlayer: transparentForcefieldPlayer,
          )) {
        return;
      }
      if (isEnemyForcefield(
        state,
        piece.player,
        row,
        col,
        ignoredDiamondId: ignored,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      )) {
        return;
      }
      moves.add(
        _move(
          piece,
          row,
          col,
          captures: <String>[target.id],
          diamondCapture: target.type == PieceType.diamond,
        ),
      );
    }

    addCapture(frontRow, frontCol);
    addCapture(frontRow - direction.dc, frontCol + direction.dr);
    addCapture(frontRow + direction.dc, frontCol - direction.dr);
    addCapture(
      piece.row + direction.dr * 2,
      piece.col + direction.dc * 2,
      clearFront: true,
    );
    return moves;
  }

  List<GameMove> _specialSquareDiamondCaptures(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    for (final target in state.pieces) {
      if (!target.alive ||
          target.player == piece.player ||
          target.type != PieceType.diamond) {
        continue;
      }
      if (target.row != piece.row && target.col != piece.col) continue;

      final dr = target.row == piece.row
          ? 0
          : (target.row > piece.row ? 1 : -1);
      final dc = target.col == piece.col
          ? 0
          : (target.col > piece.col ? 1 : -1);
      final distance = max(
        (target.row - piece.row).abs(),
        (target.col - piece.col).abs(),
      );
      var jumped = false;
      var blocked = false;

      for (var step = 1; step < distance; step += 1) {
        final row = piece.row + dr * step;
        final col = piece.col + dc * step;
        if (isEnemyForcefield(
          state,
          piece.player,
          row,
          col,
          ignoredDiamondId: target.id,
          transparentForcefieldPlayer: transparentForcefieldPlayer,
        )) {
          blocked = true;
          break;
        }
        final occupant = pieceAt(state, row, col);
        if (occupant == null) continue;
        if (occupant.player == piece.player ||
            occupant.type == PieceType.cross ||
            jumped) {
          blocked = true;
          break;
        }
        jumped = true;
      }
      if (!blocked) {
        moves.add(
          _move(
            piece,
            target.row,
            target.col,
            captures: <String>[target.id],
            distance: distance,
            jumped: jumped,
            diamondCapture: true,
          ),
        );
      }
    }
    return moves;
  }

  List<GameMove> _squareMoves(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    for (final direction in cardinalDirections) {
      var jumped = false;
      for (var distance = 1; distance < state.boardSize; distance += 1) {
        final row = piece.row + direction.dr * distance;
        final col = piece.col + direction.dc * distance;
        if (!inBounds(state, row, col)) break;
        if (isEnemyForcefield(
          state,
          piece.player,
          row,
          col,
          transparentForcefieldPlayer: transparentForcefieldPlayer,
        )) {
          break;
        }
        final occupant = pieceAt(state, row, col);
        if (occupant == null) {
          moves.add(_move(piece, row, col, distance: distance, jumped: jumped));
          continue;
        }
        if (occupant.player == piece.player ||
            occupant.type == PieceType.diamond) {
          break;
        }
        if (occupant.type == PieceType.cross && jumped) break;

        moves.add(
          _move(
            piece,
            row,
            col,
            captures: <String>[occupant.id],
            distance: distance,
            jumped: jumped,
          ),
        );
        if (!jumped && occupant.type != PieceType.cross) {
          jumped = true;
          continue;
        }
        break;
      }
    }
    moves.addAll(
      _specialSquareDiamondCaptures(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
    );
    return _deduplicate(moves);
  }

  List<GameMove> _specialCrossDiamondCaptures(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    for (final target in state.pieces) {
      if (!target.alive ||
          target.player == piece.player ||
          target.type != PieceType.diamond) {
        continue;
      }
      var dr = target.row - piece.row;
      var dc = target.col - piece.col;
      final distance = max(dr.abs(), dc.abs());
      if (distance < 1 || distance > 3) continue;
      if (!(dr == 0 || dc == 0 || dr.abs() == dc.abs())) continue;
      dr = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
      dc = dc == 0 ? 0 : (dc > 0 ? 1 : -1);

      var blocked = isEnemyForcefield(
        state,
        piece.player,
        target.row,
        target.col,
        ignoredDiamondId: target.id,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      );
      for (var step = 1; !blocked && step < distance; step += 1) {
        final row = piece.row + dr * step;
        final col = piece.col + dc * step;
        if (isEnemyForcefield(
              state,
              piece.player,
              row,
              col,
              ignoredDiamondId: target.id,
              transparentForcefieldPlayer: transparentForcefieldPlayer,
            ) ||
            pieceAt(state, row, col) != null) {
          blocked = true;
        }
      }
      if (!blocked) {
        moves.add(
          _move(
            piece,
            target.row,
            target.col,
            captures: <String>[target.id],
            distance: distance,
            diamondCapture: true,
          ),
        );
      }
    }
    return moves;
  }

  List<GameMove> _crossMoves(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    final moves = <GameMove>[];
    for (final direction in allDirections) {
      for (var distance = 1; distance <= 3; distance += 1) {
        final row = piece.row + direction.dr * distance;
        final col = piece.col + direction.dc * distance;
        if (!inBounds(state, row, col) ||
            isEnemyForcefield(
              state,
              piece.player,
              row,
              col,
              transparentForcefieldPlayer: transparentForcefieldPlayer,
            )) {
          break;
        }
        final occupant = pieceAt(state, row, col);
        if (occupant != null && occupant.player == piece.player) break;
        if (occupant != null && occupant.type == PieceType.diamond) break;
        if (occupant != null) {
          moves.add(
            _move(
              piece,
              row,
              col,
              captures: <String>[occupant.id],
              distance: distance,
            ),
          );
          break;
        }
        moves.add(_move(piece, row, col, distance: distance));
      }
    }
    moves.addAll(
      _specialCrossDiamondCaptures(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
    );
    return _deduplicate(moves);
  }

  List<GameMove> pseudoMovesForPiece(
    GameState state,
    Piece piece, {
    int? transparentForcefieldPlayer,
  }) {
    if (!piece.alive) return const <GameMove>[];
    return switch (piece.type) {
      PieceType.circle => _circleMoves(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
      PieceType.diamond => _diamondMoves(state, piece),
      PieceType.triangle => _triangleMoves(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
      PieceType.square => _squareMoves(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
      PieceType.cross => _crossMoves(
        state,
        piece,
        transparentForcefieldPlayer: transparentForcefieldPlayer,
      ),
    };
  }

  GameState simulateMove(GameState state, GameMove move) {
    return state.copyWith(pieces: _applyToPieces(state.pieces, move));
  }

  List<Piece> _applyToPieces(List<Piece> pieces, GameMove move) {
    final captured = move.captures.toSet();
    return pieces
        .map((piece) {
          if (captured.contains(piece.id)) return piece.copyWith(alive: false);
          if (piece.id != move.pieceId || !piece.alive) return piece;
          return piece.copyWith(
            row: move.toRow,
            col: move.toCol,
            facing: move.newFacing,
            alive: !move.selfDestruct,
          );
        })
        .toList(growable: false);
  }

  bool isSquareAttacked(GameState state, int row, int col, int byPlayer) {
    final target = pieceAt(state, row, col);
    if (target == null) return false;
    final transparentOwner = target.type == PieceType.cross
        ? target.player
        : null;
    for (final piece in state.pieces) {
      if (!piece.alive || piece.player != byPlayer) continue;
      final moves = pseudoMovesForPiece(
        state,
        piece,
        transparentForcefieldPlayer: transparentOwner,
      );
      if (moves.any((move) => move.captures.contains(target.id))) return true;
    }
    return false;
  }

  bool isInCheck(GameState state, int player) {
    final cross = crossFor(state, player);
    if (cross == null) return true;
    return isSquareAttacked(state, cross.row, cross.col, otherPlayer(player));
  }

  List<Piece> attackersOfCross(GameState state, int player) {
    final cross = crossFor(state, player);
    if (cross == null) return const <Piece>[];
    final attackers = <Piece>[];
    for (final piece in state.pieces) {
      if (!piece.alive || piece.player == player) continue;
      final moves = pseudoMovesForPiece(
        state,
        piece,
        transparentForcefieldPlayer: player,
      );
      if (moves.any((move) => move.captures.contains(cross.id))) {
        attackers.add(piece);
      }
    }
    return attackers;
  }

  List<GameMove> legalMovesForPiece(GameState state, Piece piece) {
    if (!piece.alive) return const <GameMove>[];
    var pseudo = pseudoMovesForPiece(state, piece).toList();
    final enemyCross = crossFor(state, otherPlayer(piece.player));

    if (enemyCross != null) {
      final hasDefendingDiamond = state.pieces.any(
        (candidate) =>
            candidate.alive &&
            candidate.player == enemyCross.player &&
            candidate.type == PieceType.diamond,
      );
      final deltaRow = (enemyCross.row - piece.row).abs();
      final deltaCol = (enemyCross.col - piece.col).abs();
      final couldReachCross = switch (piece.type) {
        PieceType.circle =>
          deltaCol == 1 &&
              enemyCross.row - piece.row == (piece.player == 1 ? -1 : 1),
        PieceType.square => deltaRow == 0 || deltaCol == 0,
        PieceType.triangle =>
          deltaRow + deltaCol > 0 && deltaRow + deltaCol <= 3,
        PieceType.cross =>
          max(deltaRow, deltaCol) > 0 &&
              max(deltaRow, deltaCol) <= 3 &&
              (deltaRow == 0 || deltaCol == 0 || deltaRow == deltaCol),
        PieceType.diamond => false,
      };
      if (hasDefendingDiamond && couldReachCross) {
        final known = pseudo.map((move) => move.signature).toSet();
        final transparentMoves = pseudoMovesForPiece(
          state,
          piece,
          transparentForcefieldPlayer: enemyCross.player,
        );
        for (final move in transparentMoves) {
          if (move.captures.contains(enemyCross.id) &&
              known.add(move.signature)) {
            pseudo.add(move);
          }
        }
      }
    }

    final legal = <GameMove>[];
    final legalBlastArrivals = <String>{};
    for (final move in pseudo) {
      final next = simulateMove(state, move);
      final ownCross = crossFor(next, piece.player);
      if (ownCross != null &&
          !isSquareAttacked(
            next,
            ownCross.row,
            ownCross.col,
            otherPlayer(piece.player),
          )) {
        legal.add(move);
        if (move.edgeBlast && move.arrivalKey != null) {
          legalBlastArrivals.add(move.arrivalKey!);
        }
      }
    }
    return _deduplicate(
      legal.where((move) {
        return !(move.edgeFallback &&
            move.arrivalKey != null &&
            legalBlastArrivals.contains(move.arrivalKey));
      }),
    );
  }

  List<GameMove> allLegalMoves(GameState state, int player) {
    final result = <GameMove>[];
    for (final piece in state.pieces) {
      if (piece.alive && piece.player == player) {
        result.addAll(legalMovesForPiece(state, piece));
      }
    }
    return result;
  }

  GameMove? canonicalMove(GameState state, GameMove proposed) {
    final piece = pieceById(state, proposed.pieceId);
    if (piece == null || !piece.alive || piece.player != state.currentPlayer) {
      return null;
    }
    for (final legal in legalMovesForPiece(state, piece)) {
      if (legal.signature == proposed.signature) return legal;
    }
    return null;
  }

  GameState advance(GameState state, GameMove proposed) {
    if (state.gameOver) return state;
    final move = canonicalMove(state, proposed);
    if (move == null) {
      throw StateError('Attempted to play a non-legal Crossmate move');
    }

    final mover = state.currentPlayer;
    var capturedCross = false;
    var points = 0;
    for (final capturedId in move.captures) {
      final capturedPiece = pieceById(state, capturedId);
      if (capturedPiece == null || capturedPiece.player == mover) continue;
      if (capturedPiece.type == PieceType.cross) capturedCross = true;
      points += capturedPiece.type.pointValue;
    }

    final nextScores = <int, int>{
      1: state.scores[1] ?? 0,
      2: state.scores[2] ?? 0,
    };
    nextScores[mover] = (nextScores[mover] ?? 0) + points;
    final movedPieces = _applyToPieces(state.pieces, move);
    final summary = LastMoveSummary(
      move: move,
      mover: mover,
      pointsGained: points,
    );

    if (capturedCross) {
      return state.copyWith(
        pieces: movedPieces,
        scores: nextScores,
        halfmoveClock: move.isCapture ? 0 : state.halfmoveClock + 1,
        moveNumber: state.moveNumber + 1,
        lastMove: summary,
        gameOver: true,
        result: GameResult(
          type: 'win',
          winner: mover,
          reason: 'The opposing cross was captured.',
        ),
      );
    }

    var next = state.copyWith(
      pieces: movedPieces,
      currentPlayer: otherPlayer(mover),
      scores: nextScores,
      halfmoveClock: move.isCapture ? 0 : state.halfmoveClock + 1,
      moveNumber: state.moveNumber + 1,
      lastMove: summary,
      gameOver: false,
      clearResult: true,
    );
    final key = positionKey(next);
    final counts = Map<String, int>.from(state.positionCounts);
    counts[key] = (counts[key] ?? 0) + 1;
    next = next.copyWith(positionCounts: counts);

    final nextMoves = allLegalMoves(next, next.currentPlayer);
    GameResult? result;
    if (nextMoves.isEmpty) {
      result = GameResult(
        type: 'win',
        winner: mover,
        reason: 'Crossmate — the opposing player has no legal move.',
      );
    } else if ((counts[key] ?? 0) >= 3) {
      result = const GameResult(
        type: 'draw',
        winner: 0,
        reason: 'The same full position occurred three times.',
      );
    } else if (next.halfmoveClock >= noCaptureLimit) {
      result = const GameResult(
        type: 'draw',
        winner: 0,
        reason: '60 consecutive player moves passed without a capture.',
      );
    }

    final alive = next.pieces.where((piece) => piece.alive).toList();
    if (result == null &&
        alive.length == 2 &&
        alive.every((piece) => piece.type == PieceType.cross) &&
        alive[0].player != alive[1].player) {
      result = const GameResult(
        type: 'draw',
        winner: 0,
        reason: 'Only the two crosses remain.',
      );
    }

    if (result != null) {
      next = next.copyWith(gameOver: true, result: result);
    }
    return next;
  }

  String positionKey(GameState state) {
    final pieces =
        state.pieces
            .where((piece) => piece.alive)
            .map(
              (piece) => <Object>[
                piece.player,
                piece.type.wireName,
                piece.row,
                piece.col,
                piece.type == PieceType.triangle ? piece.facing : 0,
              ].join(':'),
            )
            .toList()
          ..sort();
    return '${state.boardSize}|${state.currentPlayer}|${pieces.join('|')}';
  }

  bool onlyCrossesRemain(GameState state) {
    final alive = state.pieces.where((piece) => piece.alive).toList();
    return alive.length == 2 &&
        alive.every((piece) => piece.type == PieceType.cross) &&
        alive[0].player != alive[1].player;
  }

  String describeMove(GameState state, LastMoveSummary? summary) {
    if (summary == null) return '';
    final move = summary.move;
    final pieceName = move.type.displayName;
    final captureText = move.captures.isEmpty
        ? ''
        : ' captured ${move.captures.length} piece${move.captures.length == 1 ? '' : 's'}';
    final scoreText = summary.pointsGained > 0
        ? ' for ${summary.pointsGained} point${summary.pointsGained == 1 ? '' : 's'}'
        : '';
    return 'Player ${summary.mover} moved $pieceName$captureText$scoreText.';
  }

  List<GameMove> _deduplicate(Iterable<GameMove> moves) {
    final bySignature = <String, GameMove>{};
    for (final move in moves) {
      bySignature.putIfAbsent(move.signature, () => move);
    }
    return bySignature.values.toList(growable: false);
  }
}
