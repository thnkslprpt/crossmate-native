import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../game/palette.dart';
import '../widgets/app_background.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({required this.controller, super.key});

  final CrossmateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentPalette = CrossmatePalette.from(controller.theme);
        return AppBackground(
          palette: currentPalette,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Board themes'),
              backgroundColor: Colors.transparent,
            ),
            body: SafeArea(
              top: false,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
                itemCount: BoardThemeId.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final id = BoardThemeId.values[index];
                  final palette = CrossmatePalette.from(id);
                  final selected = controller.theme == id;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => controller.setTheme(id),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected ? palette.accent : Colors.white12,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            _ThemePreview(palette: palette),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    palette.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _description(id),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected ? palette.accent : Colors.white30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _description(BoardThemeId id) => switch (id) {
    BoardThemeId.neon => 'Electric blue and magenta tournament arena.',
    BoardThemeId.wood => 'Warm carved timber with classic table-game weight.',
    BoardThemeId.obsidian => 'Dark stone, steel grid and restrained gold.',
    BoardThemeId.prism => 'Colourful violet, cyan and rose circuitry.',
  };
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});

  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.grid, width: 2),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 16,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
        itemBuilder: (_, index) {
          return ColoredBox(
            color: ((index ~/ 4) + index).isEven
                ? palette.boardLight
                : palette.boardDark,
            child: index == 5
                ? Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.playerOne,
                      ),
                    ),
                  )
                : index == 10
                ? Center(
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 14,
                        height: 14,
                        color: palette.playerTwo,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
