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
  WakelockPlus.enable(); // <--- ESTO MANTIENE LA PANTALLA ENCENDIDA
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
  // Bluetooth y Estado
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _dispositivoSeleccionado;
  bool _conectando = false;

  // --- DATOS PROCESADOS ---
  List<List<FlSpot>> _historialTemps = List.generate(7, (_) => []);
  List<FlSpot> _historialPresionAtm = [];
  List<FlSpot> _historialHumedad = [];
  List<FlSpot> _historialTempAmb = [];
  List<FlSpot> _historialPotencia = [];

  List<String> _ultimoMensaje = [];
  List<List<String>> _baseDeDatosLocal = [];

  double _tiempo = 0;
  Timer? _timerDemo;

  // --- BUFFER MEJORADO ---
  String _buffer = "";

  @override
  @override
  void initState() {
    super.initState();
    _pedirPermisos();

    // ESCUCHAR BLUETOOTH
    MonitorService().dataStream.listen((dynamic data) {
      try {
        String mensajeParcial = "";

        // CASO 1: Si llega como lista de textos (tu caso actual)
        if (data is List<String>) {
          // Unimos usando "a" para restaurar el formato original
          mensajeParcial = data.join("a");
          // Agregamos una "a" extra al final por si acaso el servicio la borró
          mensajeParcial += "a";
        }
        // CASO 2: Si llega como lista de números (bytes crudos)
        else if (data is List<int>) {
          mensajeParcial = String.fromCharCodes(data);
        }
        // CASO 3: Si llega como texto
        else if (data is String) {
          mensajeParcial = data;
        }
        // CASO 4: Lista dinámica genérica
        else if (data is List) {
          mensajeParcial = data.join("a") + "a";
        }

        // --- BUFFER ACUMULADOR ---
        _buffer += mensajeParcial;

        // Limpieza de seguridad: A veces se acumulan demasiadas "a" juntas (ej: "aa"), las limpiamos
        // para que no generen datos vacíos.
        while(_buffer.contains("aa")) {
          _buffer = _buffer.replaceAll("aa", "a");
        }

        // ESTRATEGIA: BUSCAR EL SALTO DE LÍNEA (\n)
        if (_buffer.contains('\n')) {
          List<String> lineas = _buffer.split('\n');
          for (int i = 0; i < lineas.length - 1; i++) {
            if (lineas[i].trim().isNotEmpty) {
              _procesarNuevosDatos(lineas[i]);
            }
          }
          _buffer = lineas.last;
        }
        // PLAN B: Conteo de 'a'
        else {
          // Si el buffer empieza a tener muchos datos, intentamos procesar
          // "split" nos da un array. Si tenemos 25 pedazos, seguro hay 24 datos completos.
          if (_buffer.split("a").length >= 25) {
            _procesarNuevosDatos(_buffer);
            _buffer = "";
          }
        }

      } catch (e) {
        print("Error recibiendo datos: $e");
      }
    });
  }

  void _procesarNuevosDatos(String mensajeCrudo) {
    if (!mounted) return;

    // Quitamos espacios y saltos de línea al inicio/final
    String mensajeLimpio = mensajeCrudo.trim();

    // DEBUG: Ver qué estamos intentando procesar
    print("PROCESANDO: $mensajeLimpio");

    List<String> datos = mensajeLimpio.split("a");

    // Tu máquina manda 24 datos. Si llegan menos de 20, algo anda mal.
    if (datos.length < 20) {
      print("Datos insuficientes: ${datos.length}");
      return;
    }

    // Agregar Hora para Excel
    DateTime ahora = DateTime.now();
    String horaTexto = "${ahora.hour}:${ahora.minute}:${ahora.second}";
    _baseDeDatosLocal.add([horaTexto, ...datos]);

    setState(() {
      _ultimoMensaje = datos;
      _conectando = false; // ¡Esto quita el mensaje de "Esperando datos..."!

      try {
        // 1. Temperaturas (Indices 0 al 6)
        for (int i = 0; i < 7; i++) {
          double val = double.tryParse(datos[i]) ?? 0.0;
          _historialTemps[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialTemps[i]);
        }

        // 2. Ambiente (Indices 7, 8 y 9)
        // Usamos lógica defensiva (si falta un dato, ponemos 0.0)
        double valHum = datos.length > 7 ? (double.tryParse(datos[7]) ?? 0.0) : 0.0;
        double valPresAtm = datos.length > 8 ? (double.tryParse(datos[8]) ?? 0.0) : 0.0;
        double valTempAmb = datos.length > 9 ? (double.tryParse(datos[9]) ?? 0.0) : 0.0;

        _historialHumedad.add(FlSpot(_tiempo, valHum));
        _historialPresionAtm.add(FlSpot(_tiempo, valPresAtm));
        _historialTempAmb.add(FlSpot(_tiempo, valTempAmb));

        _limpiarHistorial(_historialHumedad);
        _limpiarHistorial(_historialPresionAtm);
        _limpiarHistorial(_historialTempAmb);

        // 3. Potencia (Indice 23 - El último)
        if(datos.length > 23){
          // A veces el último dato trae basura invisible (como \r), lo limpiamos
          String potLimpia = datos[23].replaceAll(RegExp(r'[^0-9.]'), '');
          double valPot = double.tryParse(potLimpia) ?? 0.0;
          _historialPotencia.add(FlSpot(_tiempo, valPot));
          _limpiarHistorial(_historialPotencia);
        }

        _tiempo++;

      } catch (e) {
        print("Error en lógica gráfica: $e");
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

  // --- MISMAS FUNCIONES AUXILIARES DE SIEMPRE ---
  void _iniciarSimulacion() {
    setState(() {
      _conectando = true;
      _dispositivoSeleccionado = const BluetoothDevice(address: '00:00', name: 'SIMULADOR');
      _limpiarTodosLosHistoriales();
      _tiempo = 0;
    });

    _timerDemo = Timer.periodic(const Duration(seconds: 1), (timer) {
      final r = Random();
      List<String> fakeValues = [];
      for (int i = 0; i < 7; i++) fakeValues.add((20 + r.nextDouble() * 10).toStringAsFixed(1));
      fakeValues.add((50 + r.nextDouble() * 5).toStringAsFixed(1));
      fakeValues.add((1013 + r.nextDouble() * 10).toStringAsFixed(0));
      fakeValues.add((25 + r.nextDouble() * 2).toStringAsFixed(1));
      for (int i = 0; i < 7; i++) fakeValues.add((10 + r.nextDouble() * 2).toStringAsFixed(1));
      fakeValues.add("0"); fakeValues.add("0"); fakeValues.add("0"); fakeValues.add("0");
      fakeValues.add("5.2"); fakeValues.add("127.0");
      fakeValues.add((600 + r.nextDouble() * 50).toStringAsFixed(0));
      _procesarNuevosDatos(fakeValues.join("a"));
    });
  }

  void _detenerTodo() {
    if (_timerDemo != null && _timerDemo!.isActive) {
      _timerDemo?.cancel();
    } else {
      MonitorService().desconectar();
    }
    setState(() {
      _dispositivoSeleccionado = null;
      _ultimoMensaje = [];
      _conectando = false;
      _limpiarTodosLosHistoriales();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar")));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generando Excel...")));
    bool exito = await ExcelService().exportarDatos(_baseDeDatosLocal);
    if (!exito) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al generar el archivo")));
    }
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
        datosRaw: _ultimoMensaje,
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