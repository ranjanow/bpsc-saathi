import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Data for a single subject tile.
class SubjectData {
  final String name;
  final IconData icon;
  final double progressPercent; // 0.0 – 1.0

  const SubjectData({
    required this.name,
    required this.icon,
    required this.progressPercent,
  });
}

/// Default BPSC subjects — fresh start with 0% progress.
final List<SubjectData> defaultSubjects = [
  const SubjectData(name: 'Bihar history', icon: Icons.account_balance_rounded, progressPercent: 0.0),
  const SubjectData(name: 'Indian polity', icon: Icons.gavel_rounded, progressPercent: 0.0),
  const SubjectData(name: 'Economy', icon: Icons.bar_chart_rounded, progressPercent: 0.0),
  const SubjectData(name: 'Geography', icon: Icons.public_rounded, progressPercent: 0.0),
  const SubjectData(name: 'General science', icon: Icons.science_rounded, progressPercent: 0.0),
  const SubjectData(name: 'Current affairs', icon: Icons.article_rounded, progressPercent: 0.0),
];

/// A grid of subject progress tiles — "Continue learning" section.
class SubjectTileGrid extends StatelessWidget {
  final List<SubjectData> subjects;
  final ValueChanged<SubjectData>? onSubjectTap;

  const SubjectTileGrid({
    super.key,
    this.subjects = const [],
    this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final data = subjects.isEmpty ? defaultSubjects : subjects;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardSurface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.borderColor),
        boxShadow: t.brightness == Brightness.dark
            ? [BoxShadow(color: t.borderColor, blurRadius: 0, spreadRadius: 1)]
            : [
                BoxShadow(
                  color: t.primary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTINUE LEARNING',
            style: TextStyle(
              fontFamily: t.displayFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600
                  ? 3
                  : constraints.maxWidth > 360
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: data.length,
                itemBuilder: (context, i) => _SubjectTile(
                  data: data[i],
                  onTap: onSubjectTap != null ? () => onSubjectTap!(data[i]) : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Individual subject tile with icon, name, progress bar, and percentage.
class _SubjectTile extends StatefulWidget {
  final SubjectData data;
  final VoidCallback? onTap;

  const _SubjectTile({required this.data, this.onTap});

  @override
  State<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends State<_SubjectTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.data.progressPercent,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    // Delay start so user sees the animation fill in
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _progressController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BpscThemeData.of(context);
    final pct = (widget.data.progressPercent * 100).round();

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isHovered ? t.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(
              color: _isHovered ? t.primary.withValues(alpha: 0.3) : t.borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.data.icon, size: 16, color: t.primary),
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                widget.data.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Progress bar (animated)
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      minHeight: 5,
                      backgroundColor: t.borderColor,
                      valueColor: AlwaysStoppedAnimation(t.secondary),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              // Percentage
              Text(
                '$pct% complete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
