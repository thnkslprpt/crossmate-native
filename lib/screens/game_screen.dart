import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../game/palette.dart';
import '../widgets/app_background.dart';
import '../widgets/crossmate_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.controller, super.key});

  final CrossmateController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int? _shownResultMove;
  bool _rotationOpen = false;

  CrossmateController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = CrossmatePalette.from(controller.theme);
    final state = controller.displayedState;
    _scheduleResult(state);
    _scheduleRotation();

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && controller.isOnline) unawaited(controller.leaveOnline());
      },
      child: AppBackground(
        palette: palette,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Crossmate',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _modeTitle(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (controller.roomCode != null)
                IconButton(
                  tooltip: 'Share room',
                  onPressed: _shareRoom,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'restart') _confirmRestart();
                  if (value == 'copy' && controller.roomCode != null) {
                    Clipboard.setData(
                      ClipboardData(text: controller.roomCode!),
                    );
                    _showMessage('Room code copied.');
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'restart',
                    child: Text('Restart match'),
                  ),
                  if (controller.roomCode != null)
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy room code'),
                    ),
                ],
              ),
            ],
          ),
          body: state == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth >= 760;
                      return horizontal
                          ? _WideGameLayout(
                              controller: controller,
                              state: state,
                              palette: palette,
                            )
                          : _PhoneGameLayout(
                              controller: controller,
                              state: state,
                              palette: palette,
                            );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _scheduleRotation() {
    if (_rotationOpen || controller.pendingTriangleMoves.isEmpty) return;
    _rotationOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final moves = List<GameMove>.of(controller.pendingTriangleMoves);
      if (moves.isEmpty) {
        _rotationOpen = false;
        return;
      }
      final move = await showDialog<GameMove>(
        context: context,
        builder: (context) => _TriangleRotationDialog(
          moves: moves,
          palette: CrossmatePalette.from(controller.theme),
          flipped: _perspectivePlayer(controller) == 2,
        ),
      );
      _rotationOpen = false;
      if (!mounted) return;
      if (move != null && controller.pendingTriangleMoves.contains(move)) {
        unawaited(controller.chooseTriangle(move));
      } else {
        controller.cancelChoice();
      }
    });
  }

  String _modeTitle() => switch (controller.mode) {
    MatchMode.local => 'Two players • same device',
    MatchMode.computer => '${controller.aiDifficulty.label} robot',
    MatchMode.online =>
      controller.roomCode == null
          ? 'Online room'
          : 'Room ${controller.roomCode}',
  };

  void _scheduleResult(GameState? state) {
    if (state == null || !state.gameOver || state.result == null) {
      _shownResultMove = null;
      return;
    }
    if (_shownResultMove == state.moveNumber) return;
    _shownResultMove = state.moveNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            state.result!.isDraw
                ? Icons.handshake_rounded
                : Icons.emoji_events_rounded,
            size: 42,
          ),
          title: Text(
            state.result!.isDraw
                ? 'Draw'
                : 'Player ${state.result!.winner} wins',
          ),
          content: Text(state.result!.reason, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Review board'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(controller.restart());
              },
              child: const Text('Play again'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _shareRoom() async {
    final code = controller.roomCode;
    if (code == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join my Crossmate room: $code\nOpen Crossmate, choose Two players online, then Join room.',
        subject: 'Crossmate room $code',
      ),
    );
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restart this match?'),
        content: const Text(
          'The current board and move history will be replaced.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.restart();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PhoneGameLayout extends StatelessWidget {
  const _PhoneGameLayout({
    required this.controller,
    required this.state,
    required this.palette,
  });

  final CrossmateController controller;
  final GameState state;
  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    final perspective = _perspectivePlayer(controller);
    final topPlayer = perspective == 1 ? 2 : 1;
    final bottomPlayer = perspective;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: Column(
        children: <Widget>[
          _PlayerBar(
            player: topPlayer,
            state: state,
            controller: controller,
            palette: palette,
            compact: true,
          ),
          const SizedBox(height: 7),
          _StatusStrip(controller: controller, state: state, palette: palette),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CrossmateBoard(
              state: state,
              engine: controller.engine,
              palette: palette,
              onTap: controller.tapCell,
              selectedPieceId: controller.isReviewing
                  ? null
                  : controller.selectedPieceId,
              legalMoves: controller.isReviewing
                  ? const <GameMove>[]
                  : controller.selectedMoves,
              pendingEdgeMoves: controller.isReviewing
                  ? const <GameMove>[]
                  : controller.pendingEdgeMoves,
              enabled: controller.canAct,
              flipped: perspective == 2,
            ),
          ),
          const SizedBox(height: 8),
          _PlayerBar(
            player: bottomPlayer,
            state: state,
            controller: controller,
            palette: palette,
            compact: true,
          ),
          const SizedBox(height: 8),
          _ChoicePanel(controller: controller, palette: palette),
          _HistoryControls(controller: controller),
        ],
      ),
    );
  }
}

class _WideGameLayout extends StatelessWidget {
  const _WideGameLayout({
    required this.controller,
    required this.state,
    required this.palette,
  });

