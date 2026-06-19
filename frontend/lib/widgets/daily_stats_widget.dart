import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A row of three compact metric cards for the dashboard.
///
/// Displays: Questions Today | Accuracy % | Streak Days.
/// Purely presentational — all data passed in via constructor.
class DailyStatsWidget extends StatelessWidget {
  final int questionsToday;
  final double accuracyPercent;
  final int streakDays;

  const DailyStatsWidget({
    super.key,
    required this.questionsToday,
    required this.accuracyPercent,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryLight,
            value: '$questionsToday',
            label: 'Questions Today',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.secondaryLight,
            value: '${accuracyPercent.toStringAsFixed(0)}%',
            label: 'Accuracy',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.streak,
            iconBgColor: const Color(0xFFFFF7ED),
            value: '$streakDays',
            label: 'Day Streak',
          ),
        ),
      ],
    );
  }
}

/// Individual stat card — icon in a tinted circle, bold value, small label.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
