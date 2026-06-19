import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The signature Diya (oil lamp) icon — painted as a custom canvas.
///
/// Features an animated flickering flame. Pass [animate] = true to enable
/// the flame animation (default: true).
class DiyaIcon extends StatefulWidget {
  final double size;
  final bool animate;

  const DiyaIcon({super.key, this.size = 38, this.animate = true});

  @override
  State<DiyaIcon> createState() => _DiyaIconState();
}

class _DiyaIconState extends State<DiyaIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size * 0.8, widget.size),
          painter: _DiyaPainter(
            bowlFill: t.primarySoft,
            bowlStroke: t.primary,
            flameOuter: t.accent,
            flameInner: t.primary,
            flickerValue: _controller.value,
            isDark: t.brightness == Brightness.dark,
          ),
        );
      },
    );
  }
}

class _DiyaPainter extends CustomPainter {
  final Color bowlFill, bowlStroke, flameOuter, flameInner;
  final double flickerValue;
  final bool isDark;

  _DiyaPainter({
    required this.bowlFill,
    required this.bowlStroke,
    required this.flameOuter,
    required this.flameInner,
    required this.flickerValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Bowl (ellipse at bottom) ──────────────────────────────────────────
    final bowlRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.8),
      width: w * 0.85,
      height: h * 0.25,
    );
    canvas.drawOval(
      bowlRect,
      Paint()..color = bowlFill,
    );
    canvas.drawOval(
      bowlRect,
      Paint()
        ..color = bowlStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── Flame (two overlapping teardrop paths) ────────────────────────────
    final cx = w / 2;
    final flameScaleY = 1.0 + 0.08 * sin(flickerValue * pi);
    final flameScaleX = 1.0 - 0.06 * sin(flickerValue * pi);
    final rotateAngle = -0.026 * sin(flickerValue * pi);

    canvas.save();
    canvas.translate(cx, h * 0.65);
    canvas.rotate(rotateAngle);
    canvas.scale(flameScaleX, flameScaleY);
    canvas.translate(-cx, -h * 0.65);

    // Outer flame
    final outerPath = _flamePath(cx, h * 0.65, w * 0.3, h * 0.55);
    final outerPaint = Paint()..color = flameOuter;
    if (isDark) {
      outerPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }
    canvas.drawPath(outerPath, outerPaint);

    // Inner flame
    final innerPath = _flamePath(cx, h * 0.63, w * 0.2, h * 0.4);
    canvas.drawPath(innerPath, Paint()..color = flameInner);

    canvas.restore();
  }

  Path _flamePath(double cx, double baseY, double halfWidth, double height) {
    return Path()
      ..moveTo(cx, baseY)
      ..cubicTo(
        cx - halfWidth * 1.8, baseY - height * 0.5,
        cx - halfWidth * 0.6, baseY - height * 0.95,
        cx, baseY - height,
      )
      ..cubicTo(
        cx + halfWidth * 0.6, baseY - height * 0.95,
        cx + halfWidth * 1.8, baseY - height * 0.5,
        cx, baseY,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_DiyaPainter oldDelegate) =>
      flickerValue != oldDelegate.flickerValue ||
      bowlFill != oldDelegate.bowlFill;
}
