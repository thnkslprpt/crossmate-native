import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/engine.dart';
import '../game/models.dart';
import '../game/palette.dart';

class CrossmateBoard extends StatelessWidget {
  const CrossmateBoard({
    required this.state,
    required this.engine,
    required this.palette,
    required this.onTap,
    required this.selectedPieceId,
    required this.legalMoves,
    required this.pendingEdgeMoves,
    this.flipped = false,
    this.enabled = true,
    super.key,
  });

  final GameState state;
  final CrossmateEngine engine;
  final CrossmatePalette palette;
  final void Function(int row, int col) onTap;
  final String? selectedPieceId;
  final List<GameMove> legalMoves;
  final List<GameMove> pendingEdgeMoves;
  final bool flipped;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final legalLandings = <String>{
      for (final move in legalMoves)
        '${move.resolvedLandingRow}:${move.resolvedLandingCol}',
    };
    final legalCaptures = <String>{
      for (final move in legalMoves)
        if (move.captures.isNotEmpty)
          '${move.resolvedLandingRow}:${move.resolvedLandingCol}',
    };
    final threatenedTargets = <String>{
      for (final move in legalMoves)
        if (move.captures.isNotEmpty) '${move.toRow}:${move.toCol}',
    };
    final edgeTargets = pendingEdgeMoves
        .map((move) => move.destroyTargetId)
        .whereType<String>()
        .toSet();
    final checkedCross = engine.isInCheck(state, state.currentPlayer)
        ? engine.crossFor(state, state.currentPlayer)
        : null;
    final attackingPieces = checkedCross == null
        ? const <Piece>[]
        : engine.attackersOfCross(state, state.currentPlayer);
    final attackers = attackingPieces.map((piece) => piece.id).toSet();
    final checkPath = checkedCross == null
        ? const <String>{}
        : _checkPath(checkedCross, attackingPieces);
    final lastPath = state.lastMove == null
        ? const <String>{}
        : _pathForMove(state.lastMove!.move);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.grid, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.glow.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / state.boardSize;
            return Stack(
              children: <Widget>[
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: state.boardSize * state.boardSize,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: state.boardSize,
                  ),
                  itemBuilder: (context, index) {
                    final visualRow = index ~/ state.boardSize;
                    final visualCol = index % state.boardSize;
                    final row = flipped
                        ? state.boardSize - 1 - visualRow
                        : visualRow;
                    final col = flipped
                        ? state.boardSize - 1 - visualCol
                        : visualCol;
                    final piece = engine.pieceAt(state, row, col);
                    final key = '$row:$col';
                    final isLegal = legalLandings.contains(key);
                    final isCapture = legalCaptures.contains(key);
                    final isThreatenedTarget = threatenedTargets.contains(key);
                    final isSelected = piece?.id == selectedPieceId;
                    final isLastFrom =
                        state.lastMove?.move.fromRow == row &&
                        state.lastMove?.move.fromCol == col;
                    final isLastTo =
                        state.lastMove?.move.toRow == row &&
                        state.lastMove?.move.toCol == col;
                    final isLastPath = lastPath.contains(key);
                    final isCheckPath = checkPath.contains(key);
                    final isChecked = piece?.id == checkedCross?.id;
                    final isAttacker =
                        piece != null && attackers.contains(piece.id);
                    final isEdgeTarget =
                        piece != null && edgeTargets.contains(piece.id);
                    final fieldOwners = _fieldOwners(row, col);
                    final isRelevantCheckField =
                        checkedCross != null &&
                        fieldOwners.isNotEmpty &&
                        (isCheckPath ||
                            engine.isAdjacent(
                              checkedCross.row,
                              checkedCross.col,
                              row,
                              col,
                            ));
                    final base = (row + col).isEven
                        ? palette.boardLight
                        : palette.boardDark;

                    return Semantics(
                      button: true,
                      label: _semanticLabel(piece, row, col, isLegal),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled ? () => onTap(row, col) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: base,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.18),
                              width: 0.5,
                            ),
                            boxShadow: isSelected
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: palette.accent.withValues(
                                        alpha: 0.9,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              if (fieldOwners.isNotEmpty)
                                _ForcefieldCell(
                                  owners: fieldOwners,
                                  palette: palette,
                                  emphasized: isRelevantCheckField,
                                ),
                              if (isLastPath && !isLastFrom && !isLastTo)
                                Container(
                                  color: palette.accent.withValues(alpha: 0.10),
                                ),
                              if (isCheckPath)
                                Container(
                                  color: const Color(
                                    0xFFFF334C,
                                  ).withValues(alpha: 0.16),
                                ),
                              if (isLastFrom || isLastTo)
                                Container(
                                  color: palette.accent.withValues(
                                    alpha: isLastTo ? 0.29 : 0.16,
                                  ),
                                ),
                              if (isSelected)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: palette.accent,
                                      width: math.max(2.0, cellSize * 0.055),
                                    ),
                                  ),
                                ),
                              if (piece != null)
                                Padding(
                                  padding: EdgeInsets.all(cellSize * 0.075),
                                  child: PieceToken(
                                    piece: piece,
                                    palette: palette,
                                    checked: isChecked,
                                    attacker: isAttacker,
                                    target: isEdgeTarget || isThreatenedTarget,
                                    facingOffset: flipped ? 2 : 0,
                                  ),
                                ),
                              if (isLegal)
                                Center(
                                  child: Container(
                                    width: cellSize * (isCapture ? 0.79 : 0.27),
                                    height:
                                        cellSize * (isCapture ? 0.79 : 0.27),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCapture
                                          ? Colors.transparent
                                          : palette.accent.withValues(
                                              alpha: 0.78,
                                            ),
                                      border: isCapture
                                          ? Border.all(
                                              color: palette.accent,
                                              width: math.max(
                                                2.0,
                                                cellSize * 0.08,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _BoardFramePainter(
                      boardSize: state.boardSize,
                      color: palette.grid.withValues(alpha: 0.5),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Set<String> _checkPath(Piece cross, List<Piece> attackers) {
    final cells = <String>{};
    for (final attacker in attackers) {
      final attackMoves = engine
          .pseudoMovesForPiece(
            state,
            attacker,
            transparentForcefieldPlayer: cross.player,
          )
          .where((move) => move.captures.contains(cross.id));
      for (final move in attackMoves) {
        cells.addAll(_pathForMove(move));
      }
    }
    return cells;
  }

  Set<String> _pathForMove(GameMove move) {
    final cells = <String>{};
    if (move.type == PieceType.triangle) {
      cells.addAll(
        _lineCells(
          move.fromRow,
          move.fromCol,
          move.resolvedLandingRow,
          move.resolvedLandingCol,
        ),
      );
      if (move.toRow != move.resolvedLandingRow ||
          move.toCol != move.resolvedLandingCol) {
        cells.add('${move.toRow}:${move.toCol}');
      }
    } else {
      cells.addAll(
        _lineCells(move.fromRow, move.fromCol, move.toRow, move.toCol),
      );
    }
    return cells;
  }

  Set<String> _lineCells(int fromRow, int fromCol, int toRow, int toCol) {
    final cells = <String>{};
    final deltaRow = toRow - fromRow;
    final deltaCol = toCol - fromCol;
    final distance = math.max(deltaRow.abs(), deltaCol.abs());
    if (distance == 0) return cells;
    final rowStep = deltaRow == 0 ? 0 : (deltaRow > 0 ? 1 : -1);
    final colStep = deltaCol == 0 ? 0 : (deltaCol > 0 ? 1 : -1);
    for (var step = 1; step <= distance; step += 1) {
      cells.add('${fromRow + rowStep * step}:${fromCol + colStep * step}');
    }
    return cells;
  }

  Set<int> _fieldOwners(int row, int col) {
    final owners = <int>{};
    for (final diamond in state.pieces) {
      if (diamond.alive &&
          diamond.type == PieceType.diamond &&
          engine.isAdjacent(diamond.row, diamond.col, row, col)) {
        owners.add(diamond.player);
      }
    }
    return owners;
  }

  String _semanticLabel(Piece? piece, int row, int col, bool legal) {
    final square = '${String.fromCharCode(65 + col)}${state.boardSize - row}';
    if (piece == null) return '$square${legal ? ', legal destination' : ''}';
    return '$square, Player ${piece.player} ${piece.type.displayName}'
        '${legal ? ', legal destination' : ''}';
  }
}

class PieceToken extends StatelessWidget {
  const PieceToken({
    required this.piece,
    required this.palette,
    this.checked = false,
    this.attacker = false,
    this.target = false,
    this.facingOffset = 0,
    super.key,
  });

  final Piece piece;
  final CrossmatePalette palette;
  final bool checked;
  final bool attacker;
  final bool target;
  final int facingOffset;

  @override
  Widget build(BuildContext context) {
    final color = piece.player == 1 ? palette.playerOne : palette.playerTwo;
    final housing = piece.type == PieceType.circle
        ? BoxShape.circle
        : BoxShape.rectangle;
    final radius = piece.type == PieceType.circle
        ? null
        : BorderRadius.circular(7);
    final borderColor = checked
        ? const Color(0xFFFF334C)
        : target
        ? palette.accent
        : attacker
        ? const Color(0xFFFF8A3D)
        : Colors.white.withValues(alpha: 0.46);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        shape: housing,
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.22)!,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
        ),
        border: Border.all(
          color: borderColor,
          width: checked || target ? 3 : 1.3,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (checked ? const Color(0xFFFF334C) : color).withValues(
              alpha: checked ? 0.62 : 0.33,
            ),
            blurRadius: checked || target ? 12 : 5,
            spreadRadius: checked || target ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 220),
          turns: piece.type == PieceType.triangle
              ? ((piece.facing + facingOffset) % 4) / 4
              : 0,
          child: CustomPaint(
            painter: _PieceGlyphPainter(
              type: piece.type,
              color: _glyphColor(color),
            ),
          ),
        ),
      ),
    );
  }

  Color _glyphColor(Color tokenColor) {
    return ThemeData.estimateBrightnessForColor(tokenColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF10131D);
  }
}

