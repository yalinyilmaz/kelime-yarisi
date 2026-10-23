import 'package:flutter/material.dart';

class StudioGlow extends StatelessWidget {
  const StudioGlow({required this.color, required this.size, super.key});

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
            colors: [color.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
