import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

class SettingsService {
  const SettingsService();

  static const _themeKey = 'crossmate-theme';
  static const _tutorialKey = 'crossmate-seen-tutorial';
  static const _difficultyKey = 'crossmate-ai-difficulty';
  static const _openingKey = 'crossmate-ai-opening';
  static const _roomKey = 'crossmate-online-room';

  Future<int> loadBoardSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('crossmate-board-size') == 7 ? 7 : 9;
  }

  Future<void> saveBoardSize(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('crossmate-board-size', value);
  }

  Future<BoardThemeId> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeKey);
    return BoardThemeId.values.firstWhere(
      (theme) => theme.name == name,
      orElse: () => BoardThemeId.neon,
    );
  }

  Future<void> saveTheme(BoardThemeId theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
  }

  Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialKey) ?? false;
  }

  Future<void> markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
  }

  Future<AiDifficulty> loadDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_difficultyKey);
    return AiDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == name,
      orElse: () => AiDifficulty.normal,
    );
  }

  Future<void> saveDifficulty(AiDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, difficulty.name);
  }

  Future<String> loadOpening() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openingKey) ?? 'human';
  }

  Future<void> saveOpening(String opening) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openingKey, opening);
  }

  Future<void> saveRoom(String code, int player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomKey, '$code:$player');
  }

  Future<({String code, int player})?> loadRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_roomKey);
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final player = int.tryParse(parts[1]);
    if (parts[0].length != 5 || (player != 1 && player != 2)) return null;
    return (code: parts[0], player: player!);
  }

  Future<void> clearRoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roomKey);
  }
}
