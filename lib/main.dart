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
import 'widgets/vista_monitor.dart';

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
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  List<FlSpot> _historialPresionAtm = []; // Dato j
  List<FlSpot> _historialHumedad = [];    // Dato h
  List<FlSpot> _historialTempAmb = [];    // Dato i
  List<FlSpot> _historialPotencia = [];   // Dato x

  // --- MEMORIA PERSISTENTE (Aquí guardamos los 24 datos) ---
  // Inicializamos con "0.0" para que no haya nulls al principio
  List<String> _datosPersistentes = List.filled(24, "0.00");

  // Base de datos Excel
  List<List<String>> _baseDeDatosLocal = [];

  double _tiempo = 0;
  Timer? _timerDemo;
  String _buffer = "";

  // --- MAPA DE ETIQUETAS (Tu diccionario a-x) ---
  final Map<String, int> _mapaLetras = {
    'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5, 'g': 6, // Temps
    'h': 7, // Humedad
    'i': 8, // Temp Amb
    'j': 9, // Presion Atm
    'k': 10, 'l': 11, 'm': 12, 'n': 13, 'o': 14, 'p': 15, 'q': 16, // Presiones Sistema
    'r': 17, 's': 18, 't': 19, 'u': 20, // Fallas
    'v': 21, // Corriente
    'w': 22, // Voltaje
    'x': 23  // Potencia
  };

  @override
  void initState() {
    super.initState();
    _pedirPermisos();

    // ESCUCHAR BLUETOOTH
    MonitorService().dataStream.listen((dynamic data) {
      try {
        String mensajeParcial = "";

        // 1. Estandarizar entrada a Texto
        if (data is List<int>) {
          mensajeParcial = String.fromCharCodes(data);
        } else if (data is String) {
          mensajeParcial = data;
        } else if (data is List) {
          // Si llega lista mezclada, unimos todo
          mensajeParcial = data.join("");
        }

        // 2. Acumular en Buffer
        _buffer += mensajeParcial;

        // 3. PROCESAR SI HAY DATOS ÚTILES
        // Si el buffer contiene al menos una letra válida, intentamos procesar
        if (_buffer.contains(RegExp(r'[a-x]'))) {
          _procesarBufferInteligente();
        }

        // Limpieza de seguridad: Si el buffer crece demasiado sin procesar, lo recortamos
        if (_buffer.length > 1000) {
          _buffer = "";
        }

      } catch (e) {
        print("Error recepción: $e");
      }
    });
  }

  // --- ALGORITMO DE EXTRACCIÓN (REGEX) ---
  void _procesarBufferInteligente() {
    if (!mounted) return;

    // Expresión Regular: Busca una letra (a-x) seguida de un número (entero o decimal)
    // Ejemplo match: "a20.5", "x1500"
    RegExp regex = RegExp(r'([a-x])([0-9]+\.?[0-9]*)');

    // Encontramos todas las coincidencias en el buffer
    Iterable<RegExpMatch> matches = regex.allMatches(_buffer);

    if (matches.isEmpty) return;

    bool huboCambios = false;

    // Recorremos cada hallazgo
    for (final match in matches) {
      String letra = match.group(1)!; // La letra (ej: 'a')
      String valorStr = match.group(2)!; // El número (ej: '20.5')

      // Buscamos el índice en nuestro mapa (0-23)
      int? index = _mapaLetras[letra];

      if (index != null) {
        // --- FILTROS DE INTEGRIDAD Y CONVERSIÓN ---
        double valor = double.tryParse(valorStr) ?? 0.0;

        // 1. Filtro Presiones (Indices 9 a 16 -> j a q)
        // Si es Pascales (>50k), convertir a Psi
        if (index >= 9 && index <= 16) {
          if (valor > 50000) {
            valor = valor / 6894.76; // Pa -> Psi
          }
        }

        // 2. Actualizamos la Memoria Persistente
        // Solo actualizamos el dato que llegó, los demás se quedan igual (persistencia)
        _datosPersistentes[index] = valor.toStringAsFixed(2);
        huboCambios = true;
      }
    }

    // Si encontramos datos válidos, actualizamos la pantalla y limpiamos lo procesado
    if (huboCambios) {
      _actualizarGraficasYExcel();

      // Opcional: Limpiar buffer dejando solo el final por si quedó un dato cortado
      // Estrategia simple: limpiar todo para evitar repeticiones, ya que la memoria persistente guarda el estado
      _buffer = "";

      // Quitamos el estado de "Cargando..."
      if (_conectando) {
        setState(() { _conectando = false; });
      }
    }
  }

  void _actualizarGraficasYExcel() {
    // Agregar a Excel con Hora
    DateTime ahora = DateTime.now();
    String horaTexto = "${ahora.hour}:${ahora.minute}:${ahora.second}";
    // Creamos una copia de los datos actuales para el excel
    _baseDeDatosLocal.add([horaTexto, ..._datosPersistentes]);

    setState(() {
      _tiempo++;

      try {
        // ACTUALIZAR GRÁFICAS USANDO LA MEMORIA PERSISTENTE

        // 1. Temperaturas (a-g -> Indices 0-6)
        for (int i = 0; i < 7; i++) {
          double val = double.parse(_datosPersistentes[i]);
          // Filtro visual gráfica (Max 200)
          if (val > 200) val = _historialTemps[i].isNotEmpty ? _historialTemps[i].last.y : 0.0;

          _historialTemps[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialTemps[i]);
        }

        // 2. Humedad (h -> Indice 7)
        double valHum = double.parse(_datosPersistentes[7]);
        if (valHum > 100) valHum = _historialHumedad.isNotEmpty ? _historialHumedad.last.y : 0.0;
        _historialHumedad.add(FlSpot(_tiempo, valHum));
        _limpiarHistorial(_historialHumedad);

        // 3. Presión Atm (j -> Indice 9 - OJO: El usuario dijo j es PresAtm)
        // Nota: En tu lista anterior el 8 era PresAtm, pero ahora según tu regla:
        // a-g(0-6), h(7), i(8 TempAmb), j(9 PresAtm). AJUSTADO AL NUEVO ORDEN.
        double valPresAtm = double.parse(_datosPersistentes[9]);
        _historialPresionAtm.add(FlSpot(_tiempo, valPresAtm));
        _limpiarHistorial(_historialPresionAtm);

        // 4. Temp Amb (i -> Indice 8)
        double valTempAmb = double.parse(_datosPersistentes[8]);
        _historialTempAmb.add(FlSpot(_tiempo, valTempAmb));
        _limpiarHistorial(_historialTempAmb);

        // 5. Potencia (x -> Indice 23)
        double valPot = double.parse(_datosPersistentes[23]);
        if (valPot > 5000) valPot = 0.0;
        _historialPotencia.add(FlSpot(_tiempo, valPot));
        _limpiarHistorial(_historialPotencia);

      } catch (e) {
        print("Error graficando: $e");
      }
    });
  }

  void _limpiarHistorial(List<FlSpot> lista) {
    if (lista.length > 40) {
      lista.removeAt(0);
      for (var i = 0; i < lista.length; i++) {
        lista[i] = FlSpot(i.toDouble(), lista[i].y);
      }
    }
  }

  // --- FUNCIONES AUXILIARES ---
  void _iniciarSimulacion() {
    setState(() {
      _conectando = true;
      _dispositivoSeleccionado = const BluetoothDevice(address: '00:00', name: 'SIMULADOR');
      _limpiarTodosLosHistoriales();
      _tiempo = 0;
      _datosPersistentes = List.filled(24, "0.00"); // Resetear memoria
    });

    _timerDemo = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulación enviando letras desordenadas para probar el algoritmo
      String sim = "a20.5b21.0x1500.0h45.5j101300v1.5w110.0";
      // Enviamos como lista de int para simular bluetooth real
      _procesarBufferInteligente(); // Esto leería _buffer, lo simulamos directo:
      // En realidad para simular, inyectamos al stream o llamamos una función auxiliar
      // Para simplificar, llenamos _buffer y llamamos:
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
    _historialPresionAtm.clear();
    _historialHumedad.clear();
    _historialTempAmb.clear();
    _historialPotencia.clear();
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

  Future<void> _pedirPermisos() async {
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    try {
      List<BluetoothDevice> devs = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() { _devices = devs; });
    } catch (e) { print(e); }
  }

  Future<void> _exportarYCompartir() async {
    if (_baseDeDatosLocal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos")));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generando Excel...")));
    bool exito = await ExcelService().exportarDatos(_baseDeDatosLocal);
    if (!exito) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al generar")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor de Fluidos"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _dispositivoSeleccionado == null
          ? VistaConexion(
        devices: _devices,
        conectando: _conectando,
        onConectar: _conectar,
        onDemo: _iniciarSimulacion,
      )
          : VistaMonitor(
        nombreDispositivo: _dispositivoSeleccionado!.name ?? "Dispositivo",
        // AQUI PASAMOS LA MEMORIA PERSISTENTE QUE SIEMPRE TIENE 24 DATOS
        datosRaw: _datosPersistentes,
        historialTemps: _historialTemps,
        historialPresion: _historialPresionAtm,
        historialHumedad: _historialHumedad,
        historialTempAmb: _historialTempAmb,
        historialPotencia: _historialPotencia,
        onDesconectar: _detenerTodo,
        onExportar: _exportarYCompartir,
      ),
    );
  }
}