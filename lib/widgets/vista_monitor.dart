import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'sensor_chart.dart';
import 'sensor_chart_multi.dart';
import 'pantalla_detalle.dart';
import 'pantalla_configuracion.dart';

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
  final bool grabando;
  final VoidCallback onToggleGrabacion;
  final Function(Duration) onProgramarTimer;
  final String textoTiempoRestante;
  final bool autoGrabar;
  final Function(bool) onToggleAutoGrabar;
  final bool mostrarTerminal;
  final Function(bool) onToggleMostrarTerminal;

  // --- VARIABLES MODO PRUEBA ---
  final bool modoPruebaErrores;
  final ValueChanged<bool> onToggleModoPruebaErrores;

  // --- NUEVOS CONTROLADORES DE PULSOS ---
  final Function(String) onComandoSimple;       // Para "1v", "1t", "1e"
  final Function(int, int) onConfigurarCamara;  // (fotosPorMin, retardo)
  final VoidCallback onDetenerCamara;
  final bool camaraActiva;

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
    required this.grabando,
    required this.onToggleGrabacion,
    required this.onProgramarTimer,
    required this.textoTiempoRestante,
    required this.autoGrabar,
    required this.onToggleAutoGrabar,
    required this.mostrarTerminal,
    required this.onToggleMostrarTerminal,
    required this.modoPruebaErrores,
    required this.onToggleModoPruebaErrores,

    // --- NUEVOS ---
    required this.onComandoSimple,
    required this.onConfigurarCamara,
    required this.onDetenerCamara,
    required this.camaraActiva,
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

  // --- NUEVO: DIÁLOGO CONFIGURACIÓN CÁMARA ---
  void _mostrarConfigCamara() {
    TextEditingController ctrlFotos = TextEditingController();
    TextEditingController ctrlRetardo = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Configurar Cámara Térmica", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Configura la secuencia de disparos:", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
            TextField(
              controller: ctrlFotos,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Fotos por minuto",
                hintText: "Ej: 6",
                prefixIcon: Icon(Icons.camera_alt, color: Colors.purpleAccent),
                filled: true,
                fillColor: Colors.black26,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlRetardo,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Retardo inicial (segundos)",
                hintText: "Ej: 5",
                prefixIcon: Icon(Icons.timer, color: Colors.purpleAccent),
                filled: true,
                fillColor: Colors.black26,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () {
              int fotos = int.tryParse(ctrlFotos.text) ?? 0;
              int retardo = int.tryParse(ctrlRetardo.text) ?? 0;

              if (fotos > 0) {
                widget.onConfigurarCamara(fotos, retardo);
                Navigator.pop(context);
              }
            },
            child: const Text("Iniciar Secuencia", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarSalida() { showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF2C2C2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Row(children: const [Icon(Icons.power_settings_new, color: Colors.redAccent), SizedBox(width: 10), Text("Desconectar", style: TextStyle(color: Colors.white))]), content: const Text("¿Seguro que quieres salir y desconectar el dispositivo?", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("No", style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () { Navigator.of(context).pop(); widget.onDesconectar(); }, child: const Text("Sí, Salir", style: TextStyle(color: Colors.white))) ])); }
  void _mostrarDialogoTemporizador() { TextEditingController _ctrlTiempo = TextEditingController(); String _unidad = 'Minutos'; showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) { return AlertDialog(backgroundColor: const Color(0xFF2C2C2C), title: const Text("Programar Grabación", style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("La grabación se detendrá automáticamente después de:", style: TextStyle(color: Colors.white70)), const SizedBox(height: 20), Row(children: [Expanded(child: TextField(controller: _ctrlTiempo, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 18), decoration: InputDecoration(hintText: "Ej: 60", hintStyle: TextStyle(color: Colors.white24), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))), const SizedBox(width: 15), DropdownButton<String>(value: _unidad, dropdownColor: const Color(0xFF3E3E3E), style: const TextStyle(color: Colors.white, fontSize: 16), underline: Container(height: 2, color: Colors.blueAccent), onChanged: (String? newValue) { setDialogState(() { _unidad = newValue!; }); }, items: <String>['Minutos', 'Horas'].map<DropdownMenuItem<String>>((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList())])]), actions: [TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop()), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text("Iniciar", style: TextStyle(color: Colors.white)), onPressed: () { if (_ctrlTiempo.text.isNotEmpty) { int valor = int.tryParse(_ctrlTiempo.text) ?? 0; if (valor > 0) { Duration tiempo = (_unidad == 'Horas') ? Duration(hours: valor) : Duration(minutes: valor); widget.onProgramarTimer(tiempo); Navigator.of(context).pop(); } } })]); }); }); }
  void _mostrarBloqueoAutomatico() { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Desactiva la grabación automática para utilizar esto", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2))); }

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
        _buildHeaderControles(false),
        Expanded(flex: 4, child: Container(padding: const EdgeInsets.fromLTRB(0, 10, 10, 0), color: const Color(0xFF1E1E1E), child: AnimatedBuilder(animation: _tabController, builder: (ctx, _) => _buildGraficaInteligente()))),
        Container(color: const Color(0xFF1E1E1E), child: TabBar(controller: _tabController, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blueAccent, dividerColor: Colors.transparent, tabs: const [Tab(icon: Icon(Icons.thermostat), text: "Temp"), Tab(icon: Icon(Icons.speed), text: "Pres"), Tab(icon: Icon(Icons.cloud), text: "Amb"), Tab(icon: Icon(Icons.flash_on), text: "Elec")])),
        Expanded(flex: 6, child: AnimatedBuilder(animation: _tabController, builder: (ctx, _) => ListView(padding: const EdgeInsets.all(12), children: _buildDatosDePestana(_tabController.index)))),
      ],
    );
  }

  Widget _buildVistaHorizontal() {
    return Row(
      children: [
        Expanded(flex: 6, child: Container(padding: const EdgeInsets.all(10), color: const Color(0xFF121212), child: AnimatedBuilder(animation: _tabController, builder: (ctx, _) => _buildGraficaInteligente()))),
        const VerticalDivider(width: 1, color: Colors.white24),
        Expanded(flex: 4, child: Column(children: [_buildHeaderControles(true), Container(color: const Color(0xFF1E1E1E), child: TabBar(controller: _tabController, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blueAccent, dividerColor: Colors.transparent, tabs: const [Tab(icon: Icon(Icons.thermostat), text: "Temp"), Tab(icon: Icon(Icons.speed), text: "Pres"), Tab(icon: Icon(Icons.cloud), text: "Amb"), Tab(icon: Icon(Icons.flash_on), text: "Elec")])), Expanded(child: Container(color: const Color(0xFF1E1E1E), child: AnimatedBuilder(animation: _tabController, builder: (ctx, _) => ListView(padding: const EdgeInsets.all(12), children: _buildDatosDePestana(_tabController.index))))) ]))
      ],
    );
  }

  Widget _buildHeaderControles(bool esHorizontal) {
    Color colorBtnPlay = widget.autoGrabar ? Colors.grey : (widget.grabando ? Colors.redAccent : Colors.greenAccent);
    Color colorBtnTimer = widget.autoGrabar ? Colors.grey : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              IconButton(icon: Icon(widget.grabando ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32), color: colorBtnPlay, onPressed: () { if (widget.autoGrabar) { _mostrarBloqueoAutomatico(); } else { widget.onToggleGrabacion(); } }),
              const SizedBox(width: 5),
              IconButton(icon: const Icon(Icons.timer, size: 28), color: colorBtnTimer, onPressed: () { if (widget.autoGrabar) { _mostrarBloqueoAutomatico(); } else { _mostrarDialogoTemporizador(); } }),
              if (!esHorizontal && widget.textoTiempoRestante.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orangeAccent)), child: Text(widget.textoTiempoRestante, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')))]
            ]),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // --- MENÚ DESPLEGABLE DE ACTUADORES ---
                  PopupMenuButton<String>(
                    icon: Icon(
                        Icons.flash_on, // Rayo
                        color: widget.camaraActiva ? Colors.purpleAccent : Colors.yellowAccent
                    ),
                    tooltip: "Panel de Actuadores",
                    color: const Color(0xFF2C2C2C),
                    onSelected: (valor) {
                      switch (valor) {
                        case 'valvula': widget.onComandoSimple("1v"); break;
                        case 'resistencia': widget.onComandoSimple("1t"); break;
                        case 'bomba': widget.onComandoSimple("1e"); break;
                        case 'camara':
                          if (widget.camaraActiva) {
                            widget.onDetenerCamara();
                          } else {
                            _mostrarConfigCamara();
                          }
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text("ENVIAR PULSO A:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'valvula',
                        child: ListTile(
                          leading: Icon(Icons.circle_outlined, color: Colors.blue),
                          title: Text("Válvula Reflujo", style: TextStyle(color: Colors.white)),
                          trailing: Text("1v", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'resistencia',
                        child: ListTile(
                          leading: Icon(Icons.whatshot, color: Colors.orange),
                          title: Text("Resist. Térmica", style: TextStyle(color: Colors.white)),
                          trailing: Text("1t", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'bomba',
                        child: ListTile(
                          leading: Icon(Icons.water_drop, color: Colors.cyan),
                          title: Text("Bomba Enfriamiento", style: TextStyle(color: Colors.white)),
                          trailing: Text("1e", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'camara',
                        child: ListTile(
                          leading: Icon(Icons.camera_alt, color: widget.camaraActiva ? Colors.red : Colors.purpleAccent),
                          title: Text(widget.camaraActiva ? "DETENER Cámara" : "Cámara Térmica", style: TextStyle(color: widget.camaraActiva ? Colors.redAccent : Colors.white)),
                          subtitle: widget.camaraActiva ? const Text("Secuencia activa...", style: TextStyle(fontSize: 10, color: Colors.green)) : null,
                        ),
                      ),
                    ],
                  ),

                  IconButton(icon: const Icon(Icons.save_alt, color: Colors.greenAccent), onPressed: widget.onExportar),

                  // --- BOTÓN APAGAR CON CONFIRMACIÓN ---
                  IconButton(
                    icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                    tooltip: "Desconectar",
                    onPressed: _confirmarSalida,
                  ),

                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (val) {
                      if (val == 'config') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaConfiguracion(
                          autoGrabar: widget.autoGrabar,
                          onChangedAutoGrabar: widget.onToggleAutoGrabar,
                          mostrarTerminal: widget.mostrarTerminal,
                          onChangedMostrarTerminal: widget.onToggleMostrarTerminal,

                          // --- AQUÍ PASAMOS LOS DATOS DE LA PRUEBA ---
                          modoPruebaErrores: widget.modoPruebaErrores,
                          onChangedModoPruebaErrores: widget.onToggleModoPruebaErrores,
                        )));
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Conectado a:", style: TextStyle(fontSize: 10, color: Colors.grey)), Row(children: [const Icon(Icons.bluetooth_connected, size: 14, color: Colors.blueAccent), const SizedBox(width: 5), Text(widget.nombreDispositivo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))]), const Divider(color: Colors.white24)])),
                        const PopupMenuItem(value: 'config', child: Row(children: [Icon(Icons.settings, color: Colors.grey), SizedBox(width: 10), Text("Configuración")])),
                        const PopupMenuItem(value: 'info', child: Row(children: [Icon(Icons.info_outline, color: Colors.grey), SizedBox(width: 10), Text("Ayuda")])),
                      ];
                    },
                  ),
                ],
              ),
            )
          ]
      ),
    );
  }

  // ... (Resto igual: _buildGraficaInteligente, _buildDatosDePestana, etc.) ...
  Widget _buildGraficaInteligente() { switch (_tabController.index) { case 0: return SensorChartMulti(lineas: widget.historialTemps, lineaSeleccionada: _tempSeleccionada, minY: 0, maxY: 200, intervalY: 25, unidadTooltip: "°C"); case 1: return SensorChartMulti(lineas: widget.historialPresionesSistema, lineaSeleccionada: _presionSeleccionada, minY: 0, maxY: 60, intervalY: 10, unidadTooltip: "Psi"); case 2: if (_ambienteSeleccionado == 0) return SensorChart(puntos: widget.historialTempAmb, colorLinea: Colors.green, minY: 0, maxY: 50, intervalY: 5); if (_ambienteSeleccionado == 1) return SensorChart(puntos: widget.historialHumedad, colorLinea: Colors.lightBlue, minY: 0, maxY: 100, intervalY: 20); double minY = 80000; double maxY = 120000; if (widget.historialPresionAtm.isNotEmpty) { List<double> valores = widget.historialPresionAtm.map((e) => e.y).where((v) => v > 50000).toList(); if (valores.isNotEmpty) { double minVal = valores.reduce(min); double maxVal = valores.reduce(max); double diferencia = maxVal - minVal; if (diferencia < 10) { minY = minVal - 50; maxY = maxVal + 50; } else { double margen = diferencia * 0.2; minY = minVal - margen; maxY = maxVal + margen; } } } return SensorChart(puntos: widget.historialPresionAtm, colorLinea: Colors.blueGrey, minY: minY, maxY: maxY); case 3: return SensorChart(puntos: widget.historialPotencia, colorLinea: Colors.purpleAccent, minY: 0, maxY: 2000, intervalY: 250); default: return const SizedBox(); } }
  List<Widget> _buildDatosDePestana(int index) { switch (index) { case 0: return _buildGridTemperaturas(); case 1: return _buildGridPresiones(); case 2: return _buildListaAmbiente(); case 3: return _buildListaElectrico(); default: return []; } }
  List<Widget> _buildGridTemperaturas() { final cols = SensorChartMulti.coloresFijos; return [_btnResetSelection(() => setState(() => _tempSeleccionada = -1), "Ver Todas"), const SizedBox(height: 10), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.0, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [ _cardSelectable(0, "Hervidor", _getDato(0), "°C", Colors.orange, cols[0], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(1, "Plato 2", _getDato(1), "°C", Colors.orange, cols[1], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(2, "Plato 4", _getDato(2), "°C", Colors.orange, cols[2], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(3, "Plato 6", _getDato(3), "°C", Colors.orange, cols[3], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(4, "Plato 8", _getDato(4), "°C", Colors.orange, cols[4], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(5, "Plato 10", _getDato(5), "°C", Colors.orange, cols[5], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), _cardSelectable(6, "Condensador", _getDato(6), "°C", Colors.orange, cols[6], _tempSeleccionada, (i) => setState(() => _tempSeleccionada = i)), ])]; }
  List<Widget> _buildGridPresiones() { final cols = SensorChartMulti.coloresFijos; return [_btnResetSelection(() => setState(() => _presionSeleccionada = -1), "Ver Todas"), const SizedBox(height: 10), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.0, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [ _cardSelectable(0, "Hervidor", _getDato(10), "Psi", Colors.blue, cols[0], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(1, "S2", _getDato(11), "Psi", Colors.blue, cols[1], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(2, "S3", _getDato(12), "Psi", Colors.blue, cols[2], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(3, "S4", _getDato(13), "Psi", Colors.blue, cols[3], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(4, "S5", _getDato(14), "Psi", Colors.blue, cols[4], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(5, "S6", _getDato(15), "Psi", Colors.blue, cols[5], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), _cardSelectable(6, "S7", _getDato(16), "Psi", Colors.blue, cols[6], _presionSeleccionada, (i) => setState(() => _presionSeleccionada = i)), ])]; }
  List<Widget> _buildListaAmbiente() { return [_cardAmbiente(0, "Temp. Ambiente", _getDato(8), "°C", Colors.green, Icons.thermostat), const SizedBox(height: 8), _cardAmbiente(1, "Humedad", _getDato(7), "%", Colors.lightBlue, Icons.water_drop), const SizedBox(height: 8), _cardAmbiente(2, "Presión Atm", _getDato(9), "Pa", Colors.blueGrey, Icons.speed), const SizedBox(height: 20), if(_hayErrores()) const Text("ALERTAS DEL SISTEMA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), if(_getDato(17)=="1") _alerta("Falla Sensor"), if(_getDato(18)=="1") _alerta("Falla Reflujo")]; }
  List<Widget> _buildListaElectrico() { return [Row(children: [Expanded(child: _miniCard("Voltaje", _getDato(22), "V", Colors.yellowAccent)), const SizedBox(width: 10), Expanded(child: _miniCard("Corriente", _getDato(21), "A", Colors.blueAccent))]), const SizedBox(height: 15), Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.purpleAccent)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Potencia Total", style: TextStyle(color: Colors.white70)), Text("${_getDato(23)} W", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purpleAccent))]))]; }
  Widget _btnResetSelection(VoidCallback t, String txt) => TextButton.icon(onPressed: t, icon: const Icon(Icons.refresh, size: 16, color: Colors.white54), label: Text(txt, style: const TextStyle(color: Colors.white54)), style: TextButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)));
  Widget _cardSelectable(int idx, String ti, String v, String u, Color c, Color dot, int sel, Function(int) onS) { bool s = (sel == idx); return InkWell(onTap: () => onS(idx), borderRadius: BorderRadius.circular(10), child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: s ? c.withOpacity(0.1) : const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10), border: Border.all(color: s ? c : Colors.transparent, width: 1.5)), padding: const EdgeInsets.all(10), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6), Expanded(child: Text(ti, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis))]), const SizedBox(height: 4), Text("$v $u", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))]))); }
  Widget _cardAmbiente(int idx, String ti, String v, String u, Color c, IconData ic) { bool s = (_ambienteSeleccionado == idx); return InkWell(onTap: () => setState(() => _ambienteSeleccionado = idx), child: Container(decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10), border: Border.all(color: s ? c : Colors.transparent, width: 1.5)), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(ic, size: 24, color: c), const SizedBox(width: 12), Text(ti, style: const TextStyle(color: Colors.white70, fontSize: 14))]), Text("$v $u", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]))); }
  Widget _miniCard(String ti, String v, String u, Color c) => Container(decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.all(15), child: Column(children: [Text(ti, style: const TextStyle(fontSize: 12, color: Colors.white54)), const SizedBox(height: 5), Text("$v $u", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))]));
  Widget _alerta(String m) => Card(color: const Color(0xFF3E1E1E), child: ListTile(leading: const Icon(Icons.warning, color: Colors.redAccent), title: Text(m, style: const TextStyle(color: Colors.redAccent))));
  bool _hayErrores() => (_getDato(17)=="1" || _getDato(18)=="1");
}