import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SensorChartMulti extends StatelessWidget {
  final List<List<FlSpot>> lineas;

  const SensorChartMulti({super.key, required this.lineas});

  // --- PALETA DE COLORES PÚBLICA ---
  static const List<Color> coloresFijos = [
    Colors.red,         // Sensor 1
    Colors.blue,        // Sensor 2
    Colors.green,       // Sensor 3
    Colors.orange,      // Sensor 4
    Colors.purple,      // Sensor 5
    Colors.teal,        // Sensor 6
    Colors.pink,        // Sensor 7
  ];

  @override
  Widget build(BuildContext context) {
    double minY = 0;
    double maxY = 100;
    List<FlSpot> todosLosPuntos = lineas.expand((l) => l).toList();

    if (todosLosPuntos.isNotEmpty) {
      double minValor = todosLosPuntos.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      double maxValor = todosLosPuntos.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      double diferencia = maxValor - minValor;

      if (diferencia < 5) {
        double centro = (minValor + maxValor) / 2;
        minY = centro - 5;
        maxY = centro + 5;
      } else {
        double margen = diferencia * 0.1;
        minY = minValor - margen;
        maxY = maxValor + margen;
      }
    }

    // --- AQUÍ AGREGAMOS EL ZOOM ---
    return ClipRect(
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 1.0,
        maxScale: 5.0, // Zoom hasta 5x
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.3))),

            lineBarsData: List.generate(lineas.length, (index) {
              Color colorLinea = coloresFijos[index % coloresFijos.length];
              return LineChartBarData(
                spots: lineas[index],
                isCurved: true,
                color: colorLinea,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              );
            }),
          ),
        ),
      ),
    );
  }
}