import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PerformanceAnalyticsDashboard extends StatelessWidget {
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int skippedCount;
  final double netScore;

  final int guessCorrect;
  final int guessIncorrect;

  const PerformanceAnalyticsDashboard({
    super.key,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.skippedCount,
    required this.netScore,
    required this.guessCorrect,
    required this.guessIncorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance Analytics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Component A: Success Rate Bar
            _buildSuccessRateBar(context),
            const SizedBox(height: 32),
            
            // Row for Component B & C
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildGuessworkEfficiency(context)),
                const SizedBox(width: 24),
                Expanded(child: _buildCutoffProximity(context)),
              ],
            ),
            const SizedBox(height: 32),
            
            // Component D: Actionable Insights Engine
            _buildActionableInsights(context),
          ],
        ),
      ),
    );
  }

  // ─── Component A: Success Rate Bar ──────────────────────────────────────────
  Widget _buildSuccessRateBar(BuildContext context) {
    final theme = Theme.of(context);
    final totalAnsweredOrSkipped = correctCount + incorrectCount + skippedCount;
    final displayTotal = totalAnsweredOrSkipped > 0 ? totalAnsweredOrSkipped : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attempt Distribution',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                if (correctCount > 0)
                  Expanded(
                    flex: correctCount,
                    child: Container(color: AppColors.success),
                  ),
                if (incorrectCount > 0)
                  Expanded(
                    flex: incorrectCount,
                    child: Container(color: AppColors.error),
                  ),
                if (skippedCount > 0)
                  Expanded(
                    flex: skippedCount,
                    child: Container(color: AppColors.textDisabled),
                  ),
                if (totalAnsweredOrSkipped == 0)
                  Expanded(
                    child: Container(color: theme.colorScheme.surfaceContainerHighest),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem(context, 'Correct ($correctCount)', AppColors.success),
            _buildLegendItem(context, 'Incorrect ($incorrectCount)', AppColors.error),
            _buildLegendItem(context, 'Skipped ($skippedCount)', AppColors.textDisabled),
          ],
        )
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // ─── Component B: Guesswork Efficiency Gauge ────────────────────────────────
  Widget _buildGuessworkEfficiency(BuildContext context) {
    final theme = Theme.of(context);
    final totalGuesses = guessCorrect + guessIncorrect;
    
    double winRate = 0;
    if (totalGuesses > 0) {
      winRate = guessCorrect / totalGuesses;
    }

    // Mathematical break-even threshold defined as 33.3%
    const double breakEven = 0.333;
    final bool isEfficient = winRate >= breakEven;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guesswork Efficiency',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (totalGuesses == 0)
          Text('No guesswork detected.', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline))
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(winRate * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEfficient ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('win rate', style: theme.textTheme.bodySmall),
              )
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: winRate.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isEfficient ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Break-even marker
              Positioned(
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: breakEven,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 2, height: 8, color: Colors.black87),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Target: >33.3% break-even',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ]
      ],
    );
  }

  // ─── Component C: Cutoff Proximity ──────────────────────────────────────────
  Widget _buildCutoffProximity(BuildContext context) {
    final theme = Theme.of(context);
    const double targetCutoff = 90.0;
    
    // Calculate progress as a ratio of 90 (clamped 0 to 1)
    final double progress = (netScore / targetCutoff).clamp(0.0, 1.0);
    final double shortfall = targetCutoff - netScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cutoff Proximity',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              netScore.toStringAsFixed(2),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: netScore >= targetCutoff ? AppColors.success : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('/ $targetCutoff target', style: theme.textTheme.bodySmall),
            )
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: netScore >= targetCutoff ? AppColors.success : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          netScore >= targetCutoff 
            ? 'Safe zone achieved!' 
            : '${shortfall.toStringAsFixed(2)} marks remaining',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  // ─── Component D: Actionable Insights Engine ────────────────────────────────
  Widget _buildActionableInsights(BuildContext context) {
    final theme = Theme.of(context);
    
    final totalGuesses = guessCorrect + guessIncorrect;
    final guessMarkImpact = (guessCorrect * 1.0) + (guessIncorrect * -0.33);

    String insightHeading = "Strategy Insight";
    String insightBody = "Complete more questions to generate behavioral insights.";
    IconData insightIcon = Icons.lightbulb_outline;
    Color insightColor = theme.colorScheme.primary;

    if (totalQuestions > 0) {
      if (totalGuesses > 0 && guessMarkImpact < -0.5) {
        insightHeading = "Aggressive Guessing Penalty";
        insightBody = "Your doubtful attempts are actively dragging your net score down by ${guessMarkImpact.abs().toStringAsFixed(2)} marks due to the 1/3 negative marking rule. Reduce low-confidence selections and skip if certainty is < 60%.";
        insightIcon = Icons.warning_amber_rounded;
        insightColor = AppColors.warning;
      } else if (totalGuesses > 0 && guessMarkImpact > 0.5) {
        insightHeading = "Effective Elimination";
        insightBody = "Your educated guesswork is paying off, contributing +${guessMarkImpact.toStringAsFixed(2)} marks. Your intuition on 50/50 options is statistically positive. Keep it up.";
        insightIcon = Icons.trending_up;
        insightColor = AppColors.success;
      } else if (incorrectCount > (correctCount * 0.5)) {
        insightHeading = "High Error Rate";
        insightBody = "Your incorrect responses are heavily penalizing your score. Focus on accuracy over volume. Re-read the BPSC syllabus for these concepts.";
        insightIcon = Icons.error_outline;
        insightColor = AppColors.error;
      } else if (skippedCount > (totalQuestions * 0.4)) {
        insightHeading = "Conservative Approach";
        insightBody = "You are skipping a large volume of questions. While safe, you may struggle to clear the 90.0 cutoff without taking measured risks using the elimination method.";
        insightIcon = Icons.shield_outlined;
        insightColor = AppColors.primary;
      } else if (netScore >= 90.0) {
        insightHeading = "Cutoff Trajectory Secured";
        insightBody = "Excellent discipline. You are maintaining a healthy accuracy ratio above the standard BPSC prelims threshold.";
        insightIcon = Icons.check_circle_outline;
        insightColor = AppColors.success;
      } else {
        insightHeading = "Steady Progress";
        insightBody = "Maintain your accuracy. Watch out for negative marking traps on questions you are completely unsure about.";
        insightIcon = Icons.insights;
        insightColor = theme.colorScheme.primary;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: insightColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: insightColor.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insightIcon, color: insightColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightHeading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: insightColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insightBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
