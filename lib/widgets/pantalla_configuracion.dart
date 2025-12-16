import 'package:flutter/material.dart';

class PantallaConfiguracion extends StatefulWidget {
  // CONFIG 1: Grabación
  final bool autoGrabar;
  final ValueChanged<bool> onChangedAutoGrabar;

  // CONFIG 2: Terminal
  final bool mostrarTerminal;
  final ValueChanged<bool> onChangedMostrarTerminal;

  // CONFIG 3: PRUEBA DE ERRORES (NUEVO)
  final bool modoPruebaErrores;
  final ValueChanged<bool> onChangedModoPruebaErrores;

  const PantallaConfiguracion({
    super.key,
    required this.autoGrabar,
    required this.onChangedAutoGrabar,
    required this.mostrarTerminal,
    required this.onChangedMostrarTerminal,
    required this.modoPruebaErrores,
    required this.onChangedModoPruebaErrores,
  });

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  late bool _localAutoGrabar;
  late bool _localMostrarTerminal;
  late bool _localModoPrueba;

  @override
  void initState() {
    super.initState();
    _localAutoGrabar = widget.autoGrabar;
    _localMostrarTerminal = widget.mostrarTerminal;
    _localModoPrueba = widget.modoPruebaErrores;
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
          const Text("ALMACENAMIENTO", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          SwitchListTile(
            title: const Text("Grabación Automática", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Guardar datos al conectar.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.greenAccent,
            value: _localAutoGrabar,
            onChanged: (val) {
              setState(() => _localAutoGrabar = val);
              widget.onChangedAutoGrabar(val);
              _mostrarAlertaReinicio();
            },
          ),

          const Divider(color: Colors.white24, height: 30),

          const Text("HERRAMIENTAS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          SwitchListTile(
            title: const Text("Terminal de Datos", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Ver datos crudos en pantalla.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.orangeAccent,
            value: _localMostrarTerminal,
            onChanged: (val) {
              setState(() => _localMostrarTerminal = val);
              widget.onChangedMostrarTerminal(val);
            },
          ),

          // --- NUEVA OPCIÓN: MODO PRUEBA DE ERRORES ---
          SwitchListTile(
            title: const Text("Probar Detección de Errores", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Simula fallas (fuga, sensor, etc.) cada 2 segundos para verificar notificaciones.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            activeColor: Colors.redAccent, // Rojo para indicar peligro/alerta
            secondary: const Icon(Icons.bug_report, color: Colors.redAccent),
            value: _localModoPrueba,
            onChanged: (val) {
              setState(() => _localModoPrueba = val);
              widget.onChangedModoPruebaErrores(val);
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