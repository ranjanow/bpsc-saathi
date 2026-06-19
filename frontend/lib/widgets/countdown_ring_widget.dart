import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular countdown ring showing syllabus completion and days until exam.
///
/// Displays a ring progress indicator with the syllabus % inside,
/// and text labels for days remaining below.
class CountdownRingWidget extends StatefulWidget {
  final double syllabusPercent; // 0.0 – 1.0
  final int daysRemaining;
  final String examLabel;

  const CountdownRingWidget({
    super.key,
    this.syllabusPercent = 0.68,
    this.daysRemaining = 42,
    this.examLabel = 'BPSC Prelims',
  });

  @override
  State<CountdownRingWidget> createState() => _CountdownRingWidgetState();
}

class _CountdownRingWidgetState extends State<CountdownRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.syllabusPercent,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final pct = (widget.syllabusPercent * 100).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ring ──────────────────────────────────────────────
          SizedBox(
            width: 92,
            height: 92,
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: _progressAnim.value,
                    trackColor: t.borderColor,
                    fillColor: t.primary,
                    strokeWidth: 8,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontFamily: t.displayFontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                        Text(
                          'syllabus',
                          style: TextStyle(
                            fontFamily: t.bodyFontFamily,
                            fontSize: 9,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // ── Days remaining ───────────────────────────────────
          Text(
            '${widget.daysRemaining} days',
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'until ${widget.examLabel}',
            style: TextStyle(
              fontSize: 13,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$pct% of syllabus covered',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom ring progress painter.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Fill arc
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start from top
      sweepAngle,
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      progress != old.progress || fillColor != old.fillColor;
}
