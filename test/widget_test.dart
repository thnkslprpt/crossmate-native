import 'package:crossmate/game/models.dart';
import 'package:crossmate/game/palette.dart';
import 'package:crossmate/widgets/crossmate_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
