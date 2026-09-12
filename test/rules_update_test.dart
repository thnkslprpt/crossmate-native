import 'package:crossmate/game/ai.dart';
import 'package:crossmate/game/controller.dart';
import 'package:crossmate/game/engine.dart';
import 'package:crossmate/game/models.dart';
import 'package:crossmate/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState position(List<Piece> pieces, {int size = 9, int clock = 0}) =>
    GameState(
      boardSize: size,
      pieces: pieces,
      currentPlayer: 1,
      halfmoveClock: clock,
      positionCounts: const {},
      gameOver: false,
      result: null,
      scores: const {1: 0, 2: 0},
      lastMove: null,
      moveNumber: 0,
    );

void main() {
  final engine = CrossmateEngine();
  const triangle = Piece(
    id: 't',
    type: PieceType.triangle,
    player: 1,
    row: 4,
    col: 4,
  );
  const ownCross = Piece(
    id: 'x1',
    type: PieceType.cross,
    player: 1,
    row: 8,
    col: 0,
  );
  const enemyCross = Piece(
    id: 'x2',
    type: PieceType.cross,
    player: 2,
    row: 0,
    col: 8,
  );

  test('triangle has three standalone turns and one empty forward move', () {
    for (var facing = 0; facing < 4; facing++) {
      final piece = triangle.copyWith(facing: facing);
      final state = position([piece, ownCross, enemyCross]);
      final moves = engine.legalMovesForPiece(state, piece);
      expect(moves, hasLength(4));
      final turns = moves.where((m) => m.toRow == 4 && m.toCol == 4);
      expect(
        turns.map((m) => m.newFacing).toSet(),
        {0, 1, 2, 3}..remove(facing),
      );
      expect(turns.every((m) => m.captures.isEmpty), isTrue);
      final move = moves.singleWhere((m) => m.distance == 1);
      final direction = CrossmateEngine.cardinalDirections[facing];
      expect([move.toRow, move.toCol], [4 + direction.dr, 4 + direction.dc]);
      expect(move.newFacing, facing);
      expect(move.preTurn, 0);
      expect(move.turn, 0);
    }
  });

  test(
    'triangle captures only its four forward targets and retains facing',
    () {
      for (var facing = 0; facing < 4; facing++) {
        final piece = triangle.copyWith(facing: facing);
        final dir = CrossmateEngine.cardinalDirections[facing];
        final targets = {
          '${4 + dir.dr}:${4 + dir.dc}',
          '${4 + dir.dr - dir.dc}:${4 + dir.dc + dir.dr}',
          '${4 + dir.dr + dir.dc}:${4 + dir.dc - dir.dr}',
          '${4 + dir.dr * 2}:${4 + dir.dc * 2}',
        };
        for (var row = 1; row <= 7; row++) {
          for (var col = 1; col <= 7; col++) {
            if (row == 4 && col == 4) continue;
            final target = Piece(
              id: 'target',
              type: PieceType.circle,
              player: 2,
              row: row,
              col: col,
            );
            final state = position([piece, target, ownCross, enemyCross]);
            final captures = engine
                .pseudoMovesForPiece(state, piece)
                .where((m) => m.captures.contains('target'))
                .toList();
            expect(
              captures.isNotEmpty,
              targets.contains('$row:$col'),
              reason: 'facing $facing, target $row:$col',
            );
            for (final move in captures) {
              expect(move.newFacing, facing);
              expect([move.toRow, move.toCol], [row, col]);
            }
          }
        }
      }
    },
  );

  test('two-square triangle capture needs an empty front square', () {
    for (final owner in [1, 2]) {
      final state = position([
        triangle,
        ownCross,
        enemyCross,
        Piece(
          id: 'block',
          type: PieceType.circle,
          player: owner,
          row: 3,
          col: 4,
        ),
        const Piece(
          id: 'target',
          type: PieceType.square,
          player: 2,
          row: 2,
          col: 4,
        ),
      ]);
      expect(
        engine
            .pseudoMovesForPiece(state, triangle)
            .any((m) => m.captures.contains('target')),
        isFalse,
      );
    }
  });

  test('triangle destroys a diamond through its own field and scores six', () {
    final state = position([
      triangle,
      ownCross,
      enemyCross,
      const Piece(id: 'd', type: PieceType.diamond, player: 2, row: 2, col: 4),
    ]);
    final moves = engine.legalMovesForPiece(state, triangle);
    expect(moves.any((m) => m.toRow == 3 && m.toCol == 4), isFalse);
    final capture = moves.singleWhere((m) => m.captures.contains('d'));
    final next = engine.advance(state, capture);
    expect(engine.pieceById(next, 'd')!.alive, isFalse);
    expect(next.scores[1], 6);
    expect(engine.pieceById(next, 't')!.facing, 0);
  });

  test('other diamonds still shield the target diamond and capture path', () {
    for (final shieldRow in [1, 4]) {
      final state = position([
        triangle,
        ownCross,
        enemyCross,
        const Piece(
          id: 'd',
          type: PieceType.diamond,
          player: 2,
          row: 2,
          col: 4,
        ),
        Piece(
          id: 'shield',
          type: PieceType.diamond,
          player: 2,
          row: shieldRow,
          col: 5,
        ),
      ]);
      expect(
        engine
            .pseudoMovesForPiece(state, triangle)
            .any((m) => m.captures.contains('d')),
        isFalse,
      );
    }
  });

  test('triangle checks and captures a cross through its friendly field', () {
    final cross = enemyCross.copyWith(row: 2, col: 4);
    final state = position([
      triangle,
      ownCross,
      cross,
      const Piece(id: 'd', type: PieceType.diamond, player: 2, row: 2, col: 5),
    ]);
    expect(engine.isInCheck(state, 2), isTrue);
    final capture = engine
        .legalMovesForPiece(state, triangle)
        .singleWhere((m) => m.captures.contains('x2'));
    expect(engine.advance(state, capture).result!.winner, 1);
  });

  for (final checked in [false, true]) {
    test(
      'no legal moves loses with check=$checked, before the 60-move draw',
      () {
        final state = position(
          [
            const Piece(
              id: 'x1',
              type: PieceType.cross,
              player: 1,
              row: 6,
              col: 6,
            ),
            const Piece(
              id: 'x2',
              type: PieceType.cross,
              player: 2,
              row: 0,
              col: 0,
            ),
            const Piece(
              id: 'd1',
              type: PieceType.diamond,
              player: 1,
              row: 2,
              col: 1,
            ),
            const Piece(
              id: 'd2',
              type: PieceType.diamond,
              player: 1,
              row: 1,
              col: 2,
            ),
            const Piece(
              id: 'c',
              type: PieceType.circle,
              player: 1,
              row: 5,
              col: 4,
            ),
            if (checked)
              const Piece(
                id: 's',
                type: PieceType.square,
                player: 1,
                row: 0,
                col: 4,
              ),
          ],
          size: 7,
          clock: 59,
        );
        expect(engine.isInCheck(state, 2), checked);
        expect(engine.allLegalMoves(state, 2), isEmpty);
        final move = engine
            .legalMovesForPiece(state, engine.pieceById(state, 'c')!)
            .singleWhere((m) => m.toRow == 4);
        final next = engine.advance(state, move);
        expect(next.gameOver, isTrue);
        expect(next.result!.winner, 1);
        expect(next.result!.isDraw, isFalse);
      },
    );
  }

  test('7x7 setup, boundaries, serialization and position keys', () {
    final state = engine.initialState(boardSize: 7, startingPlayer: 1);
    expect(state.pieces, hasLength(28));
    expect(
      state.pieces.where((p) => p.type == PieceType.circle),
      hasLength(14),
    );
    expect(engine.crossFor(state, 1)!.col, 3);
    expect(engine.crossFor(state, 1)!.row, 6);
    expect(engine.crossFor(state, 2)!.row, 0);
    final decoded = GameState.decode(state.encode());
    expect(decoded.boardSize, 7);
    expect(engine.positionKey(decoded), engine.positionKey(state));
    final legacy = state.toJson()..remove('boardSize');
    expect(GameState.fromJson(legacy).boardSize, 9);
    for (final type in PieceType.values) {
      final piece = Piece(
        id: 'p',
        type: type,
        player: 1,
        row: 6,
        col: 6,
        facing: 2,
      );
      final edge = position([piece], size: 7);
      expect(
        engine
            .pseudoMovesForPiece(edge, piece)
            .every(
              (m) => m.toRow >= 0 && m.toRow < 7 && m.toCol >= 0 && m.toCol < 7,
            ),
        isTrue,
      );
    }
  });

  test('player two circle sacrifices at row six on 7x7', () {
    const circle = Piece(
      id: 'c',
      type: PieceType.circle,
      player: 2,
      row: 5,
      col: 0,
    );
    final state = position([
      circle,
      const Piece(id: 'x1', type: PieceType.cross, player: 1, row: 6, col: 6),
      const Piece(id: 'x2', type: PieceType.cross, player: 2, row: 0, col: 6),
      const Piece(
        id: 'target',
        type: PieceType.triangle,
        player: 1,
        row: 3,
        col: 3,
      ),
    ], size: 7).copyWith(currentPlayer: 2);
    final blast = engine
        .legalMovesForPiece(state, circle)
        .singleWhere((m) => m.toRow == 6);
    expect(blast.edgeBlast, isTrue);
    expect(engine.advance(state, blast).scores[2], 3);
  });

  test('board choice persists and local rematch keeps the size', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = CrossmateController();
    addTearDown(controller.dispose);
    await controller.setBoardSize(7);
    expect(await const SettingsService().loadBoardSize(), 7);
    await controller.startLocal(startingPlayer: 1);
    expect(controller.state!.boardSize, 7);
    await controller.restart();
    expect(controller.state!.boardSize, 7);
    expect(controller.state!.pieces, hasLength(28));
  });

  test(
    'robot returns a legal move on 7x7 at every difficulty',
    () async {
      final state = engine.initialState(boardSize: 7, startingPlayer: 2);
      for (final difficulty in AiDifficulty.values) {
        final move = await const CrossmateAi().chooseMove(state, difficulty, 2);
        expect(move, isNotNull);
        expect(engine.canonicalMove(state, move!), isNotNull);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
