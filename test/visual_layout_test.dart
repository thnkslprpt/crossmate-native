import 'package:crossmate/game/controller.dart';
import 'package:crossmate/game/engine.dart';
import 'package:crossmate/widgets/crossmate_board.dart';
import 'package:crossmate/game/models.dart';
import 'package:crossmate/game/palette.dart';
import 'package:crossmate/screens/game_screen.dart';
import 'package:crossmate/screens/home_screen.dart';
import 'package:crossmate/screens/rules_screen.dart';
import 'package:crossmate/screens/theme_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('empty squares are not highlighted when nothing is selected', (
    tester,
  ) async {
    final engine = CrossmateEngine();
    final palette = CrossmatePalette.from(BoardThemeId.neon);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            height: 350,
            child: CrossmateBoard(
              state: engine.initialState(),
              engine: engine,
              palette: palette,
              onTap: (_, _) {},
              selectedPieceId: null,
              legalMoves: const [],
              pendingEdgeMoves: const [],
            ),
          ),
        ),
      ),
    );
    final selectionBorders = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.decoration is! BoxDecoration) {
        return false;
      }
      final border = (widget.decoration! as BoxDecoration).border;
      return border is Border && border.top.color == palette.accent;
    });
    expect(selectionBorders, findsNothing);
  });
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('screens fit $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'crossmate-seen-tutorial': true});
      final controller = CrossmateController();
      addTearDown(controller.dispose);
      for (final theme in BoardThemeId.values) {
        await controller.setTheme(theme);
        for (final boardSize in [7, 9]) {
          await controller.setBoardSize(boardSize);
          await controller.startLocal(startingPlayer: 1);
          for (final screen in [
            HomeScreen(controller: controller),
            ThemeScreen(controller: controller),
            RulesScreen(palette: CrossmatePalette.from(theme)),
            GameScreen(controller: controller),
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildCrossmateTheme(theme),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType}, $theme, $boardSize',
            );
          }
        }
      }
    });
  }
}
