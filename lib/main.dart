import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'bluetooth_service.dart';
import 'excel_service.dart';
import 'widgets/vista_conexion.dart';
import 'widgets/vista_monitor.dart'; // Asegúrate de que este archivo existe y no tiene errores

import 'package:wakelock_plus/wakelock_plus.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF1E1E1E),
        ),
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
  // Bluetooth
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _dispositivoSeleccionado;
  bool _conectando = false;

  // --- HISTORIALES GRÁFICOS ---
  List<List<FlSpot>> _historialTemps = List.generate(7, (_) => []);
  // ESTA ES LA LISTA CLAVE PARA LAS PRESIONES (ANTES FALTABA)
  List<List<FlSpot>> _historialPresionesSistema = List.generate(7, (_) => []);

  List<FlSpot> _historialPresionAtm = [];
  List<FlSpot> _historialHumedad = [];
  List<FlSpot> _historialTempAmb = [];
  List<FlSpot> _historialPotencia = [];

  // --- MEMORIA ---
  List<String> _datosPersistentes = List.filled(24, "0.00");
  List<List<String>> _baseDeDatosLocal = [];

  double _tiempo = 0;
  Timer? _timerDemo;
  String _buffer = "";

  final Map<String, int> _mapaLetras = {
    'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6,
    'h': 7, 'i': 8, 'j': 9,
    'k': 10, 'l': 11, 'm': 12, 'n': 13, 'o': 14, 'p': 15, 'q': 16,
    'r': 17, 's': 18, 't': 19, 'u': 20,
    'v': 21, 'w': 22, 'x': 23
  };

  @override
  void initState() {
    super.initState();
    _pedirPermisos();

    MonitorService().dataStream.listen((dynamic data) {
      try {
        String mensajeParcial = "";
        if (data is List<int>) {
          mensajeParcial = String.fromCharCodes(data);
        } else if (data is String) {
          mensajeParcial = data;
        } else if (data is List) {
          mensajeParcial = data.join("");
        }

        _buffer += mensajeParcial;
        if (_buffer.contains(RegExp(r'[a-x]'))) {
          _procesarBufferInteligente();
        }
        // Limpieza de seguridad del buffer
        if (_buffer.length > 2000) _buffer = "";
      } catch (e) {
        print("Error recepción: $e");
      }
    });
  }

  void _procesarBufferInteligente() {
    if (!mounted) return;

    RegExp regex = RegExp(r'([a-x])([0-9]+\.?[0-9]*)');
    Iterable<RegExpMatch> matches = regex.allMatches(_buffer);

    if (matches.isEmpty) return;

    bool huboCambios = false;

    for (final match in matches) {
      String letra = match.group(1)!;
      String valorStr = match.group(2)!;
      int? index = _mapaLetras[letra];

      if (index != null) {
        double valor = double.tryParse(valorStr) ?? 0.0;

        // Conversión Pascales a Psi (Indices 9 a 16)
        if (index >= 9 && index <= 16) {
          if (valor > 50000) valor = valor / 6894.76;
        }

        _datosPersistentes[index] = valor.toStringAsFixed(2);
        huboCambios = true;
      }
    }

    if (huboCambios) {
      _actualizarGraficasYExcel();
      _buffer = "";
      if (_conectando) setState(() { _conectando = false; });
    }
  }

  void _actualizarGraficasYExcel() {
    DateTime ahora = DateTime.now();
    String horaTexto = "${ahora.hour}:${ahora.minute}:${ahora.second}";
    _baseDeDatosLocal.add([horaTexto, ..._datosPersistentes]);

    setState(() {
      _tiempo++;
      try {
        // Temps
        for (int i = 0; i < 7; i++) {
          double val = double.parse(_datosPersistentes[i]);
          if (val > 250 || val < -50) val = _historialTemps[i].isNotEmpty ? _historialTemps[i].last.y : 0.0;
          _historialTemps[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialTemps[i]);
        }

        // Humedad
        double valHum = double.parse(_datosPersistentes[7]);
        if (valHum > 100) valHum = _historialHumedad.isNotEmpty ? _historialHumedad.last.y : 0.0;
        _historialHumedad.add(FlSpot(_tiempo, valHum));
        _limpiarHistorial(_historialHumedad);

        // Temp Amb
        double valTempAmb = double.parse(_datosPersistentes[8]);
        _historialTempAmb.add(FlSpot(_tiempo, valTempAmb));
        _limpiarHistorial(_historialTempAmb);

        // Presión Atm
        double valPresAtm = double.parse(_datosPersistentes[9]);
        _historialPresionAtm.add(FlSpot(_tiempo, valPresAtm));
        _limpiarHistorial(_historialPresionAtm);

        // Presiones Sistema (k-q)
        for (int i = 0; i < 7; i++) {
          // El índice en _datosPersistentes empieza en 10 (letra k)
          double val = double.parse(_datosPersistentes[10 + i]);
          _historialPresionesSistema[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialPresionesSistema[i]);
        }

        // Potencia
        double valPot = double.parse(_datosPersistentes[23]);
        if (valPot > 5000) valPot = _historialPotencia.isNotEmpty ? _historialPotencia.last.y : 0.0;
        _historialPotencia.add(FlSpot(_tiempo, valPot));
        _limpiarHistorial(_historialPotencia);

      } catch (e) {
        print("Error graficando: $e");
      }
    });
  }

  void _limpiarHistorial(List<FlSpot> lista) {
    if (lista.length > 60) {
      lista.removeAt(0);
      for (var i = 0; i < lista.length; i++) {
        lista[i] = FlSpot(i.toDouble(), lista[i].y);
      }
    }
  }

  Future<void> _pedirPermisos() async {
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    _escanearDispositivos();
  }

  Future<void> _escanearDispositivos() async {
    try {
      List<BluetoothDevice> devs = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() { _devices = devs; });
    } catch (e) { print("Error escaneo: $e"); }
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() {
      _conectando = true;
      _tiempo = 0;
      _limpiarTodosLosHistoriales();
      _datosPersistentes = List.filled(24, "0.00");
      _buffer = "";
    });
    bool exito = await MonitorService().conectarDispositivo(device);
    setState(() {
      _conectando = false;
      if (exito) _dispositivoSeleccionado = device;
    });
  }

  void _iniciarSimulacion() {
    setState(() {
      _conectando = true;
      _dispositivoSeleccionado = const BluetoothDevice(address: '00:00', name: 'SIMULADOR');
      _limpiarTodosLosHistoriales();
      _tiempo = 0;
      _datosPersistentes = List.filled(24, "0.00");
    });
    _timerDemo = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final r = Random();
      String sim = "";
      for(int i=0; i<7; i++) sim += "${String.fromCharCode(97+i)}${(20 + r.nextDouble()*15).toStringAsFixed(1)}";
      sim += "h${(40 + r.nextDouble()*20).toStringAsFixed(1)}";
      sim += "i${(25 + r.nextDouble()*5).toStringAsFixed(1)}";
      sim += "j${(101300 + r.nextDouble()*500).toStringAsFixed(0)}";
      for(int i=0; i<7; i++) sim += "${String.fromCharCode(107+i)}${(0.5 + r.nextDouble()*2).toStringAsFixed(2)}";
      sim += "v1.5w110.0x${(150 + r.nextDouble()*50).toStringAsFixed(1)}";
      _buffer += sim;
      _procesarBufferInteligente();
    });
  }

  void _detenerTodo() {
    if (_timerDemo != null && _timerDemo!.isActive) _timerDemo?.cancel();
    MonitorService().desconectar();
    setState(() {
      _dispositivoSeleccionado = null;
      _conectando = false;
      _limpiarTodosLosHistoriales();
      _buffer = "";
    });
  }

  void _limpiarTodosLosHistoriales(){
    for(var lista in _historialTemps) lista.clear();
    for(var lista in _historialPresionesSistema) lista.clear();
    _historialPresionAtm.clear();
    _historialHumedad.clear();
    _historialTempAmb.clear();
    _historialPotencia.clear();
  }

  Future<void> _exportarYCompartir() async {
    if (_baseDeDatosLocal.isEmpty) return;
    bool exito = await ExcelService().exportarDatos(_baseDeDatosLocal);
    if (!exito) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al generar")));
  }

  // --- AQUÍ ESTÁ LA FUNCIÓN BUILD QUE FALTABA ---
  // Esta función es la que dibuja la pantalla. Sin ella, sale el error rojo.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _dispositivoSeleccionado == null
          ? AppBar(title: const Text("Monitor de Fluidos"))
          : null,
      body: _dispositivoSeleccionado == null
          ? VistaConexion(
        devices: _devices,
        conectando: _conectando,
        onConectar: _conectar,
        onDemo: _iniciarSimulacion,
      )
          : VistaMonitor(
        nombreDispositivo: _dispositivoSeleccionado!.name ?? "Dispositivo",
        datosRaw: _datosPersistentes,
        historialTemps: _historialTemps,
        // Aquí pasamos la lista de presiones que declaramos arriba
        historialPresionesSistema: _historialPresionesSistema,
        historialPresionAtm: _historialPresionAtm,
        historialHumedad: _historialHumedad,
        historialTempAmb: _historialTempAmb,
        historialPotencia: _historialPotencia,
        onDesconectar: _detenerTodo,
        onExportar: _exportarYCompartir,
      ),
    );
  }
}