import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../game/palette.dart';
import '../services/online_service.dart';
import '../widgets/app_background.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'theme_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final CrossmateController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CrossmateController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFirstLaunchRules());
    });
  }

  Future<void> _showFirstLaunchRules() async {
    if (await controller.settings.hasSeenTutorial()) return;
    await controller.settings.markTutorialSeen();
    if (!mounted) return;
    final palette = CrossmatePalette.from(controller.theme);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RulesScreen(palette: palette)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CrossmatePalette.from(controller.theme);
    return AppBackground(
      palette: palette,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeroHeader(palette: palette),
                  const SizedBox(height: 22),
                  _ModeCard(
                    icon: Icons.smart_toy_rounded,
                    title: 'Play the robot',
                    subtitle: 'Offline • Easy, Normal or Hard',
                    colors: <Color>[palette.playerOne, palette.glow],
                    onTap: () => _showComputerSetup(context),
                  ),
                  const SizedBox(height: 12),
                  _ModeCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Two players here',
                    subtitle: 'Pass one phone or tablet between players',
                    colors: <Color>[palette.playerTwo, palette.accent],
                    onTap: () async {
                      await controller.startLocal();
                      if (context.mounted) _openGame(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ModeCard(
                    icon: Icons.language_rounded,
                    title: 'Two players online',
                    subtitle: 'Create or join a private five-character room',
                    colors: <Color>[palette.accent, palette.playerOne],
                    onTap: () => _showOnlineSetup(context),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.menu_book_rounded,
                          label: 'Rules',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RulesScreen(palette: palette),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.palette_rounded,
                          label: palette.name,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ThemeScreen(controller: controller),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CROSSMATE NATIVE • 0.1.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(controller: controller),
      ),
    );
  }

  Future<void> _showComputerSetup(BuildContext context) async {
    var difficulty = controller.aiDifficulty;
    var opening = await controller.settings.loadOpening();
    if (!context.mounted) return;
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SetupSheet(
              title: 'Robot match',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionLabel('DIFFICULTY'),
                  SegmentedButton<AiDifficulty>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<AiDifficulty>>[
                      ButtonSegment(
                        value: AiDifficulty.easy,
                        label: Text('Easy'),
                      ),
                      ButtonSegment(
                        value: AiDifficulty.normal,
                        label: Text('Normal'),
                      ),
                      ButtonSegment(
                        value: AiDifficulty.hard,
                        label: Text('Hard'),
                      ),
                    ],
                    selected: <AiDifficulty>{difficulty},
                    onSelectionChanged: (value) =>
                        setModalState(() => difficulty = value.first),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel('WHO OPENS?'),
                  DropdownButtonFormField<String>(
                    initialValue: opening,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'human', child: Text('You')),
                      DropdownMenuItem(value: 'computer', child: Text('Robot')),
                      DropdownMenuItem(value: 'random', child: Text('Random')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => opening = value ?? 'human'),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start match'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (start != true || !context.mounted) return;
    await controller.startComputer(difficulty: difficulty, opening: opening);
    if (context.mounted) _openGame(context);
  }

  Future<void> _showOnlineSetup(BuildContext context) async {
    final codeController = TextEditingController();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _SetupSheet(
          title: 'Online room',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'create'),
                icon: const Icon(Icons.add_circle_rounded),
                label: const Text('Create a room'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z2-9]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
                decoration: const InputDecoration(
                  hintText: 'ROOM CODE',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  if (codeController.text.trim().length == 5) {
                    Navigator.pop(sheetContext, codeController.text.trim());
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Join room'),
              ),
            ],
          ),
        );
      },
    );
    codeController.dispose();
    if (choice == null || !context.mounted) return;

    try {
      if (choice == 'create') {
        await controller.createOnlineRoom();
      } else {
        await controller.joinOnlineRoom(choice);
      }
      if (context.mounted) _openGame(context);
    } on OnlineUnavailableException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.palette});

  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: <Color>[palette.playerOne, palette.playerTwo],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.glow.withValues(alpha: 0.55),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(Icons.close_rounded, size: 68, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text('CROSSMATE', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 7),
        Text(
          'Outmanoeuvre the forcefields. Capture the cross.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colors.first.withValues(alpha: 0.22),
                colors.last.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: colors.first.withValues(alpha: 0.42)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: colors),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SetupSheet extends StatelessWidget {
  const _SetupSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 19),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.52),
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}
