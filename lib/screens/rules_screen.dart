import 'package:flutter/material.dart';

import '../game/models.dart';
import '../game/palette.dart';
import '../widgets/app_background.dart';
import '../widgets/crossmate_board.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({required this.palette, super.key});

  final CrossmatePalette palette;

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  int page = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const sections = <_RuleSection>[
    _RuleSection(
      'Win the board',
      Icons.emoji_events_rounded,
      'Play on a quick 7×7 board with seven circles per player, or the classic 9×9 board with nine circles and two empty back-row spaces beside each cross. Capture the opponent’s cross, or leave the opponent with no legal move—even without check. Captured pieces score points, but points do not decide the match.',
    ),
    _RuleSection(
      'Circle • 1 point',
      Icons.circle_outlined,
      'Moves one or two empty squares vertically. Captures one step diagonally forward. On reaching the far edge, it must sacrifice itself to remove one chosen enemy piece other than the cross when a legal target exists. With no legal target, it remains on the edge.',
    ),
    _RuleSection(
      'Triangle • 3 points',
      Icons.change_history_rounded,
      'Faces up, right, down or left. Each turn, choose one action: rotate in place to any other direction, move one empty square forward, or capture. Captures reach one square ahead, diagonally ahead-left or ahead-right, or two squares ahead if the first square is empty. A capture lands on the target without changing facing. Triangles can capture diamonds, ignoring only the target diamond’s own field. Moving, turning and capturing are separate actions.',
    ),
    _RuleSection(
      'Square • 5 points',
      Icons.crop_square_rounded,
      'Slides any distance horizontally or vertically. At the first ordinary enemy, it may capture and stop or jump over without capturing. After one jump it may continue through empty squares and optionally capture one further ordinary enemy. A diamond is destroyed only by landing directly on it, including after one legal jump.',
    ),
    _RuleSection(
      'Diamond • 6 points',
      Icons.diamond_outlined,
      'Moves one square in any direction and projects a forcefield into all eight neighbouring squares. Enemy pieces cannot enter or cross that field. Your own cross may enter its own field, but can still be checked there.',
    ),
    _RuleSection(
      'Cross',
      Icons.close_rounded,
      'Moves one, two or three squares in any straight or diagonal direction. It stops after its first capture. Protect it: capturing the cross or leaving its player with no legal move wins immediately.',
    ),
    _RuleSection(
      'Draws',
      Icons.handshake_rounded,
      'The game is drawn by three repetitions of the same full position, 60 consecutive player moves without a capture, or when only the two crosses remain. Having no legal move is a loss, even without check, and takes priority over a draw.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      palette: widget.palette,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('How to play'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: sections.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 10),
                          _RuleIcon(
                            icon: section.icon,
                            palette: widget.palette,
                            type: _pieceForPage(index),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            section.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Text(
                              section.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.55,
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                          if (index == 0) ...<Widget>[
                            const SizedBox(height: 25),
                            _ScoreLegend(palette: widget.palette),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: page > 0
                          ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          sections.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: index == page ? 22 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == page
                                  ? widget.palette.accent
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: page < sections.length - 1
                          ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PieceType? _pieceForPage(int page) => switch (page) {
    1 => PieceType.circle,
    2 => PieceType.triangle,
    3 => PieceType.square,
    4 => PieceType.diamond,
    5 => PieceType.cross,
    _ => null,
  };
}

class _RuleSection {
  const _RuleSection(this.title, this.icon, this.body);

  final String title;
  final IconData icon;
  final String body;
}

class _RuleIcon extends StatelessWidget {
  const _RuleIcon({
    required this.icon,
    required this.palette,
    required this.type,
  });

  final IconData icon;
  final CrossmatePalette palette;
  final PieceType? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: <Color>[
            palette.playerOne.withValues(alpha: 0.32),
            palette.playerTwo.withValues(alpha: 0.24),
          ],
        ),
        border: Border.all(color: palette.accent.withValues(alpha: 0.42)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.35),
            blurRadius: 26,
          ),
        ],
      ),
      child: type == null
          ? Icon(icon, size: 64, color: palette.accent)
          : PieceToken(
              piece: Piece(id: 'rule', type: type!, player: 1, row: 0, col: 0),
              palette: palette,
            ),
    );
  }
}

class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend({required this.palette});

  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Wrap(
        alignment: WrapAlignment.center,
        spacing: 13,
        runSpacing: 8,
        children: <Widget>[
          _ScoreItem('Circle', 1),
          _ScoreItem('Triangle', 3),
          _ScoreItem('Square', 5),
          _ScoreItem('Diamond', 6),
        ],
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  const _ScoreItem(this.label, this.score);

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $score',
      style: const TextStyle(fontWeight: FontWeight.w900),
    );
  }
}
