import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class SensorChart extends StatelessWidget {
  final List<FlSpot> puntos;
  final Color colorLinea;

  // --- VARIABLES NUEVAS PARA LÍMITES ---
  final double? minY;
  final double? maxY;

  const SensorChart({
    super.key,
    required this.puntos,
    required this.colorLinea,
    this.minY, // Ahora aceptamos minY
    this.maxY, // Ahora aceptamos maxY
  });

  @override
  Widget build(BuildContext context) {
    double maxX = 0;
    if (puntos.isNotEmpty) {
      maxX = puntos.last.x;
    }
    if (maxX < 60) maxX = 60;

    return LineChart(
      LineChartData(
        // USAMOS LOS LÍMITES AQUÍ
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
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(show: false), // Sin títulos para la versión mini/simple
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
        lineBarsData: [
          LineChartBarData(
            spots: puntos,
            isCurved: true,
            color: colorLinea,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true,
                color: colorLinea.withOpacity(0.1)
            ),
          ),
        ],
      ),
    );
  }
}