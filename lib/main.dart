import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background/flutter_background.dart';
import 'dart:convert';

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
      title: 'Monitor de variables en proceso',
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
  bool _grabando = false;
  bool _autoGrabar = true;
  bool _mostrarTerminal = false;

  bool _modoPruebaErrores = false;
  Timer? _timerPrueba;
  int _fasePrueba = 0;

  Timer? _timerCuentaRegresiva;
  int _segundosRestantes = 0;

  bool _errorSensorPrevio = false;
  bool _errorReflujoPrevio = false;
  bool _errorFugaPrevio = false;
  bool _errorValvulaPrevio = false;

  Timer? _timerCamara;
  bool _secuenciaCamaraActiva = false;
  String _statusFoto = "0";

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

  // --- MAPA DE LETRAS ACTUALIZADO (Nuevo Formato) ---
  final Map<String, int> _mapaLetras = {
    'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6, // Temperaturas
    'h': 7, // Humedad
    'i': 8, // Temp Amb
    'j': 9, // Presion Atm
    'k': 10, 'l': 11, 'm': 12, 'n': 13, 'o': 14, 'p': 15, 'q': 16, // Presiones
    'r': 17, 's': 18, 't': 19, 'u': 20, // Fallas
    'v': 21, 'w': 22, 'x': 23 // Electrico
    // AQUI SE AGREGAN OTRAS VARIABLES
  };

  // --- CONFIGURACIÓN DE FILTROS (ROBUSTEZ) ---
  final Map<int, Map<String, double>> _configSensores = {
    0: {'min': 0, 'max': 250, 'salto': 50}, // Hervidor
    1: {'min': 0, 'max': 200, 'salto': 40}, // Platos...
    2: {'min': 0, 'max': 200, 'salto': 40},
    3: {'min': 0, 'max': 200, 'salto': 40},
    4: {'min': 0, 'max': 200, 'salto': 40},
    5: {'min': 0, 'max': 200, 'salto': 40},
    6: {'min': 0, 'max': 200, 'salto': 40}, // Condensador
    7: {'min': 0, 'max': 100, 'salto': 20}, // Humedad
    8: {'min': -20, 'max': 80, 'salto': 15}, // Temp Amb
    9: {'min': 50, 'max': 120, 'salto': 10}, // Presión Atm (kPa: 81.6)
    23: {'min': 0, 'max': 5000, 'salto': 1000}, // Potencia
  };

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _pedirPermisos();
    NotificacionService().init();
    _initBackgroundService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intentarReconexionAutomatica();
    });

    MonitorService().dataStream.listen((dynamic data) {
      try {
        String msg = (data is List<int>) ? String.fromCharCodes(data) : data.toString();
        _buffer += msg;
        if (_buffer.isNotEmpty) _procesarBuffer();
        // Buffer más grande para evitar cortes en tramas largas
        if (_buffer.length > 2000) _buffer = _buffer.substring(_buffer.length - 500);
      } catch (e) {
        if (_mostrarTerminal) setState(() => _debugVisual = "Error: $e");
      }
    });
  }

  // --- PROCESADOR DE BUFFER (V3.0 - FORMATO LETRA-NUMERO) ---
  void _procesarBuffer() {
    if (!mounted) return;
    bool huboCambios = false;

    // Regex Nueva: Busca [Letras][EspaciosOpcionales][Numero]
    // Ejemplo: "aa 19.21" o "b18.84"
    final RegExp regExp = RegExp(r'([a-zA-Z]+)\s*([0-9]+\.?[0-9]*)');

    Iterable<RegExpMatch> matches = regExp.allMatches(_buffer);

    if (matches.isEmpty) return;

    RegExpMatch? ultimoMatchUtil;

    for (final match in matches) {
      ultimoMatchUtil = match;

      String letraRaw = match.group(1)!.toLowerCase();
      String valStr = match.group(2)!.replaceAll(',', '.');

      // TRUCO: Si llega "aa", lo convertimos a "a"
      String letra = (letraRaw == "aa") ? "a" : letraRaw;

      double valor = double.tryParse(valStr) ?? -1.0;
      int? index = _mapaLetras[letra];

      if (valor != -1.0 && index != null) {
        if (_validarYGuardar(index, valor)) {
          huboCambios = true;
        }
      }
    }

    // Limpieza segura del buffer
    if (ultimoMatchUtil != null) {
      _buffer = _buffer.substring(ultimoMatchUtil.end);
    }

    if (huboCambios) {
      _verificarAlertas();
      _actualizarGraficasYExcel();
      if (_conectando) setState(() => _conectando = false);
      if (_mostrarTerminal) {
        setState(() {
          _debugVisual = _buffer.length > 50 ? "..." + _buffer.substring(_buffer.length - 50) : _buffer;
        });
      }
    }
  }

  bool _validarYGuardar(int index, double nuevoValor) {
    // 1. Conversión Presión Atm (Pa -> kPa)
    // Si llega 81668, lo convertimos a 81.66
    if (index == 9 && nuevoValor > 1000) {
      nuevoValor = nuevoValor / 1000.0;
    }

    // 2. Conversión Presiones Sistema (Pa -> PSI)
    // Si llega > 500, asumimos Pa y convertimos a PSI
    if (index >= 10 && index <= 16 && nuevoValor > 500) {
      nuevoValor = nuevoValor / 6894.76;
    }

    double valorAnterior = double.tryParse(_datosPersistentes[index]) ?? 0.0;

    // 3. Filtros Anti-Glitch
    if (_configSensores.containsKey(index)) {
      var config = _configSensores[index]!;
      // Rango Absoluto
      if (nuevoValor < config['min']! || nuevoValor > config['max']!) return false;
      // Salto Brusco
      if (valorAnterior != 0) {
        double diferencia = (nuevoValor - valorAnterior).abs();
        if (diferencia > config['salto']!) return false;
      }
    }

    _datosPersistentes[index] = nuevoValor.toStringAsFixed(2);
    return true;
  }

  void _verificarAlertas() {
    bool errorSensorActual = _datosPersistentes[17] == "1.00" || _datosPersistentes[17] == "1";
    bool errorReflujoActual = _datosPersistentes[18] == "1.00" || _datosPersistentes[18] == "1";
    bool errorFugaActual = _datosPersistentes[19] == "1.00" || _datosPersistentes[19] == "1";
    bool errorValvulaActual = _datosPersistentes[20] == "1.00" || _datosPersistentes[20] == "1";

    if (errorSensorActual && !_errorSensorPrevio) NotificacionService().mostrarNotificacion(id: 1, titulo: "⚠️ ALERTA CRÍTICA", cuerpo: "Falla en Sensores detectada.");
    if (errorReflujoActual && !_errorReflujoPrevio) NotificacionService().mostrarNotificacion(id: 2, titulo: "⚠️ ALERTA DE REFLUJO", cuerpo: "Error en el sistema de reflujo.");
    if (errorFugaActual && !_errorFugaPrevio) NotificacionService().mostrarNotificacion(id: 3, titulo: "🚨 PELIGRO: FUGA", cuerpo: "¡Posible fuga detectada!");
    if (errorValvulaActual && !_errorValvulaPrevio) NotificacionService().mostrarNotificacion(id: 4, titulo: "⚠️ ALERTA VÁLVULA", cuerpo: "Falla en válvula solenoide.");

    _errorSensorPrevio = errorSensorActual; _errorReflujoPrevio = errorReflujoActual;
    _errorFugaPrevio = errorFugaActual; _errorValvulaPrevio = errorValvulaActual;
  }

  // --- FUNCIONES DE SOPORTE ---
  Future<void> _initBackgroundService() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Monitor de variables en proceso",
      notificationText: "Monitoreando sensores activamente...",
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    await FlutterBackground.initialize(androidConfig: androidConfig);
  }

  Future<void> _intentarReconexionAutomatica() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastAddress = prefs.getString('last_device_address');
    if (lastAddress != null && lastAddress.isNotEmpty) {
      try {
        List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
        BluetoothDevice lastDevice = bonded.firstWhere((d) => d.address == lastAddress);
        _conectar(lastDevice);
      } catch (e) {}
    }
  }

  void _toggleModoPrueba(bool activar) {
    setState(() => _modoPruebaErrores = activar); _timerPrueba?.cancel();
    if (activar) {
      _fasePrueba = 0;
      // Demo ajustada al nuevo formato (Letra+Numero)
      _timerPrueba = Timer.periodic(const Duration(seconds: 2), (t) {
        String inyeccion = "";
        switch(_fasePrueba) {
          case 0: inyeccion = "r1.00"; break;
          case 1: inyeccion = "s1.00"; break;
          case 2: inyeccion = "t1.00"; break;
          case 3: inyeccion = "u1.00"; break;
          case 4: inyeccion = "r0.00 s0.00 t0.00 u0.00"; break;
        }
        _buffer += inyeccion; _procesarBuffer(); _fasePrueba++; if (_fasePrueba > 4) _fasePrueba = 0;
      });
    }
  }

  Future<void> _cargarPreferencias() async { final prefs = await SharedPreferences.getInstance(); setState(() { _autoGrabar = prefs.getBool('autoGrabar') ?? true; _mostrarTerminal = prefs.getBool('mostrarTerminal') ?? false; }); }
  Future<void> _guardarPreferencia(String key, bool value) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool(key, value); }

  void _iniciarGrabacionConTimer(Duration duracion) {
    _timerCuentaRegresiva?.cancel();
    setState(() { _grabando = true; _segundosRestantes = duracion.inSeconds; });
    _timerCuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_segundosRestantes > 0) { _segundosRestantes--; }
        else { _detenerGrabacion(); NotificacionService().mostrarNotificacion(id: 999, titulo: "⏳ Proceso Finalizado", cuerpo: "Grabación detenida."); }
      });
    });
  }

  void _detenerGrabacion() { _timerCuentaRegresiva?.cancel(); setState(() { _grabando = false; _segundosRestantes = 0; }); }
  String _formatoTiempo(int segundos) { if (segundos <= 0) return ""; int horas = segundos ~/ 3600; int minutos = (segundos % 3600) ~/ 60; int segs = segundos % 60; String h = horas > 0 ? "${horas.toString().padLeft(2, '0')}:" : ""; return "$h${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}"; }

  void _actualizarGraficasYExcel() {
    if (_grabando) {
      DateTime now = DateTime.now();
      _baseDeDatosLocal.add([ "${now.hour}:${now.minute}:${now.second}", ..._datosPersistentes, _statusFoto ]);
      if (_statusFoto == "1") { _statusFoto = "0"; }
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

  Future<void> _pedirPermisos() async { await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location, Permission.ignoreBatteryOptimizations].request(); _scan(); }
  Future<void> _scan() async { try { var d = await FlutterBluetoothSerial.instance.getBondedDevices(); setState(() { _devices = d; }); } catch(e){} }

  Future<void> _conectar(BluetoothDevice d) async {
    setState(() { _conectando = true; _tiempo = 0; _limpiar(); });
    bool ok = await MonitorService().conectarDispositivo(d);
    setState(() {
      _conectando = false;
      if(ok) {
        _dispositivoSeleccionado = d;
        SharedPreferences.getInstance().then((prefs) => prefs.setString('last_device_address', d.address));
        FlutterBackground.enableBackgroundExecution();
        if (_autoGrabar) _grabando = true;
      }
    });
  }

  void _limpiar() { for(var l in _historialTemps) l.clear(); for(var l in _historialPresionesSistema) l.clear(); _historialPresionAtm.clear(); _historialHumedad.clear(); _historialTempAmb.clear(); _historialPotencia.clear(); }

  Future<void> _enviarComando(String comando) async {
    if (_dispositivoSeleccionado != null) {
      try {
        MonitorService().connection?.output.add(utf8.encode(comando));
        await MonitorService().connection?.output.allSent;
      } catch (e) {}
    }
  }

  void _configurarCamara(int fotosPorMinuto, int retardoSegundos) {
    _timerCamara?.cancel(); if (fotosPorMinuto <= 0) return;
    setState(() => _secuenciaCamaraActiva = true);
    Future.delayed(Duration(seconds: retardoSegundos), () {
      if (!_secuenciaCamaraActiva) return;
      _dispararCamara();
      _timerCamara = Timer.periodic(Duration(milliseconds: (60000 / fotosPorMinuto).toInt()), (t) => _dispararCamara());
    });
  }

  void _dispararCamara() { _enviarComando("1c"); _statusFoto = "1"; }
  void _detenerCamara() { _timerCamara?.cancel(); setState(() => _secuenciaCamaraActiva = false); }

  void _detener() async {
    MonitorService().desconectar();
    try { if (FlutterBackground.isBackgroundExecutionEnabled) await FlutterBackground.disableBackgroundExecution(); } catch (e) {}
    if (mounted) { setState(() { _dispositivoSeleccionado = null; _limpiar(); _detenerGrabacion(); }); }
  }

  void _demo() {
    setState(() { _dispositivoSeleccionado = const BluetoothDevice(address: '00', name: 'SIMULADOR'); _limpiar(); if(_autoGrabar) _grabando = true; });
    // Demo con Formato NUEVO:
    _timerDemo = Timer.periodic(const Duration(milliseconds: 500), (t) {
      _buffer += "09:52:44 aa19.21 b18.84 c18.94 d19.78 e19.04 f19.21 g18.84 h45.00 i18.18 j81668.00 k12.10 l0.20 m0.30 n0.40 o0.50 p0.60 q0.70 r0.00 s0.00 t0.00 u0.00 v0.01 w0.56 x165.00\n";
      _procesarBuffer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _dispositivoSeleccionado == null ? AppBar(title: const Text("Monitor de variables en proceso")) : null,
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
            onProgramarTimer: (Duration tiempo) { _iniciarGrabacionConTimer(tiempo); },
            autoGrabar: _autoGrabar,
            onToggleAutoGrabar: (val) { setState(() => _autoGrabar = val); _guardarPreferencia('autoGrabar', val); },
            mostrarTerminal: _mostrarTerminal,
            onToggleMostrarTerminal: (val) { setState(() => _mostrarTerminal = val); _guardarPreferencia('mostrarTerminal', val); },
            modoPruebaErrores: _modoPruebaErrores,
            onToggleModoPruebaErrores: _toggleModoPrueba,
            onComandoSimple: (cmd) => _enviarComando(cmd),
            onConfigurarCamara: _configurarCamara,
            onDetenerCamara: _detenerCamara,
            camaraActiva: _secuenciaCamaraActiva,
          ),
          if (_dispositivoSeleccionado != null && _mostrarTerminal)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(color: Colors.black.withOpacity(0.9), padding: const EdgeInsets.all(8), height: 45, child: Text("BUFFER: $_debugVisual", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'))),
            ),
        ],
      ),
    );
  }
}