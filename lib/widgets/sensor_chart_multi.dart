import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class SensorChartMulti extends StatelessWidget {
  final List<List<FlSpot>> lineas;
  final double? minY;
  final double? maxY;
  final double? intervalY;
  final String unidadTooltip;

  const SensorChartMulti({
    super.key,
    required this.lineas,
    this.minY,
    this.maxY,
    this.intervalY,
    this.unidadTooltip = "",
  });

  static const List<Color> coloresFijos = [
    Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent,
    Colors.purpleAccent, Colors.tealAccent, Colors.pinkAccent,
  ];

  @override
  Widget build(BuildContext context) {
    double maxX = 0;
    for (var linea in lineas) {
      if (linea.isNotEmpty) maxX = max(maxX, linea.last.x);
    }
    if (maxX < 60) maxX = 60;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: maxX - 60,
        maxX: maxX,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.grey[900]!,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(1)} $unidadTooltip',
                  TextStyle(color: barSpot.bar.color, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 40, interval: intervalY,
              getTitlesWidget: (value, meta) {
                if (intervalY != null || value % 10 == 0) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
        lineBarsData: List.generate(lineas.length, (index) {
          return LineChartBarData(
            spots: lineas[index], isCurved: true,
            color: coloresFijos[index % coloresFijos.length],
            barWidth: 2, isStrokeCapRound: true, dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          );
        }),
      ),
    );
  }
}