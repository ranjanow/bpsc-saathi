import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Hero quiz banner — the prominent CTA card at the top of the dashboard.
///
/// Shows today's quiz challenge with a gradient background and a Start button.
class HeroQuizBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onStartQuiz;

  const HeroQuizBanner({
    super.key,
    this.eyebrow = "Today's challenge",
    this.title = 'Bihar History — Round 14',
    this.subtitle = '10 questions · about 6 minutes · earn 50 XP for finishing',
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final isDark = t.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(
          color: isDark ? t.primary : t.borderColor,
          width: isDark ? 1.5 : 1,
        ),
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
                colors: [t.primarySoft, t.cardSurface],
                stops: const [0, 0.65],
              ),
        boxShadow: isDark
            ? [BoxShadow(color: t.primary.withValues(alpha: 0.08), blurRadius: 24)]
            : [
                BoxShadow(
                  color: t.primary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContent(t),
                const SizedBox(height: 20),
                _buildCta(t, isDark),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildContent(t)),
              const SizedBox(width: 24),
              _buildCta(t, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BpscThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: t.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: t.displayFontFamily,
            fontSize: t.brightness == Brightness.dark ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: t.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCta(BpscThemeData t, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onStartQuiz,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: BorderRadius.circular(t.radius),
            boxShadow: isDark
                ? [BoxShadow(color: t.primary.withValues(alpha: 0.4), blurRadius: 16)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Start quiz',
                style: TextStyle(
                  fontFamily: t.bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? t.bg : Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: isDark ? t.bg : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
