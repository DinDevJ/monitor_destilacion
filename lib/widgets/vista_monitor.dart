import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sensor_chart.dart';
import 'sensor_chart_multi.dart'; // Importamos para acceder a la lista de colores
import 'pantalla_detalle.dart';

class VistaMonitor extends StatefulWidget {
  final String nombreDispositivo;
  final List<String> datosRaw;

  final List<List<FlSpot>> historialTemps;
  final List<FlSpot> historialPresion;
  final List<FlSpot> historialHumedad;
  final List<FlSpot> historialTempAmb;
  final List<FlSpot> historialPotencia;

  final VoidCallback onDesconectar;
  final VoidCallback onExportar;

  const VistaMonitor({
    super.key,
    required this.nombreDispositivo,
    required this.datosRaw,
    required this.historialTemps,
    required this.historialPresion,
    required this.historialHumedad,
    required this.historialTempAmb,
    required this.historialPotencia,
    required this.onDesconectar,
    required this.onExportar,
  });

  @override
  State<VistaMonitor> createState() => _VistaMonitorState();
}

class _VistaMonitorState extends State<VistaMonitor> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    bool datosListos = widget.datosRaw.length >= 20;

    // Obtenemos los colores oficiales de la gráfica
    final List<Color> colores = SensorChartMulti.coloresFijos;

    return Column(
      children: [
        // --- CABECERA ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Conectado a: ${widget.nombreDispositivo}", style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.red), onPressed: widget.onDesconectar)
            ],
          ),
        ),

        // --- GRÁFICAS ---
        Container(
          color: Colors.white,
          height: 280,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue[800],
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                isScrollable: true,
                tabs: const [
                  Tab(text: "Temperaturas"),
                  Tab(text: "Presión Atm"),
                  Tab(text: "Humedad"),
                  Tab(text: "Potencia"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _chartPadding(SensorChartMulti(lineas: widget.historialTemps)),
                    _chartPadding(SensorChart(puntos: widget.historialPresion, colorLinea: Colors.blue)),
                    _chartPadding(SensorChart(puntos: widget.historialHumedad, colorLinea: Colors.lightBlue)),
                    _chartPadding(SensorChart(puntos: widget.historialPotencia, colorLinea: Colors.purple)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(thickness: 2),

        // --- LISTA ---
        Expanded(
          child: !datosListos
              ? const Center(child: Text("Esperando datos de la máquina..."))
              : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _tituloSeccion("Temperaturas de Proceso"),

              // AQUI PASAMOS EL COLOR ESPECÍFICO A CADA TARJETA
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _cardSensor("S1 (Entrada)", widget.datosRaw[0], "°C", Colors.orange, widget.historialTemps[0], colorGrafica: colores[0]),
                  _cardSensor("S2", widget.datosRaw[1], "°C", Colors.orange, widget.historialTemps[1], colorGrafica: colores[1]),
                  _cardSensor("S3", widget.datosRaw[2], "°C", Colors.orange, widget.historialTemps[2], colorGrafica: colores[2]),
                  _cardSensor("S4", widget.datosRaw[3], "°C", Colors.orange, widget.historialTemps[3], colorGrafica: colores[3]),
                  _cardSensor("S5", widget.datosRaw[4], "°C", Colors.orange, widget.historialTemps[4], colorGrafica: colores[4]),
                  _cardSensor("S6", widget.datosRaw[5], "°C", Colors.orange, widget.historialTemps[5], colorGrafica: colores[5]),
                  _cardSensor("S7", widget.datosRaw[6], "°C", Colors.orange, widget.historialTemps[6], colorGrafica: colores[6]),

                  // Ambiente no sale en la gráfica multi, no lleva bolita
                  _cardSensor("Ambiente", widget.datosRaw[9], "°C", Colors.green, widget.historialTempAmb),
                ],
              ),

              const SizedBox(height: 15),

              _tituloSeccion("Presiones del Sistema"),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                children: [
                  _cardMini("P. Hervidor", widget.datosRaw[10], "Psi"),
                  _cardMini("P. Sensor 2", widget.datosRaw[11], "Psi"),
                  _cardMini("P. Sensor 3", widget.datosRaw[12], "Psi"),
                  _cardMini("P. Sensor 4", widget.datosRaw[13], "Psi"),
                  _cardMini("P. Sensor 5", widget.datosRaw[14], "Psi"),
                  _cardMini("P. Sensor 6", widget.datosRaw[15], "Psi"),
                  _cardMini("P. Sensor 7", widget.datosRaw[16], "Psi"),
                ],
              ),

              const SizedBox(height: 15),

              _tituloSeccion("Sistema Eléctrico"),
              Row(
                children: [
                  Expanded(child: _cardMini("Voltaje", widget.datosRaw[22], "V", color: Colors.yellow[800]!)),
                  const SizedBox(width: 5),
                  Expanded(child: _cardMini("Corriente", widget.datosRaw[21], "A", color: Colors.blue[800]!)),
                  const SizedBox(width: 5),
                  Expanded(child: _cardMini("Potencia", widget.datosRaw.length > 23 ? widget.datosRaw[23] : "-", "W", color: Colors.purple)),
                ],
              ),

              const SizedBox(height: 15),

              if(_hayErrores()) _tituloSeccion("ALERTAS DEL SISTEMA", color: Colors.red),
              if(widget.datosRaw[17] == "1") _alerta("Falla en Sensor"),
              if(widget.datosRaw[18] == "1") _alerta("Falla Reflujo"),
              if(widget.datosRaw[19] == "1") _alerta("Fuga Detectada"),
              if(widget.datosRaw[20] == "1") _alerta("Falla Válvula"),

              const SizedBox(height: 10),
              _tituloSeccion("Ambiente"),
              Row(
                children: [
                  Expanded(child: _cardSensor("Humedad", widget.datosRaw[7], "%", Colors.lightBlue, widget.historialHumedad)),
                  const SizedBox(width: 10),
                  Expanded(child: _cardSensor("Presión Atm", widget.datosRaw[8], "Pa", Colors.blueGrey, widget.historialPresion)),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text("Exportar Datos Completos"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white
            ),
            onPressed: widget.onExportar,
          ),
        )
      ],
    );
  }

  Widget _tituloSeccion(String texto, {Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(texto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    );
  }

  Widget _chartPadding(Widget chart) {
    return Padding(padding: const EdgeInsets.all(12.0), child: chart);
  }

  // --- MODIFICADO: AHORA ACEPTA "colorGrafica" ---
  Widget _cardSensor(String titulo, String valor, String unidad, Color colorTema, List<FlSpot> historial, {Color? colorGrafica}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaDetalle(
            titulo: titulo,
            valorActual: valor,
            unidad: unidad,
            historial: historial,
            colorTema: colorTema // Para el detalle usamos el color temático (Naranja)
        )));
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
            border: Border.all(color: colorTema.withOpacity(0.3))
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            // 1. SI HAY COLOR DE GRÁFICA, MOSTRAMOS LA BOLITA
            if (colorGrafica != null) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: colorGrafica, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ] else ...[
              // Si no hay color de gráfica, mostramos el icono normal
              Icon(Icons.thermostat, color: colorTema, size: 28),
              const SizedBox(width: 8),
            ],

            // 2. TEXTOS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey[800], fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis,),
                  Text("$valor $unidad", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorTema)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _cardMini(String titulo, String valor, String unidad, {Color color = Colors.blueGrey}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!)
      ),
      padding: const EdgeInsets.all(5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center,),
          Text("$valor $unidad", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _alerta(String mensaje){
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.red),
        title: Text(mensaje, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ),
    );
  }

  bool _hayErrores(){
    if(widget.datosRaw.length < 21) return false;
    return (widget.datosRaw[17]=="1" || widget.datosRaw[18]=="1" || widget.datosRaw[19]=="1" || widget.datosRaw[20]=="1");
  }
}