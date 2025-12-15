import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  List<List<FlSpot>> _historialTemps = List.generate(7, (_) => []);
  List<List<FlSpot>> _historialPresionesSistema = List.generate(7, (_) => []);
  List<FlSpot> _historialPresionAtm = [];
  List<FlSpot> _historialHumedad = [];
  List<FlSpot> _historialTempAmb = [];
  List<FlSpot> _historialPotencia = [];

  List<String> _datosPersistentes = List.filled(24, "0.00");
  List<List<String>> _baseDeDatosLocal = [];

  double _tiempo = 0;
  String _buffer = "";
  String _debugVisual = "Esperando..."; // Caja negra

  final Map<String, int> _mapaLetras = {
    // 'a' la trataremos especial, pero la dejamos aqui por si acaso
    'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6,
    'h': 7, 'i': 8, 'j': 9, 'k': 10, 'l': 11, 'm': 12, 'n': 13, 'o': 14, 'p': 15, 'q': 16,
    'r': 17, 's': 18, 't': 19, 'u': 20, 'v': 21, 'w': 22, 'x': 23
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

        // Limpieza básica
        mensajeParcial = mensajeParcial.replaceAll(RegExp(r'[\r\n]'), '');
        _buffer += mensajeParcial;

        // Visualizar en pantalla
        setState(() {
          int start = _buffer.length > 50 ? _buffer.length - 50 : 0;
          _debugVisual = _buffer.substring(start);
        });

        if (_buffer.isNotEmpty) {
          _procesarConAnclaB();
        }

        if (_buffer.length > 2000) {
          _buffer = _buffer.substring(_buffer.length - 1000);
        }

      } catch (e) {
        setState(() => _debugVisual = "Error: $e");
      }
    });
  }

  void _procesarConAnclaB() {
    if (!mounted) return;
    bool huboCambios = false;

    // --- 1. LÓGICA ESPECIAL PARA EL HERVIDOR (ANCLA 'B') ---
    // Buscamos: Un número decimal (con punto), espacios opcionales, y luego la letra 'b'.
    // Esto captura lo que está justo ANTES de la b.
    RegExp regexHervidor = RegExp(r'([0-9]+\.[0-9]+)\s*[bB]');

    Iterable<RegExpMatch> matchesHervidor = regexHervidor.allMatches(_buffer);

    // Si encontramos algo antes de una 'b', tomamos el último hallazgo (el más reciente)
    if (matchesHervidor.isNotEmpty) {
      String valorStr = matchesHervidor.last.group(1)!; // El grupo 1 es el número
      double val = double.tryParse(valorStr) ?? 0.0;

      // Filtro de realidad: Si es > 200 o < 0, probablemente sea error de lectura
      if (val > 0 && val < 200) {
        _datosPersistentes[0] = val.toStringAsFixed(2);
        huboCambios = true;
      }
    }

    // --- 2. LÓGICA ESTÁNDAR PARA EL RESTO (b ... x) ---
    // Aquí sí buscamos "Letra + Numero", pero ignoramos la 'a' porque ya la leímos arriba
    RegExp regexGeneral = RegExp(r'([b-xB-X])\s*([0-9]+[\.,]?[0-9]*)');
    Iterable<RegExpMatch> matches = regexGeneral.allMatches(_buffer);

    for (final match in matches) {
      String letra = match.group(1)!.toLowerCase();
      String valStr = match.group(2)!.replaceAll(',', '.');
      int? index = _mapaLetras[letra];

      if (index != null) {
        double valor = double.tryParse(valStr) ?? 0.0;

        // Conversión Psi (k-q)
        if (index >= 10 && index <= 16) {
          if (valor > 50000) valor = valor / 6894.76;
        }

        _datosPersistentes[index] = valor.toStringAsFixed(2);
        huboCambios = true;
      }
    }

    if (huboCambios) {
      _actualizarGraficasYExcel();
      if (_conectando) setState(() { _conectando = false; });
    }
  }

  void _actualizarGraficasYExcel() {
    DateTime now = DateTime.now();
    _baseDeDatosLocal.add(["${now.hour}:${now.minute}:${now.second}", ..._datosPersistentes]);
    setState(() {
      _tiempo++;
      for (int i = 0; i < 7; i++) {
        _add(_historialTemps[i], double.parse(_datosPersistentes[i]), max: 250);
        _add(_historialPresionesSistema[i], double.parse(_datosPersistentes[10+i]));
      }
      _add(_historialHumedad, double.parse(_datosPersistentes[7]), max: 100);
      _add(_historialTempAmb, double.parse(_datosPersistentes[8]));
      _add(_historialPresionAtm, double.parse(_datosPersistentes[9]));
      _add(_historialPotencia, double.parse(_datosPersistentes[23]), max: 5000);
    });
  }

  void _add(List<FlSpot> lista, double val, {double max = 99999}) {
    if (val > max) val = lista.isNotEmpty ? lista.last.y : 0.0;
    lista.add(FlSpot(_tiempo, val));
    if (lista.length > 60) {
      lista.removeAt(0);
      for (var i = 0; i < lista.length; i++) lista[i] = FlSpot(i.toDouble(), lista[i].y);
    }
  }

  Future<void> _pedirPermisos() async { await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request(); _scan(); }
  Future<void> _scan() async { try { var d = await FlutterBluetoothSerial.instance.getBondedDevices(); setState(() { _devices = d; }); } catch(e){} }
  Future<void> _conectar(BluetoothDevice d) async { setState(() { _conectando = true; _tiempo = 0; _limpiar(); }); bool ok = await MonitorService().conectarDispositivo(d); setState(() { _conectando = false; if(ok) _dispositivoSeleccionado = d; }); }
  void _limpiar() { for(var l in _historialTemps) l.clear(); for(var l in _historialPresionesSistema) l.clear(); _historialPresionAtm.clear(); _historialHumedad.clear(); _historialTempAmb.clear(); _historialPotencia.clear(); }
  void _detener() { MonitorService().desconectar(); setState(() { _dispositivoSeleccionado = null; _limpiar(); }); }

  // SIMULADOR ACTUALIZADO PARA PROBAR TU CASO
  // Enviamos "20.5b" sin la 'a' para probar que la lógica funciona
  void _demo() {
    setState(() { _dispositivoSeleccionado = const BluetoothDevice(address: '00', name: 'SIMULADOR'); _limpiar(); });
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      // Enviamos el dato del hervidor (20.5) pegado a la 'b', a veces sin la 'a'
      _buffer += " 20.5b21.0c22.0d23.0e24.0f25.0g26.0h45.0i25.0j101300k10.0l11.0m12.0n13.0o14.0p15.0q16.0v110.0w1.5x150.0";
      _procesarConAnclaB();
    });
  }

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
          ),

          if (_dispositivoSeleccionado != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.9),
                padding: const EdgeInsets.all(8),
                height: 45,
                alignment: Alignment.centerLeft,
                child: Text(
                  "ENTRADA: $_debugVisual",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}