import 'package:flutter/material.dart';

import '../game/palette.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.palette, required this.child, super.key});

  final CrossmatePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.background,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -140,
            right: -110,
            child: _Glow(color: palette.playerTwo, size: 310),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: _Glow(color: palette.playerOne, size: 360),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
