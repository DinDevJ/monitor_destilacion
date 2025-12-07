import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SensorChart extends StatelessWidget {
  final List<FlSpot> puntos;
  final Color colorLinea;
  final bool mostrarPuntos;

  const SensorChart({
    super.key,
    required this.puntos,
    this.colorLinea = Colors.blue,
    this.mostrarPuntos = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. CALCULAR LÍMITES INTELIGENTES (Igual que antes)
    double minY = 0;
    double maxY = 100;

    if (puntos.isNotEmpty) {
      double minValor = puntos.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      double maxValor = puntos.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      double diferencia = maxValor - minValor;

      if (diferencia < 5) {
        double centro = (minValor + maxValor) / 2;
        minY = centro - 5;
        maxY = centro + 5;
      } else {
        double margen = diferencia * 0.2;
        minY = minValor - margen;
        maxY = maxValor + margen;
      }
    }

    // --- AQUÍ EMPIEZA LA MAGIA DEL ZOOM ---
    return ClipRect( // 1. Corta lo que se salga del recuadro al hacer zoom
      child: InteractiveViewer( // 2. Permite gestos de pinza y arrastre
        panEnabled: true, // Permite moverse por la gráfica si está con zoom
        boundaryMargin: const EdgeInsets.all(0),
        minScale: 1.0, // No deja hacerla más chica que el original
        maxScale: 5.0, // Permite hacer zoom hasta 5x
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (value, meta) {
                    if (value >= 1000) return Text("${(value/1000).toStringAsFixed(1)}k", style: const TextStyle(fontSize: 10));
                    return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: puntos,
                isCurved: true,
                color: colorLinea,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: mostrarPuntos),
                belowBarData: BarAreaData(
                  show: true,
                  color: colorLinea.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}