import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background/flutter_background.dart';
import 'dart:convert'; // Necesario para utf8.encode

import 'notification_service.dart';
import 'bluetooth_service.dart';
import 'excel_service.dart';
import 'widgets/vista_conexion.dart';
import 'widgets/vista_monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monitor Destilación',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), foregroundColor: Colors.white, elevation: 0),
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent, secondary: Colors.orangeAccent, surface: Color(0xFF1E1E1E)),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _dispositivoSeleccionado;
  bool _conectando = false;

  // Variables de Estado
  bool _grabando = false;
  bool _autoGrabar = true;
  bool _mostrarTerminal = false;

  // Variables Modo Prueba
  bool _modoPruebaErrores = false;
  Timer? _timerPrueba;
  int _fasePrueba = 0;

  // Variables Timer Grabación
  Timer? _timerCuentaRegresiva;
  int _segundosRestantes = 0;

  // Variables Errores Previos
  bool _errorSensorPrevio = false;
  bool _errorReflujoPrevio = false;
  bool _errorFugaPrevio = false;
  bool _errorValvulaPrevio = false;

  // --- VARIABLES PARA CÁMARA Y SINCRONIZACIÓN ---
  Timer? _timerCamara;
  bool _secuenciaCamaraActiva = false;
  String _statusFoto = "0"; // "0" = No foto, "1" = Foto tomada en este segundo

  // Listas de Datos
  List<List<FlSpot>> _historialTemps = List.generate(7, (_) => []);
  List<List<FlSpot>> _historialPresionesSistema = List.generate(7, (_) => []);
  List<FlSpot> _historialPresionAtm = [];
  List<FlSpot> _historialHumedad = [];
  List<FlSpot> _historialTempAmb = [];
  List<FlSpot> _historialPotencia = [];

  List<String> _datosPersistentes = List.filled(24, "0.00");
  List<List<String>> _baseDeDatosLocal = [];

  double _tiempo = 0;
  Timer? _timerDemo;
  String _buffer = "";
  String _debugVisual = "Esperando...";

  final Map<String, int> _mapaLetras = {
    'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6,
    'h': 7, 'i': 8, 'j': 9, 'k': 10, 'l': 11, 'm': 12, 'n': 13, 'o': 14, 'p': 15, 'q': 16,
    'r': 17, 's': 18, 't': 19, 'u': 20, 'v': 21, 'w': 22, 'x': 23
  };

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _pedirPermisos();
    NotificacionService().init();
    _initBackgroundService();

    MonitorService().dataStream.listen((dynamic data) {
      try {
        String msg = (data is List<int>) ? String.fromCharCodes(data) : (data is List ? data.join("") : data.toString());
        msg = msg.replaceAll(RegExp(r'[\r\n]'), '');
        _buffer += msg;

        if (_mostrarTerminal) {
          setState(() {
            int start = _buffer.length > 50 ? _buffer.length - 50 : 0;
            _debugVisual = _buffer.substring(start);
          });
        }

        if (_buffer.isNotEmpty) _procesarConAnclaB();
        if (_buffer.length > 2000) _buffer = _buffer.substring(_buffer.length - 1000);
      } catch (e) {
        if (_mostrarTerminal) setState(() => _debugVisual = "Error: $e");
      }
    });
  }

  Future<void> _initBackgroundService() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Monitor de Destilación",
      notificationText: "Monitoreando sensores y temporizador en segundo plano...",
      notificationImportance: AndroidNotificationImportance.normal, // Cambiado a Default para mejor visibilidad
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    await FlutterBackground.initialize(androidConfig: androidConfig);
  }

  // --- LOGICA MODO PRUEBA ---
  void _toggleModoPrueba(bool activar) { setState(() => _modoPruebaErrores = activar); _timerPrueba?.cancel(); if (activar) { _fasePrueba = 0; _timerPrueba = Timer.periodic(const Duration(seconds: 2), (t) { String inyeccion = ""; switch(_fasePrueba) { case 0: inyeccion = "r1.00"; break; case 1: inyeccion = "s1.00"; break; case 2: inyeccion = "t1.00"; break; case 3: inyeccion = "u1.00"; break; case 4: inyeccion = "r0.00s0.00t0.00u0.00"; break; } _buffer += inyeccion; _procesarConAnclaB(); _fasePrueba++; if (_fasePrueba > 4) _fasePrueba = 0; }); } }

  // --- PREFERENCIAS ---
  Future<void> _cargarPreferencias() async { final prefs = await SharedPreferences.getInstance(); setState(() { _autoGrabar = prefs.getBool('autoGrabar') ?? true; _mostrarTerminal = prefs.getBool('mostrarTerminal') ?? false; }); }
  Future<void> _guardarPreferencia(String key, bool value) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool(key, value); }

  // --- TIMER GRABACIÓN ---
  void _iniciarGrabacionConTimer(Duration duracion) {
    _timerCuentaRegresiva?.cancel();
    setState(() {
      _grabando = true;
      _segundosRestantes = duracion.inSeconds;
    });
    _timerCuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_segundosRestantes > 0) {
          _segundosRestantes--;
        } else {
          _detenerGrabacion();
          NotificacionService().mostrarNotificacion(id: 999, titulo: "⏳ Proceso Finalizado", cuerpo: "El temporizador ha terminado. Grabación detenida.");
        }
      });
    });
  }

  void _detenerGrabacion() { _timerCuentaRegresiva?.cancel(); setState(() { _grabando = false; _segundosRestantes = 0; }); }
  String _formatoTiempo(int segundos) { if (segundos <= 0) return ""; int horas = segundos ~/ 3600; int minutos = (segundos % 3600) ~/ 60; int segs = segundos % 60; String h = horas > 0 ? "${horas.toString().padLeft(2, '0')}:" : ""; String m = minutos.toString().padLeft(2, '0'); String s = segs.toString().padLeft(2, '0'); return "$h$m:$s"; }

  // --- PROCESAMIENTO DE DATOS ---
  void _procesarConAnclaB() {
    if (!mounted) return;
    bool huboCambios = false;
    RegExp regexHervidor = RegExp(r'([0-9]+\.[0-9]+)\s*[bB]');
    Iterable<RegExpMatch> matchesHervidor = regexHervidor.allMatches(_buffer);
    if (matchesHervidor.isNotEmpty) { String valorStr = matchesHervidor.last.group(1)!; double val = double.tryParse(valorStr) ?? 0.0; if (val > 0 && val < 200) { _datosPersistentes[0] = val.toStringAsFixed(2); huboCambios = true; } }
    RegExp regexGeneral = RegExp(r'([b-xB-X])\s*([0-9]+[\.,]?[0-9]*)');
    Iterable<RegExpMatch> matches = regexGeneral.allMatches(_buffer);
    for (final match in matches) { String letra = match.group(1)!.toLowerCase(); String valStr = match.group(2)!.replaceAll(',', '.'); int? index = _mapaLetras[letra]; if (index != null) { double valor = double.tryParse(valStr) ?? 0.0; if (index >= 10 && index <= 16) { if (valor > 50000) valor = valor / 6894.76; } _datosPersistentes[index] = valor.toStringAsFixed(2); huboCambios = true; } }

    // Detección de errores y notificaciones
    bool errorSensorActual = _datosPersistentes[17] == "1.00" || _datosPersistentes[17] == "1";
    bool errorReflujoActual = _datosPersistentes[18] == "1.00" || _datosPersistentes[18] == "1";
    bool errorFugaActual = _datosPersistentes[19] == "1.00" || _datosPersistentes[19] == "1";
    bool errorValvulaActual = _datosPersistentes[20] == "1.00" || _datosPersistentes[20] == "1";

    if (errorSensorActual && !_errorSensorPrevio) NotificacionService().mostrarNotificacion(id: 1, titulo: "⚠️ ALERTA CRÍTICA", cuerpo: "Falla en Sensores detectada. Revise conexiones.");
    if (errorReflujoActual && !_errorReflujoPrevio) NotificacionService().mostrarNotificacion(id: 2, titulo: "⚠️ ALERTA DE REFLUJO", cuerpo: "Error en el sistema de reflujo.");
    if (errorFugaActual && !_errorFugaPrevio) NotificacionService().mostrarNotificacion(id: 3, titulo: "🚨 PELIGRO: FUGA", cuerpo: "¡Posible fuga de gas detectada! Realizar protocolo.");
    if (errorValvulaActual && !_errorValvulaPrevio) NotificacionService().mostrarNotificacion(id: 4, titulo: "⚠️ ALERTA VÁLVULA", cuerpo: "Falla en válvula solenoide.");

    _errorSensorPrevio = errorSensorActual; _errorReflujoPrevio = errorReflujoActual; _errorFugaPrevio = errorFugaActual; _errorValvulaPrevio = errorValvulaActual;

    if (huboCambios) { _actualizarGraficasYExcel(); if (_conectando) setState(() { _conectando = false; }); }
  }

  // --- ACTUALIZAR GRÁFICAS Y EXCEL (CORREGIDO PARA COLUMNA FOTO) ---
  void _actualizarGraficasYExcel() {
    if (_grabando) {
      DateTime now = DateTime.now();
      // Agregamos la columna FOTO al final (índice 25)
      _baseDeDatosLocal.add([
        "${now.hour}:${now.minute}:${now.second}",
        ..._datosPersistentes,
        _statusFoto // <--- AQUÍ ESTÁ LA SINCRONIZACIÓN
      ]);

      // Reseteamos bandera de foto inmediatamente
      if (_statusFoto == "1") {
        _statusFoto = "0";
      }
    }

    setState(() {
      _tiempo++;
      for (int i = 0; i < 7; i++) {
        _add(_historialTemps[i], double.parse(_datosPersistentes[i]), max: 250);
        _add(_historialPresionesSistema[i], double.parse(_datosPersistentes[10+i]));
      }
      _add(_historialHumedad, double.parse(_datosPersistentes[7]), max: 100);
      _add(_historialTempAmb, double.parse(_datosPersistentes[8]));
      _add(_historialPresionAtm, double.parse(_datosPersistentes[9]), max: 150000);
      _add(_historialPotencia, double.parse(_datosPersistentes[23]), max: 5000);
    });
  }

  void _add(List<FlSpot> lista, double val, {double max = 99999}) { if (val > max) val = lista.isNotEmpty ? lista.last.y : 0.0; lista.add(FlSpot(_tiempo, val)); if (lista.length > 60) { lista.removeAt(0); for (var i = 0; i < lista.length; i++) lista[i] = FlSpot(i.toDouble(), lista[i].y); } }

  // --- BLUETOOTH ---
  Future<void> _pedirPermisos() async { await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request(); _scan(); }
  Future<void> _scan() async { try { var d = await FlutterBluetoothSerial.instance.getBondedDevices(); setState(() { _devices = d; }); } catch(e){} }

  Future<void> _conectar(BluetoothDevice d) async {
    setState(() { _conectando = true; _tiempo = 0; _limpiar(); });
    bool ok = await MonitorService().conectarDispositivo(d);
    setState(() {
      _conectando = false;
      if(ok) {
        _dispositivoSeleccionado = d;
        FlutterBackground.enableBackgroundExecution(); // Segundo plano
        if (_autoGrabar) _grabando = true;
      }
    });
  }

  void _limpiar() { for(var l in _historialTemps) l.clear(); for(var l in _historialPresionesSistema) l.clear(); _historialPresionAtm.clear(); _historialHumedad.clear(); _historialTempAmb.clear(); _historialPotencia.clear(); }

  // --- LÓGICA DE PULSOS Y CÁMARA (NUEVO) ---
  Future<void> _enviarComando(String comando) async {
    if (_dispositivoSeleccionado != null) {
      try {
        MonitorService().connection?.output.add(utf8.encode(comando));
        await MonitorService().connection?.output.allSent;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Comando enviado: $comando"), duration: const Duration(milliseconds: 500))
        );
      } catch (e) {
        print("Error al enviar comando: $e");
      }
    }
  }

  void _configurarCamara(int fotosPorMinuto, int retardoSegundos) {
    _timerCamara?.cancel();
    if (fotosPorMinuto <= 0) return;

    // Cálculo: 60 seg / fotos = intervalo
    double intervaloSegundos = 60 / fotosPorMinuto;
    int milisegundosIntervalo = (intervaloSegundos * 1000).toInt();

    setState(() {
      _secuenciaCamaraActiva = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Cámara: Iniciando en $retardoSegundos segs ($fotosPorMinuto fotos/min)"),
      backgroundColor: Colors.purpleAccent,
    ));

    Future.delayed(Duration(seconds: retardoSegundos), () {
      if (!_secuenciaCamaraActiva) return;
      _dispararCamara(); // Primer disparo tras retardo
      _timerCamara = Timer.periodic(Duration(milliseconds: milisegundosIntervalo), (t) {
        _dispararCamara();
      });
    });
  }

  void _dispararCamara() {
    _enviarComando("1c"); // Pulso físico
    _statusFoto = "1";    // Sincronización Excel
  }

  void _detenerCamara() {
    _timerCamara?.cancel();
    setState(() {
      _secuenciaCamaraActiva = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Secuencia de cámara detenida.")));
  }

  // --- DESACTIVAR AL DESCONECTAR (BLINDADO) ---
  void _detener() async {
    MonitorService().desconectar();
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      print("Error al detener servicio de fondo: $e");
    }
    if (mounted) {
      setState(() {
        _dispositivoSeleccionado = null;
        _limpiar();
        _detenerGrabacion();
      });
    }
  }

  void _demo() { setState(() { _dispositivoSeleccionado = const BluetoothDevice(address: '00', name: 'SIMULADOR'); _limpiar(); if(_autoGrabar) _grabando = true; }); _timerDemo = Timer.periodic(const Duration(milliseconds: 500), (t) { _buffer += " 20.5b21.0c22.0d23.0e24.0f25.0g26.0h45.0i25.0j101300k10.0l11.0m12.0n13.0o14.0p15.0q16.0v110.0w1.5x150.0"; _procesarConAnclaB(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _dispositivoSeleccionado == null ? AppBar(title: const Text("Monitor de Fluidos")) : null,
      body: Stack(
        children: [
          _dispositivoSeleccionado == null
              ? VistaConexion(devices: _devices, conectando: _conectando, onConectar: _conectar, onDemo: _demo)
              : VistaMonitor(
            nombreDispositivo: _dispositivoSeleccionado!.name ?? "Dispositivo",
            datosRaw: _datosPersistentes,
            historialTemps: _historialTemps,
            historialPresionesSistema: _historialPresionesSistema,
            historialPresionAtm: _historialPresionAtm,
            historialHumedad: _historialHumedad,
            historialTempAmb: _historialTempAmb,
            historialPotencia: _historialPotencia,
            onDesconectar: _detener,
            onExportar: () => ExcelService().exportarDatos(_baseDeDatosLocal),
            grabando: _grabando,
            textoTiempoRestante: _formatoTiempo(_segundosRestantes),
            onToggleGrabacion: () { if (_grabando) { _detenerGrabacion(); } else { setState(() => _grabando = true); } },
            onProgramarTimer: (Duration tiempo) { _iniciarGrabacionConTimer(tiempo); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⏳ Grabando por ${tiempo.inMinutes} minutos..."), backgroundColor: Colors.orangeAccent)); },
            autoGrabar: _autoGrabar,
            onToggleAutoGrabar: (val) { setState(() => _autoGrabar = val); _guardarPreferencia('autoGrabar', val); },
            mostrarTerminal: _mostrarTerminal,
            onToggleMostrarTerminal: (val) { setState(() => _mostrarTerminal = val); _guardarPreferencia('mostrarTerminal', val); },
            modoPruebaErrores: _modoPruebaErrores,
            onToggleModoPruebaErrores: _toggleModoPrueba,

            // --- NUEVOS PARÁMETROS DE PULSOS CORRECTAMENTE CONECTADOS ---
            onComandoSimple: (cmd) => _enviarComando(cmd),
            onConfigurarCamara: _configurarCamara,
            onDetenerCamara: _detenerCamara,
            camaraActiva: _secuenciaCamaraActiva,
          ),

          if (_dispositivoSeleccionado != null && _mostrarTerminal)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(color: Colors.black.withOpacity(0.9), padding: const EdgeInsets.all(8), height: 45, alignment: Alignment.centerLeft, child: Text("ENTRADA: $_debugVisual", style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'monospace'))),
            ),
        ],
      ),
    );
  }
}