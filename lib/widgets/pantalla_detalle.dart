import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sensor_chart.dart'; // Tu widget de gráfica

class PantallaDetalle extends StatelessWidget {
  final String titulo;
  final String valorActual;
  final String unidad;
  final List<FlSpot> historial;
  final Color colorTema;

  const PantallaDetalle({
    super.key,
    required this.titulo,
    required this.valorActual,
    required this.unidad,
    required this.historial, // Recibimos la historia para la gráfica
    this.colorTema = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: colorTema,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. TARJETA GIGANTE CON EL VALOR
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: colorTema.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    Text("Valor Actual", style: TextStyle(color: Colors.grey[700])),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          valorActual,
                          style: TextStyle(
                              fontSize: 60, fontWeight: FontWeight.bold, color: colorTema),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 5),
                          child: Text(unidad,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 2. LA GRÁFICA (Ahora vive aquí)
            const Text("Comportamiento en el tiempo", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: historial.isEmpty
                  ? const Center(child: Text("Esperando datos para graficar..."))
                  : SensorChart(puntos: historial, colorLinea: colorTema),
            ),
          ],
        ),
      ),
    );
  }
}