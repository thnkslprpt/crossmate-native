import 'package:crossmate/game/controller.dart';
import 'package:crossmate/game/engine.dart';
import 'package:crossmate/screens/game_screen.dart';
import 'package:crossmate/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crossmate/game/models.dart';
import 'package:crossmate/game/palette.dart';
import 'package:crossmate/widgets/crossmate_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('board size chooser starts a 7x7 local match', (tester) async {
    SharedPreferences.setMockInitialValues({'crossmate-seen-tutorial': true});
    final controller = CrossmateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7×7 · Quick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two players here'));
    await tester.pumpAndSettle();
    expect(controller.state!.boardSize, 7);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      7,
    );
    expect(find.byType(PieceToken), findsNWidgets(28));
  });

  testWidgets('both board sizes map flipped corner taps correctly', (
    tester,
  ) async {
    final engine = CrossmateEngine();
    for (final size in [7, 9]) {
      for (final flipped in [false, true]) {
        (int, int)? tapped;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                height: 350,
                child: CrossmateBoard(
                  state: engine.initialState(boardSize: size),
                  engine: engine,
                  palette: CrossmatePalette.from(BoardThemeId.neon),
                  onTap: (row, col) => tapped = (row, col),
                  selectedPieceId: null,
                  legalMoves: const [],
                  pendingEdgeMoves: const [],
                  flipped: flipped,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final grid = find.byType(GridView);
        await tester.tapAt(tester.getTopLeft(grid) + const Offset(8, 8));
        expect(tapped, flipped ? (size - 1, size - 1) : (0, 0));
      }
    }
  });

  testWidgets('triangle offers and executes a standalone half turn', (
    tester,
  ) async {
    final controller = CrossmateController();
    addTearDown(controller.dispose);
    await controller.startLocal(startingPlayer: 1);
    final triangle = controller.state!.pieces.firstWhere(
      (p) => p.player == 1 && p.type == PieceType.triangle,
    );
    controller.tapCell(triangle.row, triangle.col);
    controller.tapCell(triangle.row, triangle.col);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rotate 180°'));
    await tester.tap(find.text('Rotate 180°'));
    await tester.pumpAndSettle();
    final rotated = controller.engine.pieceById(
      controller.state!,
      triangle.id,
    )!;
    expect(rotated.facing, 2);
    expect((rotated.row, rotated.col), (triangle.row, triangle.col));
    expect(controller.state!.currentPlayer, 2);
  });

  testWidgets('rotation popup cancels without using a turn', (tester) async {
    final controller = CrossmateController();
    addTearDown(controller.dispose);
    await controller.startLocal(startingPlayer: 1);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    final triangle = controller.state!.pieces.firstWhere(
      (p) => p.player == 1 && p.type == PieceType.triangle,
    );
    controller.tapCell(triangle.row, triangle.col);
    controller.tapCell(triangle.row, triangle.col);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(controller.pendingTriangleMoves, isEmpty);
    expect(controller.state!.moveNumber, 0);
    expect(controller.state!.currentPlayer, 1);
  });

  testWidgets('robot setup offers all five levels and starts Master', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'crossmate-seen-tutorial': true});
    final controller = CrossmateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play the robot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AiDifficulty>));
    await tester.pumpAndSettle();
    for (final level in AiDifficulty.values) {
      expect(find.text(level.label), findsWidgets);
    }
    await tester.tap(find.text('5 · Master').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start match'));
    await tester.pumpAndSettle();
    expect(controller.aiDifficulty, AiDifficulty.master);
    expect(await controller.settings.loadDifficulty(), AiDifficulty.master);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('triangle uses the same square housing as back-row pieces', (
    tester,
  ) async {
    const triangle = Piece(
      id: 't',
      type: PieceType.triangle,
      player: 1,
      row: 0,
      col: 0,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: PieceToken(
                piece: triangle,
                palette: CrossmatePalette(
                  name: 'test',
                  background: <Color>[Colors.black, Colors.black],
                  surface: Colors.black,
                  surfaceStrong: Colors.black,
                  boardLight: Colors.black,
                  boardDark: Colors.black,
                  grid: Colors.white,
                  playerOne: Colors.cyan,
                  playerTwo: Colors.pink,
                  accent: Colors.amber,
                  glow: Colors.purple,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PieceToken), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsOneWidget);
  });
}
