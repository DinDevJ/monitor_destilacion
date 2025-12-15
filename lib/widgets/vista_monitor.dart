import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sensor_chart.dart';
import 'sensor_chart_multi.dart'; // <--- Este import ahora leerá el archivo corregido
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
  int _sensorAmbienteSeleccionado = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  String _getDato(int index) => (index < widget.datosRaw.length) ? widget.datosRaw[index] : "--";

  @override
  Widget build(BuildContext context) {
    bool esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(child: esHorizontal ? _buildVistaHorizontal() : _buildVistaVertical()),
    );
  }

  Widget _buildVistaVertical() {
    return Column(children: [
      _header(),
      Expanded(flex: 4, child: Container(color: const Color(0xFF1E1E1E), child: _graficas())),
      const Divider(color: Colors.white24, height: 1),
      Expanded(flex: 6, child: ListView(padding: const EdgeInsets.all(12), children: _detalles())),
    ]);
  }

  Widget _buildVistaHorizontal() {
    return Row(children: [
      Expanded(flex: 6, child: Container(padding: const EdgeInsets.all(10), color: const Color(0xFF121212), child: _graficas())),
      const VerticalDivider(width: 1, color: Colors.white24),
      Expanded(flex: 4, child: Column(children: [
        _header(),
        TabBar(controller: _tabController, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blueAccent, dividerColor: Colors.transparent,
            tabs: const [Tab(icon: Icon(Icons.thermostat)), Tab(icon: Icon(Icons.speed)), Tab(icon: Icon(Icons.cloud)), Tab(icon: Icon(Icons.flash_on))]),
        Expanded(child: AnimatedBuilder(animation: _tabController, builder: (ctx, _) => ListView(padding: const EdgeInsets.all(12), children: _tabs(_tabController.index)))),
      ])),
    ]);
  }

  Widget _header() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: const Color(0xFF1E1E1E), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [const Icon(Icons.bluetooth_connected, color: Colors.blueAccent, size: 16), const SizedBox(width: 8), Text(widget.nombreDispositivo, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]),
      Row(children: [IconButton(icon: const Icon(Icons.save_alt, color: Colors.greenAccent), onPressed: widget.onExportar), IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), onPressed: widget.onDesconectar)])
    ]));
  }

  Widget _graficas() {
    bool hor = MediaQuery.of(context).orientation == Orientation.landscape;
    return Column(children: [
      if (!hor) TabBar(controller: _tabController, isScrollable: true, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blueAccent, dividerColor: Colors.transparent, tabs: const [Tab(text: "Temperaturas"), Tab(text: "Presiones"), Tab(text: "Ambiente"), Tab(text: "Eléctrico")]),
      Expanded(child: AnimatedBuilder(animation: Listenable.merge([_tabController]), builder: (ctx, _) => _chartLogic())),
    ]);
  }

  Widget _chartLogic() {
    // ESTO YA NO DARÁ ERROR PORQUE EL PASO 1 ARREGLÓ "SensorChartMulti"
    switch (_tabController.index) {
      case 0: return _pad(SensorChartMulti(lineas: widget.historialTemps, minY: 0, maxY: 200, intervalY: 20, unidadTooltip: "°C"));
      case 1: return _pad(SensorChartMulti(lineas: widget.historialPresionesSistema, minY: 0, maxY: 60, intervalY: 10, unidadTooltip: "Psi"));
      case 2:
        if(_sensorAmbienteSeleccionado == 0) return _pad(SensorChart(puntos: widget.historialTempAmb, colorLinea: Colors.green, minY: 0, maxY: 50));
        if(_sensorAmbienteSeleccionado == 1) return _pad(SensorChart(puntos: widget.historialHumedad, colorLinea: Colors.lightBlue, minY: 0, maxY: 100));
        return _pad(SensorChart(puntos: widget.historialPresionAtm, colorLinea: Colors.blueGrey, minY: 80000, maxY: 110000));
      case 3: return _pad(SensorChart(puntos: widget.historialPotencia, colorLinea: Colors.purpleAccent, minY: 0, maxY: 2000));
      default: return const SizedBox();
    }
  }

  Widget _pad(Widget w) => Padding(padding: const EdgeInsets.fromLTRB(5, 10, 20, 0), child: w);

  List<Widget> _detalles() => [..._bTemps(), ..._bPres(), ..._bElec(), ..._bAmb()];
  List<Widget> _tabs(int i) { if(i==0)return _bTemps(); if(i==1)return _bPres(); if(i==2)return _bAmb(); if(i==3)return _bElec(); return []; }

  List<Widget> _bTemps() {
    return [_tit("Temperaturas de Proceso", Colors.orangeAccent), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.5, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
      _card("S1", _getDato(0), "°C", Colors.orange, widget.historialTemps[0], graf: SensorChartMulti.coloresFijos[0]),
      _card("S2", _getDato(1), "°C", Colors.orange, widget.historialTemps[1], graf: SensorChartMulti.coloresFijos[1]),
      _card("S3", _getDato(2), "°C", Colors.orange, widget.historialTemps[2], graf: SensorChartMulti.coloresFijos[2]),
      _card("S4", _getDato(3), "°C", Colors.orange, widget.historialTemps[3], graf: SensorChartMulti.coloresFijos[3]),
      _card("S5", _getDato(4), "°C", Colors.orange, widget.historialTemps[4], graf: SensorChartMulti.coloresFijos[4]),
      _card("S6", _getDato(5), "°C", Colors.orange, widget.historialTemps[5], graf: SensorChartMulti.coloresFijos[5]),
      _card("S7", _getDato(6), "°C", Colors.orange, widget.historialTemps[6], graf: SensorChartMulti.coloresFijos[6]),
    ])];
  }

  List<Widget> _bPres() {
    return [_tit("Presiones (Psi)", Colors.blueAccent), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.5, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
      _card("Hervidor", _getDato(10), "Psi", Colors.blue, widget.historialPresionesSistema[0], graf: SensorChartMulti.coloresFijos[0]),
      _card("S2", _getDato(11), "Psi", Colors.blue, widget.historialPresionesSistema[1], graf: SensorChartMulti.coloresFijos[1]),
      _card("S3", _getDato(12), "Psi", Colors.blue, widget.historialPresionesSistema[2], graf: SensorChartMulti.coloresFijos[2]),
      _card("S4", _getDato(13), "Psi", Colors.blue, widget.historialPresionesSistema[3], graf: SensorChartMulti.coloresFijos[3]),
      _card("S5", _getDato(14), "Psi", Colors.blue, widget.historialPresionesSistema[4], graf: SensorChartMulti.coloresFijos[4]),
      _card("S6", _getDato(15), "Psi", Colors.blue, widget.historialPresionesSistema[5], graf: SensorChartMulti.coloresFijos[5]),
      _card("S7", _getDato(16), "Psi", Colors.blue, widget.historialPresionesSistema[6], graf: SensorChartMulti.coloresFijos[6]),
    ])];
  }

  List<Widget> _bAmb() {
    return [_tit("Ambiente", Colors.greenAccent),
      _inter(0, "Temp. Amb", _getDato(8), "°C", Colors.green), const SizedBox(height: 8),
      _inter(1, "Humedad", _getDato(7), "%", Colors.lightBlue), const SizedBox(height: 8),
      _inter(2, "Presión Atm", _getDato(9), "Pa", Colors.blueGrey), const SizedBox(height: 20),
      if(_getDato(17)=="1" || _getDato(18)=="1" || _getDato(19)=="1" || _getDato(20)=="1") _tit("ALERTAS", Colors.red),
      if(_getDato(17)=="1") _alert("Falla Sensor"), if(_getDato(18)=="1") _alert("Falla Reflujo"),
    ];
  }

  List<Widget> _bElec() {
    return [_tit("Eléctrico", Colors.purpleAccent), Row(children: [Expanded(child: _mini("Voltaje", _getDato(22), "V", Colors.yellowAccent)), const SizedBox(width: 5), Expanded(child: _mini("Corriente", _getDato(21), "A", Colors.blueAccent))]), const SizedBox(height: 10), _card("Potencia", _getDato(23), "W", Colors.purpleAccent, widget.historialPotencia)];
  }

  Widget _tit(String t, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c)));
  Widget _card(String t, String v, String u, Color c, List<FlSpot> h, {Color? graf}) => GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaDetalle(titulo: t, valorActual: v, unidad: u, historial: h, colorTema: c))), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), padding: const EdgeInsets.all(8), child: Row(children: [graf!=null?Container(width:10,height:10,decoration:BoxDecoration(color:graf,shape:BoxShape.circle)):Icon(Icons.thermostat,color:c,size:20),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(t,style:const TextStyle(fontSize:10,color:Colors.white54),overflow:TextOverflow.ellipsis),Text("$v $u",style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:c))]))])));
  Widget _inter(int idx, String t, String v, String u, Color c) { bool sel = _sensorAmbienteSeleccionado == idx && _tabController.index == 2; return InkWell(onTap: (){ setState(() { _sensorAmbienteSeleccionado = idx; if(_tabController.index!=2) _tabController.animateTo(2); }); }, child: Container(decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? c : Colors.white12, width: sel?2:1)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), child: Row(children: [Icon(Icons.touch_app, color: c, size: 20), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: Colors.white70))), Text("$v $u", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c))]))); }
  Widget _mini(String t, String v, String u, Color c) => Container(decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.all(8), child: Column(children: [Text(t, style: const TextStyle(fontSize: 10, color: Colors.white54)), Text("$v $u", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))]));
  Widget _alert(String m) => Card(color: const Color(0xFF3E1E1E), child: ListTile(leading: const Icon(Icons.warning, color: Colors.redAccent, size: 20), title: Text(m, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)), dense: true));
}