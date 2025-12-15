import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sensor_chart.dart';
import 'sensor_chart_multi.dart';
import 'pantalla_detalle.dart';

class VistaMonitor extends StatefulWidget {
  final String nombreDispositivo;
  final List<String> datosRaw;
  final List<List<FlSpot>> historialTemps;
  final List<List<FlSpot>> historialPresionesSistema;
  final List<FlSpot> historialPresionAtm;
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
    required this.historialPresionesSistema,
    required this.historialPresionAtm,
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
  int _tempSeleccionada = -1;
  int _presionSeleccionada = -1;
  int _ambienteSeleccionado = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if(!_tabController.indexIsChanging) setState(() {});
    });
  }

  String _getDato(int index) => (index < widget.datosRaw.length) ? widget.datosRaw[index] : "--";

  @override
  Widget build(BuildContext context) {
    bool esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: esHorizontal ? _buildVistaHorizontal() : _buildVistaVertical(),
      ),
    );
  }

  Widget _buildVistaVertical() {
    return Column(
      children: [
        _buildHeaderCompacto(),
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
            color: const Color(0xFF1E1E1E),
            child: AnimatedBuilder(
                animation: _tabController,
                builder: (ctx, _) => _buildGraficaInteligente()
            ),
          ),
        ),
        Container(
          color: const Color(0xFF1E1E1E),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.thermostat), text: "Temp"),
              Tab(icon: Icon(Icons.speed), text: "Pres"),
              Tab(icon: Icon(Icons.cloud), text: "Amb"),
              Tab(icon: Icon(Icons.flash_on), text: "Elec"),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (ctx, _) => ListView(
              padding: const EdgeInsets.all(12),
              children: _buildDatosDePestana(_tabController.index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVistaHorizontal() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF121212),
            child: AnimatedBuilder(
                animation: _tabController,
                builder: (ctx, _) => _buildGraficaInteligente()
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.white24),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildHeaderCompacto(),
              Container(
                color: const Color(0xFF1E1E1E),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueAccent,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.thermostat), text: "Temp"),
                    Tab(icon: Icon(Icons.speed), text: "Pres"),
                    Tab(icon: Icon(Icons.cloud), text: "Amb"),
                    Tab(icon: Icon(Icons.flash_on), text: "Elec"),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (ctx, _) => ListView(
                      padding: const EdgeInsets.all(12),
                      children: _buildDatosDePestana(_tabController.index),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGraficaInteligente() {
    switch (_tabController.index) {
      case 0:
        return SensorChartMulti(lineas: widget.historialTemps, lineaSeleccionada: _tempSeleccionada, minY: 0, maxY: 200, intervalY: 25, unidadTooltip: "°C");
      case 1:
        return SensorChartMulti(lineas: widget.historialPresionesSistema, lineaSeleccionada: _presionSeleccionada, minY: 0, maxY: 60, intervalY: 10, unidadTooltip: "Psi");
      case 2:
        if (_ambienteSeleccionado == 0) return SensorChart(puntos: widget.historialTempAmb, colorLinea: Colors.green, minY: 0, maxY: 50, intervalY: 5);
        if (_ambienteSeleccionado == 1) return SensorChart(puntos: widget.historialHumedad, colorLinea: Colors.lightBlue, minY: 0, maxY: 100, intervalY: 20);
        return SensorChart(puntos: widget.historialPresionAtm, colorLinea: Colors.blueGrey, minY: 0, maxY: 100);
      case 3:
        return SensorChart(puntos: widget.historialPotencia, colorLinea: Colors.purpleAccent, minY: 0, maxY: 2000, intervalY: 250);
      default: return const SizedBox();
    }
  }

  List<Widget> _buildDatosDePestana(int index) {
    switch (index) {
      case 0: return _buildGridTemperaturas();
      case 1: return _buildGridPresiones();
      case 2: return _buildListaAmbiente();
      case 3: return _buildListaElectrico();
      default: return [];
    }
  }

  List<Widget> _buildGridTemperaturas() {
    final cols = SensorChartMulti.coloresFijos;
    return [
      _btnResetSelection(() => setState(() => _tempSeleccionada = -1), "Ver Todas las Temperaturas"),
      const SizedBox(height: 10),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.0, // <-- ARREGLADO
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        children: [
          _cardSelectable(0, "Hervidor", _getDato(0), "°C", Colors.orange, cols[0], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(1, "Plato 2", _getDato(1), "°C", Colors.orange, cols[1], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(2, "Plato 4", _getDato(2), "°C", Colors.orange, cols[2], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(3, "Plato 6", _getDato(3), "°C", Colors.orange, cols[3], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(4, "Plato 8", _getDato(4), "°C", Colors.orange, cols[4], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(5, "Plato 10", _getDato(5), "°C", Colors.orange, cols[5], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
          _cardSelectable(6, "Condensador", _getDato(6), "°C", Colors.orange, cols[6], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)),
        ],
      )
    ];
  }

  List<Widget> _buildGridPresiones() {
    final cols = SensorChartMulti.coloresFijos;
    return [
      _btnResetSelection(() => setState(() => _presionSeleccionada = -1), "Ver Todas las Presiones"),
      const SizedBox(height: 10),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.0, // <-- ARREGLADO
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        children: [
          _cardSelectable(0, "Hervidor", _getDato(10), "Psi", Colors.blue, cols[0], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(1, "S2", _getDato(11), "Psi", Colors.blue, cols[1], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(2, "S3", _getDato(12), "Psi", Colors.blue, cols[2], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(3, "S4", _getDato(13), "Psi", Colors.blue, cols[3], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(4, "S5", _getDato(14), "Psi", Colors.blue, cols[4], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(5, "S6", _getDato(15), "Psi", Colors.blue, cols[5], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
          _cardSelectable(6, "S7", _getDato(16), "Psi", Colors.blue, cols[6], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)),
        ],
      )
    ];
  }

  List<Widget> _buildListaAmbiente() {
    return [
      _cardAmbiente(0, "Temp. Ambiente", _getDato(8), "°C", Colors.green, Icons.thermostat),
      const SizedBox(height: 8),
      _cardAmbiente(1, "Humedad", _getDato(7), "%", Colors.lightBlue, Icons.water_drop),
      const SizedBox(height: 8),
      _cardAmbiente(2, "Presión Atm", _getDato(9), "Pa", Colors.blueGrey, Icons.speed),
      const SizedBox(height: 20),
      if(_hayErrores()) const Text("ALERTAS DEL SISTEMA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      if(_getDato(17)=="1") _alerta("Falla Sensor"),
      if(_getDato(18)=="1") _alerta("Falla Reflujo"),
    ];
  }

  List<Widget> _buildListaElectrico() {
    return [
      Row(children: [
        Expanded(child: _miniCard("Voltaje", _getDato(22), "V", Colors.yellowAccent)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard("Corriente", _getDato(21), "A", Colors.blueAccent)),
      ]),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purpleAccent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Potencia Total", style: TextStyle(color: Colors.white70)),
            Text("${_getDato(23)} W", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
          ],
        ),
      )
    ];
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildHeaderCompacto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [const Icon(Icons.bluetooth_connected, color: Colors.blueAccent, size: 16), const SizedBox(width: 8), Text(widget.nombreDispositivo, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]),
        Row(children: [IconButton(icon: const Icon(Icons.save_alt, color: Colors.greenAccent), onPressed: widget.onExportar), IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), onPressed: widget.onDesconectar)])
      ]),
    );
  }

  Widget _btnResetSelection(VoidCallback onTap, String text) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
      label: Text(text, style: const TextStyle(color: Colors.white54)),
      style: TextButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
    );
  }

  Widget _cardSelectable(int index, String title, String val, String unit, Color colorText, Color colorDot, int currentSelection, Function(int) onSelect) {
    bool isSelected = (currentSelection == index);
    return InkWell(
      onTap: () => onSelect(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? colorText.withOpacity(0.1) : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? colorText : Colors.transparent, width: 1.5),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colorDot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text("$val $unit", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorText)),
          ],
        ),
      ),
    );
  }

  Widget _cardAmbiente(int index, String title, String val, String unit, Color color, IconData icono) {
    bool isSelected = (_ambienteSeleccionado == index);
    return InkWell(
      onTap: () => setState(() => _ambienteSeleccionado = index),
      child: Container(
        decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5)
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icono, size: 24, color: color), const SizedBox(width: 12), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14))]),
            Text("$val $unit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String title, String val, String unit, Color color) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 5),
          Text("$val $unit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _alerta(String msg) => Card(color: const Color(0xFF3E1E1E), child: ListTile(leading: const Icon(Icons.warning, color: Colors.redAccent), title: Text(msg, style: const TextStyle(color: Colors.redAccent))));

  bool _hayErrores() => (_getDato(17)=="1" || _getDato(18)=="1");
}