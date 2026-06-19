import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Data point for the radar chart.
class RadarDataPoint {
  final String subject;
  final double score;

  const RadarDataPoint({required this.subject, required this.score});
}

class WeaknessRadarChart extends StatelessWidget {
  final List<RadarDataPoint> dataPoints;
  final void Function(String subject)? onSubjectSelected;

  const WeaknessRadarChart({
    super.key,
    required this.dataPoints,
    this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RadarChart(
      RadarChartData(
        radarTouchData: RadarTouchData(
          touchCallback: (FlTouchEvent event, RadarTouchResponse? response) {
            if (response != null && response.touchedSpot != null && event is FlTapUpEvent) {
            final int index = response.touchedSpot!.touchedDataSetIndex; 
      
            if (index >= 0 && index < dataPoints.length) {
              onSubjectSelected?.call(dataPoints[index].subject);
            }
          }
        },
      ),
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        getTitle: (int index, double angle) {
          if (index >= 0 && index < dataPoints.length) {
            return RadarChartTitle(
              text: dataPoints[index].subject,
              angle: angle,
              positionPercentageOffset: 0.1,
            );
          }
          return const RadarChartTitle(text: '');
        },
        dataSets: [
          RadarDataSet(
            dataEntries: dataPoints
                .map((point) => RadarEntry(value: point.score))
                .toList(),
            borderColor: theme.colorScheme.primary,
            fillColor: theme.colorScheme.primary.withAlpha(50),
            entryRadius: 3.0,
            borderWidth: 2.0,
          ),
        ],
        tickCount: 5,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        tickBorderData: const BorderSide(color: Colors.transparent),
        gridBorderData: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
        radarBorderData: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }
}
