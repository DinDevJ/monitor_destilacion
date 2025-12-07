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
  WidgetsFlutterBinding.ensureInitialized(); // <--- Agrega esto
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

  // --- DATOS PROCESADOS (Listas para gráficas) ---
  List<List<FlSpot>> _historialTemps = List.generate(7, (_) => []);

  // Ambiente
  List<FlSpot> _historialPresionAtm = [];
  List<FlSpot> _historialHumedad = [];
  List<FlSpot> _historialTempAmb = []; // <--- ¡AQUÍ ESTABA EL FALTANTE!

  // Eléctrico
  List<FlSpot> _historialPotencia = [];

  // Datos crudos
  List<String> _ultimoMensaje = [];

  double _tiempo = 0;
  Timer? _timerDemo;
  List<List<String>> _baseDeDatosLocal = [];

  @override
  void initState() {
    super.initState();
    _pedirPermisos();

    // Escuchar el stream
    MonitorService().dataStream.listen((data) {
      try {
        // 1. Convertimos lo que llegue a una lista de enteros segura
        // "List<int>.from(data)" arregla cualquier problema de tipos (Uint8List vs List dynamic)
        List<int> bytes = List<int>.from(data);

        // 2. Convertimos esos números a letras (ASCII)
        String mensajeTexto = String.fromCharCodes(bytes);

        // 3. Enviamos el texto limpio a tu función
        _procesarNuevosDatos(mensajeTexto);

      } catch (e) {
        print("Error al convertir datos Bluetooth: $e");
      }
    });
  }

  void _procesarNuevosDatos(String mensajeCrudo) {
    if (!mounted) return;

    List<String> datos = mensajeCrudo.split("a");

    if (datos.length < 20) return;

    DateTime ahora = DateTime.now();
    String horaTexto = "${ahora.hour}:${ahora.minute}:${ahora.second}";
    _baseDeDatosLocal.add([horaTexto, ...datos]);

    setState(() {
      _ultimoMensaje = datos;
      _conectando = false;

      try {
        // 1. Temperaturas (Indices 0 al 6)
        for (int i = 0; i < 7; i++) {
          double val = double.tryParse(datos[i]) ?? 0.0;
          _historialTemps[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialTemps[i]);
        }

        // 2. Ambiente (Indices 7, 8 y 9)
        double valHum = double.tryParse(datos[7]) ?? 0.0;
        double valPresAtm = double.tryParse(datos[8]) ?? 0.0;
        double valTempAmb = double.tryParse(datos[9]) ?? 0.0; // <--- LEEMOS EL DATO 9

        _historialHumedad.add(FlSpot(_tiempo, valHum));
        _historialPresionAtm.add(FlSpot(_tiempo, valPresAtm));
        _historialTempAmb.add(FlSpot(_tiempo, valTempAmb)); // <--- GUARDAMOS EL DATO 9

        _limpiarHistorial(_historialHumedad);
        _limpiarHistorial(_historialPresionAtm);
        _limpiarHistorial(_historialTempAmb); // <--- LIMPIAMOS SU HISTORIAL

        // 3. Potencia
        if(datos.length > 23){
          double valPot = double.tryParse(datos[23]) ?? 0.0;
          _historialPotencia.add(FlSpot(_tiempo, valPot));
          _limpiarHistorial(_historialPotencia);
        }

        _tiempo++;

      } catch (e) {
        print("Error procesando datos: $e");
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

  void _iniciarSimulacion() {
    setState(() {
      _conectando = true;
      _dispositivoSeleccionado = const BluetoothDevice(address: '00:00', name: 'SIMULADOR PARA TESTS');

      for(var lista in _historialTemps) lista.clear();
      _historialPresionAtm.clear();
      _historialHumedad.clear();
      _historialTempAmb.clear(); // Limpiar también este
      _historialPotencia.clear();
      _tiempo = 0;
    });

    _timerDemo = Timer.periodic(const Duration(seconds: 1), (timer) {
      final r = Random();
      List<String> fakeValues = [];
      for (int i = 0; i < 7; i++) fakeValues.add((20 + r.nextDouble() * 10).toStringAsFixed(1));
      fakeValues.add((50 + r.nextDouble() * 5).toStringAsFixed(1));
      fakeValues.add((1013 + r.nextDouble() * 10).toStringAsFixed(0));
      fakeValues.add((25 + r.nextDouble() * 2).toStringAsFixed(1)); // Temp Amb simulada
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
      for(var lista in _historialTemps) lista.clear();
      _historialPresionAtm.clear();
      _historialHumedad.clear();
      _historialTempAmb.clear();
      _historialPotencia.clear();
    });
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() {
      _conectando = true;
      _tiempo = 0;
      for(var lista in _historialTemps) lista.clear();
      _historialPresionAtm.clear();
      _historialHumedad.clear();
      _historialTempAmb.clear();
      _historialPotencia.clear();
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
        historialTempAmb: _historialTempAmb, // <--- AHORA SÍ PASAMOS LA LISTA LLENA
        historialPotencia: _historialPotencia,
        onDesconectar: _detenerTodo,
        onExportar: _exportarYCompartir,
      ),
    );
  }
}