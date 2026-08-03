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
      background: <Color>[Color(0xFF050718), Color(0xFF10164A)],
      surface: Color(0xCC111A3D),
      surfaceStrong: Color(0xFF17224E),
      boardLight: Color(0xFF172E59),
      boardDark: Color(0xFF0C1936),
      grid: Color(0xFF3D62A4),
      playerOne: Color(0xFF38E8FF),
      playerTwo: Color(0xFFFF4F9A),
      accent: Color(0xFFFFD166),
      glow: Color(0xFF7A5CFF),
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
      background: <Color>[Color(0xFF191035), Color(0xFF082B44)],
      surface: Color(0xD9291B50),
      surfaceStrong: Color(0xFF332360),
      boardLight: Color(0xFF3E3172),
      boardDark: Color(0xFF173A5C),
      grid: Color(0xFF8B79D3),
      playerOne: Color(0xFF6FFFE9),
      playerTwo: Color(0xFFFF7AB6),
      accent: Color(0xFFFFE66D),
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
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.2),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w800),
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
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
