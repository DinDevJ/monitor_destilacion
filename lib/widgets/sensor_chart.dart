import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class SensorChart extends StatelessWidget {
  final List<FlSpot> puntos;
  final Color colorLinea;
  final double? minY;
  final double? maxY;
  final double? intervalY; // <--- Nuevo parámetro

  const SensorChart({
    super.key,
    required this.puntos,
    required this.colorLinea,
    this.minY,
    this.maxY,
    this.intervalY,
  });

  @override
  Widget build(BuildContext context) {
    double maxX = 0;
    if (puntos.isNotEmpty) maxX = puntos.last.x;
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
                  barSpot.y.toStringAsFixed(1),
                  TextStyle(color: barSpot.bar.color, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 45, interval: intervalY, // Usar intervalo
              getTitlesWidget: (value, meta) {
                if (intervalY != null) {
                  if (value % intervalY! == 0) return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                } else if (value % 10 == 0) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
        lineBarsData: [
          LineChartBarData(
            spots: puntos, isCurved: true, color: colorLinea, barWidth: 3,
            isStrokeCapRound: true, dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: colorLinea.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}