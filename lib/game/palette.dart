import 'package:flutter/material.dart';

import 'models.dart';

class CrossmatePalette {
  const CrossmatePalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.boardLight,
    required this.boardDark,
    required this.grid,
    required this.playerOne,
    required this.playerTwo,
    required this.accent,
    required this.glow,
  });

  final String name;
  final List<Color> background;
  final Color surface;
  final Color surfaceStrong;
  final Color boardLight;
  final Color boardDark;
  final Color grid;
  final Color playerOne;
  final Color playerTwo;
  final Color accent;
  final Color glow;

  static CrossmatePalette from(BoardThemeId id) => switch (id) {
    BoardThemeId.neon => const CrossmatePalette(
      name: 'Neon Arena',
      background: <Color>[Color(0xFF0B121B), Color(0xFF162838)],
      surface: Color(0xF0182533),
      surfaceStrong: Color(0xFF202F3E),
      boardLight: Color(0xFF334B5B),
      boardDark: Color(0xFF223644),
      grid: Color(0xFF688291),
      playerOne: Color(0xFF8ADDD4),
      playerTwo: Color(0xFFEBAB9B),
      accent: Color(0xFFE8C98C),
      glow: Color(0xFF648EAD),
    ),
    BoardThemeId.wood => const CrossmatePalette(
      name: 'Grandmaster Wood',
      background: <Color>[Color(0xFF1B100C), Color(0xFF4B2E1F)],
      surface: Color(0xDD2C1B14),
      surfaceStrong: Color(0xFF4C2C1D),
      boardLight: Color(0xFFD9B27C),
      boardDark: Color(0xFF7A492C),
      grid: Color(0xFF4A2B1B),
      playerOne: Color(0xFFF8E5BD),
      playerTwo: Color(0xFF251711),
      accent: Color(0xFFE9B44C),
      glow: Color(0xFFC76D3D),
    ),
    BoardThemeId.obsidian => const CrossmatePalette(
      name: 'Obsidian Vault',
      background: <Color>[Color(0xFF050608), Color(0xFF171A20)],
      surface: Color(0xE615171C),
      surfaceStrong: Color(0xFF23272F),
      boardLight: Color(0xFF303640),
      boardDark: Color(0xFF171A20),
      grid: Color(0xFF606A78),
      playerOne: Color(0xFFF2F4F8),
      playerTwo: Color(0xFFE2AA3A),
      accent: Color(0xFFE2AA3A),
      glow: Color(0xFF8A94A5),
    ),
    BoardThemeId.prism => const CrossmatePalette(
      name: 'Prism Circuit',
      background: <Color>[Color(0xFF171528), Color(0xFF253249)],
      surface: Color(0xF025263E),
      surfaceStrong: Color(0xFF32334E),
      boardLight: Color(0xFF4D496D),
      boardDark: Color(0xFF303C59),
      grid: Color(0xFF8B79D3),
      playerOne: Color(0xFFA3E7DE),
      playerTwo: Color(0xFFE7ACCD),
      accent: Color(0xFFE6D6A2),
      glow: Color(0xFFB66DFF),
    ),
  };
}

ThemeData buildCrossmateTheme(BoardThemeId id) {
  final palette = CrossmatePalette.from(id);
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: Brightness.dark,
    primary: palette.accent,
    secondary: palette.playerOne,
    surface: palette.surfaceStrong,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F2EB),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceStrong,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.10)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 14),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent.withValues(alpha: 0.16)
              : palette.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : Colors.white70,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -1.2),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(height: 1.35),
      bodyMedium: TextStyle(height: 1.35),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    ),
  );
}
