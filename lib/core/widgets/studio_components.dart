import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NightStudioScaffold extends StatelessWidget {
  const NightStudioScaffold({
    required this.body,
    this.appBar,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: AppColors.background,
      body: StudioBackground(child: body),
    );
  }
}

class StudioBackground extends StatelessWidget {
  const StudioBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        const Positioned(
          top: -170,
          left: -130,
          child: _Glow(color: AppColors.primary, size: 360),
        ),
        const Positioned(
          right: -160,
          bottom: -180,
          child: _Glow(color: AppColors.violet, size: 400),
        ),
        child,
      ],
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
            colors: [color.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class StudioMark extends StatelessWidget {
  const StudioMark({this.width = 128, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 0.72;
    return Semantics(
      image: true,
      label: 'Kelime Yarışı logosu',
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _StudioMarkPainter()),
      ),
    );
  }
}

class _StudioMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 160;
    final scaleY = size.height / 116;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final bubble = Path()
      ..moveTo(30, 16)
      ..lineTo(130, 16)
      ..cubicTo(143, 16, 150, 24, 150, 36)
      ..lineTo(150, 69)
      ..cubicTo(150, 82, 142, 89, 130, 89)
      ..lineTo(68, 89)
      ..lineTo(48, 105)
      ..lineTo(48, 89)
      ..lineTo(30, 89)
      ..cubicTo(17, 89, 10, 81, 10, 69)
      ..lineTo(10, 36)
      ..cubicTo(10, 23, 18, 16, 30, 16)
      ..close();
    canvas.drawPath(
      bubble,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.round,
    );

    void drawTile(Rect rect, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = color,
      );
    }

    drawTile(const Rect.fromLTWH(31, 35, 31, 33), AppColors.cyan);
    drawTile(const Rect.fromLTWH(65, 35, 31, 33), AppColors.paper);
    drawTile(const Rect.fromLTWH(99, 35, 31, 33), AppColors.cyan);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'K',
        style: TextStyle(
          color: AppColors.onPaper,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(80.5 - textPainter.width / 2, 51.5 - textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StudioSectionLabel extends StatelessWidget {
  const StudioSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}
