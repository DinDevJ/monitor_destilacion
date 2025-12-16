import 'package:flutter/material.dart';

class PantallaConfiguracion extends StatefulWidget {
  // CONFIG 1: Grabación Automática
  final bool autoGrabar;
  final ValueChanged<bool> onChangedAutoGrabar;

  // CONFIG 2: Terminal (NUEVO)
  final bool mostrarTerminal;
  final ValueChanged<bool> onChangedMostrarTerminal;

  const PantallaConfiguracion({
    super.key,
    required this.autoGrabar,
    required this.onChangedAutoGrabar,
    required this.mostrarTerminal,
    required this.onChangedMostrarTerminal,
  });

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  late bool _localAutoGrabar;
  late bool _localMostrarTerminal;

  @override
  void initState() {
    super.initState();
    _localAutoGrabar = widget.autoGrabar;
    _localMostrarTerminal = widget.mostrarTerminal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Configuración"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECCIÓN 1: ALMACENAMIENTO
          const Text("ALMACENAMIENTO", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Grabación Automática", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Guardar datos automáticamente al conectar.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.greenAccent,
            value: _localAutoGrabar,
            onChanged: (val) {
              setState(() => _localAutoGrabar = val);
              widget.onChangedAutoGrabar(val);
              _mostrarAlertaReinicio();
            },
          ),

          const Divider(color: Colors.white24, height: 30),

          // SECCIÓN 2: HERRAMIENTAS (NUEVO)
          const Text("HERRAMIENTAS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Terminal de Datos", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Muestra una caja con los datos crudos recibidos (útil para detectar errores).", style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.orangeAccent,
            value: _localMostrarTerminal,
            onChanged: (val) {
              setState(() => _localMostrarTerminal = val);
              // Este cambio es inmediato, no requiere alerta
              widget.onChangedMostrarTerminal(val);
            },
          ),
        ],
      ),
    );
  }

  void _mostrarAlertaReinicio() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Reinicio Requerido", style: TextStyle(color: Colors.white)),
        content: const Text("Reinicia la app para aplicar cambios de grabación.", style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}