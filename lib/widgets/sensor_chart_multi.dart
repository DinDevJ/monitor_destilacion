import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class SensorChartMulti extends StatelessWidget {
  final List<List<FlSpot>> lineas;
  // Si este índice es -1, mostramos TODAS. Si es 0-6, mostramos solo esa.
  final int lineaSeleccionada;

  final double? minY;
  final double? maxY;
  final double? intervalY;
  final String unidadTooltip;

  const SensorChartMulti({
    super.key,
    required this.lineas,
    this.lineaSeleccionada = -1, // Por defecto -1 (Todas)
    this.minY,
    this.maxY,
    this.intervalY,
    this.unidadTooltip = "",
  });

  static const List<Color> coloresFijos = [
    Colors.orange,       // 0: Hervidor
    Colors.blue,         // 1: Plato 2
    Colors.deepPurple,   // 2: Plato 4
    Colors.green,        // 3: Plato 6
    Colors.yellow,       // 4: Plato 8
    Colors.white,        // 5: Plato 10
    Colors.red,    // 6: Condensador
  ];

  @override
  Widget build(BuildContext context) {
    // Calculamos X máximo para el desplazamiento
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
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 40, interval: intervalY,
              getTitlesWidget: (value, meta) {
                // Solo mostrar etiquetas si coinciden con el intervalo
                if (intervalY != null) {
                  if (value % intervalY! == 0) {
                    return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                  }
                } else if (value % 10 == 0) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),

        // AQUÍ ESTÁ LA LÓGICA DE SELECCIÓN
        lineBarsData: List.generate(lineas.length, (index) {
          // Si hay una seleccionada y no es esta, la ocultamos (retornando una línea vacía o transparente)
          if (lineaSeleccionada != -1 && lineaSeleccionada != index) {
            return LineChartBarData(spots: [], show: false);
          }

          return LineChartBarData(
            spots: lineas[index],
            isCurved: true,
            color: coloresFijos[index % coloresFijos.length],
            barWidth: (lineaSeleccionada != -1) ? 4 : 2, // Más gruesa si está sola
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
                show: (lineaSeleccionada != -1), // Sombra solo si está sola
                color: coloresFijos[index % coloresFijos.length].withOpacity(0.1)
            ),
          );
        }),
      ),
    );
  }
}