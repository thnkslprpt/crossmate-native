import 'package:crossmate/game/engine.dart';
import 'package:crossmate/game/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Crossmate engine', () {
    final engine = CrossmateEngine();

    test('creates the complete 9x9 opening position', () {
      final state = engine.initialState(startingPlayer: 1);
      expect(state.pieces.where((piece) => piece.alive), hasLength(32));
      expect(
        state.pieces.where(
          (piece) => piece.player == 1 && piece.type == PieceType.circle,
        ),
        hasLength(9),
      );
      expect(
        state.pieces.where(
          (piece) => piece.player == 2 && piece.type == PieceType.circle,
        ),
        hasLength(9),
      );
      expect(engine.crossFor(state, 1)?.col, 4);
      expect(engine.crossFor(state, 2)?.col, 4);
      expect(state.currentPlayer, 1);
    });

    test('cross stops after its first capture', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 4, col: 0),
        const Piece(
          id: 'c2',
          type: PieceType.circle,
          player: 2,
          row: 4,
          col: 1,
        ),
        const Piece(
          id: 's2',
          type: PieceType.square,
          player: 2,
          row: 4,
          col: 2,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 8, col: 8),
      ]);
      final cross = engine.pieceById(state, 'x1')!;
      // Inspect pseudo-moves here so this test isolates the Cross movement
      // rule from the separate rule that a Cross may not move into check.
      final pseudo = engine.pseudoMovesForPiece(state, cross);
      expect(
        pseudo.any(
          (move) =>
              move.toRow == 4 &&
              move.toCol == 1 &&
              move.captures.contains('c2'),
        ),
        isTrue,
      );
      expect(pseudo.any((move) => move.toRow == 4 && move.toCol == 2), isFalse);
    });

    test('square can jump one ordinary enemy without capturing it', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 8, col: 0),
        const Piece(
          id: 'square1',
          type: PieceType.square,
          player: 1,
          row: 4,
          col: 0,
        ),
        const Piece(
          id: 'first',
          type: PieceType.circle,
          player: 2,
          row: 4,
          col: 2,
        ),
        const Piece(
          id: 'second',
          type: PieceType.triangle,
          player: 2,
          row: 4,
          col: 4,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 8),
      ]);
      final square = engine.pieceById(state, 'square1')!;
      final legal = engine.legalMovesForPiece(state, square);

      expect(
        legal.any(
          (move) =>
              move.toRow == 4 &&
              move.toCol == 2 &&
              move.captures.contains('first'),
        ),
        isTrue,
      );
      expect(
        legal.any(
          (move) =>
              move.toRow == 4 &&
              move.toCol == 3 &&
              move.jumped &&
              move.captures.isEmpty,
        ),
        isTrue,
      );
      expect(
        legal.any(
          (move) =>
              move.toRow == 4 &&
              move.toCol == 4 &&
              move.jumped &&
              move.captures.length == 1 &&
              move.captures.single == 'second',
        ),
        isTrue,
      );
    });

    test('square cannot capture the cross after a jump', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 8, col: 0),
        const Piece(
          id: 'square1',
          type: PieceType.square,
          player: 1,
          row: 4,
          col: 0,
        ),
        const Piece(
          id: 'screen',
          type: PieceType.circle,
          player: 2,
          row: 4,
          col: 2,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 4, col: 4),
      ]);
      final square = engine.pieceById(state, 'square1')!;
      final legal = engine.legalMovesForPiece(state, square);
      expect(
        legal.any(
          (move) =>
              move.toRow == 4 &&
              move.toCol == 4 &&
              move.captures.contains('x2'),
        ),
        isFalse,
      );
    });

    test('a cross can be checked inside its own diamond field', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 4, col: 4),
        const Piece(
          id: 'd1',
          type: PieceType.diamond,
          player: 1,
          row: 5,
          col: 4,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 1, col: 4),
      ]);
      expect(engine.isForcefieldSquare(state, 1, 4, 4), isTrue);
      expect(engine.isInCheck(state, 1), isTrue);
    });

    test('far-edge circle sacrifices itself and removes a chosen target', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 8, col: 4),
        const Piece(
          id: 'circle1',
          type: PieceType.circle,
          player: 1,
          row: 1,
          col: 0,
        ),
        const Piece(
          id: 'target',
          type: PieceType.square,
          player: 2,
          row: 6,
          col: 6,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 4),
      ]);
      final circle = engine.pieceById(state, 'circle1')!;
      final legal = engine.legalMovesForPiece(state, circle);
      final blast = legal.singleWhere(
        (move) =>
            move.toRow == 0 &&
            move.toCol == 0 &&
            move.destroyTargetId == 'target',
      );
      expect(blast.selfDestruct, isTrue);
      final next = engine.advance(state, blast);
      expect(engine.pieceById(next, 'circle1')?.alive, isFalse);
      expect(engine.pieceById(next, 'target')?.alive, isFalse);
      expect(next.scores[1], 5);
    });

    test('far-edge circle remains when no legal sacrifice target exists', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 8, col: 4),
        const Piece(
          id: 'circle1',
          type: PieceType.circle,
          player: 1,
          row: 1,
          col: 0,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 4),
      ]);
      final circle = engine.pieceById(state, 'circle1')!;
      final edgeMove = engine
          .legalMovesForPiece(state, circle)
          .singleWhere((move) => move.toRow == 0 && move.toCol == 0);
      expect(edgeMove.edgeFallback, isTrue);
      expect(edgeMove.selfDestruct, isFalse);
    });

    test('a cross may enter its own diamond forcefield', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 4, col: 4),
        const Piece(
          id: 'd1',
          type: PieceType.diamond,
          player: 1,
          row: 5,
          col: 5,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 0),
      ]);
      final cross = engine.pieceById(state, 'x1')!;
      final legal = engine.legalMovesForPiece(state, cross);
      expect(engine.isForcefieldSquare(state, 1, 4, 5), isTrue);
      expect(legal.any((move) => move.toRow == 4 && move.toCol == 5), isTrue);
    });

    test('draws immediately when only the two crosses remain', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 4, col: 4),
        const Piece(
          id: 'last',
          type: PieceType.circle,
          player: 2,
          row: 4,
          col: 5,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 8, col: 8),
      ]);
      final move = engine
          .legalMovesForPiece(state, engine.pieceById(state, 'x1')!)
          .singleWhere((candidate) => candidate.captures.contains('last'));
      final next = engine.advance(state, move);
      expect(next.gameOver, isTrue);
      expect(next.result?.isDraw, isTrue);
      expect(next.result?.reason, contains('Only the two crosses'));
    });

    test('draws after 60 consecutive player moves without a capture', () {
      final state = _state(<Piece>[
        const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 8, col: 0),
        const Piece(
          id: 'circle1',
          type: PieceType.circle,
          player: 1,
          row: 4,
          col: 4,
        ),
        const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 8),
      ], halfmoveClock: 59);
      final circle = engine.pieceById(state, 'circle1')!;
      final move = engine
          .legalMovesForPiece(state, circle)
          .singleWhere(
            (candidate) => candidate.toRow == 3 && candidate.toCol == 4,
          );
      final next = engine.advance(state, move);
      expect(next.gameOver, isTrue);
      expect(next.result?.isDraw, isTrue);
      expect(next.result?.reason, contains('60 consecutive player moves'));
    });

    test('round-trips game state JSON', () {
      final state = engine.initialState(startingPlayer: 2);
      final decoded = GameState.decode(state.encode());
      expect(decoded.currentPlayer, 2);
      expect(decoded.pieces, hasLength(state.pieces.length));
      expect(engine.positionKey(decoded), engine.positionKey(state));
    });
  });
}

GameState _state(
  List<Piece> pieces, {
  int currentPlayer = 1,
  int halfmoveClock = 0,
}) {
  final state = GameState(
    pieces: pieces,
    currentPlayer: currentPlayer,
    halfmoveClock: halfmoveClock,
    positionCounts: const <String, int>{},
    gameOver: false,
    result: null,
    scores: const <int, int>{1: 0, 2: 0},
    lastMove: null,
    moveNumber: 0,
  );
  final engine = CrossmateEngine();
  final key = engine.positionKey(state);
  return state.copyWith(positionCounts: <String, int>{key: 1});
}