  final CrossmateController controller;
  final GameState state;
  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    final perspective = _perspectivePlayer(controller);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 7,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: CrossmateBoard(
                  state: state,
                  engine: controller.engine,
                  palette: palette,
                  onTap: controller.tapCell,
                  selectedPieceId: controller.selectedPieceId,
                  legalMoves: controller.selectedMoves,
                  pendingEdgeMoves: controller.pendingEdgeMoves,
                  enabled: controller.canAct,
                  flipped: perspective == 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: math.min(330.0, MediaQuery.sizeOf(context).width * 0.32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _PlayerBar(
                    player: perspective == 1 ? 2 : 1,
                    state: state,
                    controller: controller,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _StatusStrip(
                    controller: controller,
                    state: state,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _PlayerBar(
                    player: perspective,
                    state: state,
                    controller: controller,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _ChoicePanel(controller: controller, palette: palette),
                  _HistoryControls(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _perspectivePlayer(CrossmateController controller) {
  return switch (controller.mode) {
    MatchMode.online => controller.localPlayer,
    MatchMode.computer => controller.humanPlayer,
    MatchMode.local => 1,
  };
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.player,
    required this.state,
    required this.controller,
    required this.palette,
    this.compact = false,
  });

  final int player;
  final GameState state;
  final CrossmateController controller;
  final CrossmatePalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = !state.gameOver && state.currentPlayer == player;
    final color = player == 1 ? palette.playerOne : palette.playerTwo;
    final label = _playerLabel();
    final connected =
        controller.mode != MatchMode.online ||
        player == controller.localPlayer ||
        controller.opponentConnected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 11 : 16,
      ),
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(
                color.withValues(alpha: 0.08),
                palette.surfaceStrong,
              )
            : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.55) : Colors.white12,
          width: 1,
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 13),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 30 : 38,
            height: compact ? 30 : 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 8),
              ],
            ),
            child: Text(
              '$player',
              style: TextStyle(
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                    ),
                    if (!connected) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(Icons.cloud_off_rounded, size: 14),
                    ],
                  ],
                ),
                Text(
                  state.gameOver
                      ? 'Match complete'
                      : active
                      ? 'To move'
                      : 'Waiting',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          Text(
            '${state.scores[player] ?? 0}',
            style: TextStyle(
              color: color,
              fontSize: compact ? 21 : 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'PTS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _playerLabel() {
    if (controller.mode == MatchMode.computer) {
      return player == controller.aiPlayer
          ? '${controller.aiDifficulty.label} robot'
          : 'You';
    }
    if (controller.mode == MatchMode.online) {
      return player == controller.localPlayer ? 'You' : 'Opponent';
    }
    return 'Player $player';
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.controller,
    required this.state,
    required this.palette,
  });

  final CrossmateController controller;
  final GameState state;
  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    final inCheck = controller.engine.isInCheck(state, state.currentPlayer);
    final text = controller.isReviewing
        ? 'Reviewing move ${controller.reviewIndex} of ${controller.history.length - 1}'
        : controller.aiThinking
        ? 'Robot is thinking…'
        : controller.message ??
              (state.gameOver
                  ? state.result?.reason ?? 'Game over'
                  : inCheck
                  ? 'Player ${state.currentPlayer} is in check'
                  : 'Player ${state.currentPlayer} to move');
    final alert = inCheck && !state.gameOver;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (alert ? const Color(0xFFFF334C) : palette.surfaceStrong)
            .withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: alert
              ? const Color(0xFFFF6A7B)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (controller.aiThinking) ...<Widget>[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ] else if (alert) ...<Widget>[
            const Icon(Icons.warning_rounded, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({required this.controller, required this.palette});

  final CrossmateController controller;
  final CrossmatePalette palette;

  @override
  Widget build(BuildContext context) {
    if (controller.pendingEdgeMoves.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.accent),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.bolt_rounded, color: palette.accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tap a highlighted non-cross enemy piece to remove it.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: controller.cancelChoice,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TriangleRotationDialog extends StatelessWidget {
  const _TriangleRotationDialog({
    required this.moves,
    required this.palette,
    required this.flipped,
  });

  final List<GameMove> moves;
  final CrossmatePalette palette;
  final bool flipped;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: palette.surfaceStrong,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rotate_90_degrees_cw_rounded,
              color: palette.accent,
              size: 30,
            ),
            const SizedBox(height: 12),
            const Text(
              'Rotate your triangle',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose its new direction. Rotating uses this turn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            for (final move in moves)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    side: BorderSide(color: palette.grid),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, move),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: PieceToken(
                          piece: Piece(
                            id: move.pieceId,
                            type: PieceType.triangle,
                            player: move.player,
                            row: move.toRow,
                            col: move.toCol,
                            facing: move.newFacing,
                          ),
                          palette: palette,
                          facingOffset: flipped ? 2 : 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          move.turn == 2
                              ? 'Rotate 180°'
                              : move.turn < 0
                              ? 'Rotate left'
                              : 'Rotate right',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: palette.accent),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HistoryControls extends StatelessWidget {
  const _HistoryControls({required this.controller});

  final CrossmateController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.history.length <= 1) return const SizedBox.shrink();
    final description = controller.history[controller.reviewIndex].description;
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: 'Previous move',
          onPressed: controller.canReviewBack
              ? controller.reviewPrevious
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: controller.isReviewing ? controller.returnToLive : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Text(
                controller.isReviewing
                    ? '$description • Tap for live board'
                    : description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.67),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Next move',
          onPressed: controller.canReviewForward ? controller.reviewNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