class _ForcefieldCell extends StatelessWidget {
  const _ForcefieldCell({
    required this.owners,
    required this.palette,
    this.emphasized = false,
  });

  final Set<int> owners;
  final CrossmatePalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      if (owners.contains(1)) palette.playerOne.withValues(alpha: 0.17),
      if (owners.contains(2)) palette.playerTwo.withValues(alpha: 0.17),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.length == 1
            ? RadialGradient(colors: <Color>[colors.first, Colors.transparent])
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        border: Border.all(
          color: emphasized
              ? const Color(0xFFFF667A)
              : colors.first.withValues(alpha: 0.62),
          width: emphasized ? 2 : 1,
        ),
      ),
      child: CustomPaint(
        painter: _ForcefieldPainter(
          color: colors.first.withValues(alpha: 0.56),
        ),
      ),
    );
  }
}

class _PieceGlyphPainter extends CustomPainter {
  const _PieceGlyphPainter({required this.type, required this.color});

  final PieceType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, size.shortestSide * 0.12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromLTWH(
      size.width * 0.17,
      size.height * 0.17,
      size.width * 0.66,
      size.height * 0.66,
    );

    switch (type) {
      case PieceType.circle:
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, paint);
        break;
      case PieceType.diamond:
        final path = Path()
          ..moveTo(size.width / 2, size.height * 0.11)
          ..lineTo(size.width * 0.89, size.height / 2)
          ..lineTo(size.width / 2, size.height * 0.89)
          ..lineTo(size.width * 0.11, size.height / 2)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, paint);
        break;
      case PieceType.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
        break;
      case PieceType.triangle:
        final path = Path()
          ..moveTo(size.width / 2, size.height * 0.09)
          ..lineTo(size.width * 0.87, size.height * 0.84)
          ..lineTo(size.width * 0.13, size.height * 0.84)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, paint);
        break;
      case PieceType.cross:
        canvas.drawLine(
          Offset(size.width * 0.22, size.height * 0.22),
          Offset(size.width * 0.78, size.height * 0.78),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.78, size.height * 0.22),
          Offset(size.width * 0.22, size.height * 0.78),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PieceGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class _ForcefieldPainter extends CustomPainter {
  const _ForcefieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ForcefieldPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BoardFramePainter extends CustomPainter {
  const _BoardFramePainter({required this.color, required this.boardSize});

  final Color color;
  final int boardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final step = size.width / boardSize;
    for (var i = 1; i < boardSize; i += 1) {
      final value = step * i;
      canvas.drawLine(Offset(value, 0), Offset(value, size.height), paint);
      canvas.drawLine(Offset(0, value), Offset(size.width, value), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.boardSize != boardSize;
}
