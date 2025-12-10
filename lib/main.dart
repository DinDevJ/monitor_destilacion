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

  String _buffer = "";

  @override
  void initState() {
    super.initState();
    _pedirPermisos();

    MonitorService().dataStream.listen((dynamic data) {
      try {
        String mensajeParcial = "";

        if (data is List<String>) {
          mensajeParcial = data.join("a");
          if (!mensajeParcial.endsWith("a")) mensajeParcial += "a";
        } else if (data is List<int>) {
          mensajeParcial = String.fromCharCodes(data);
        } else if (data is String) {
          mensajeParcial = data;
        } else if (data is List) {
          mensajeParcial = data.join("a") + "a";
        }

        _buffer += mensajeParcial;

        while(_buffer.contains("aa")) {
          _buffer = _buffer.replaceAll("aa", "a");
        }

        if (_buffer.contains('\n')) {
          List<String> lineas = _buffer.split('\n');
          for (int i = 0; i < lineas.length - 1; i++) {
            if (lineas[i].trim().isNotEmpty) {
              _procesarNuevosDatos(lineas[i]);
            }
          }
          _buffer = lineas.last;
        } else {
          if (_buffer.split("a").length >= 25) {
            _procesarNuevosDatos(_buffer);
            _buffer = "";
          }
        }
      } catch (e) {
        print("Error: $e");
      }
    });
  }

  void _procesarNuevosDatos(String mensajeCrudo) {
    if (!mounted) return;

    String mensajeLimpio = mensajeCrudo.trim();
    List<String> datos = mensajeLimpio.split("a");

    if (datos.length < 20) return;

    // --- CORRECCIÓN UNIDADES: PASCALES A PSI ---
    // Recorremos los datos de presión (indices 10 al 16)
    // Si vemos un número gigante (> 50,000), asumimos Pascales y convertimos a Psi.
    for(int k=10; k<=16; k++) {
      if(datos.length > k) {
        double val = double.tryParse(datos[k]) ?? 0.0;
        if(val > 50000) {
          // 1 Psi = 6894.76 Pa. 
          // Ejemplo: 81065 Pa / 6894.76 = 11.75 Psi
          double valPsi = val / 6894.76;
          datos[k] = valPsi.toStringAsFixed(2); // Actualizamos el dato en la lista
        }
      }
    }

    DateTime ahora = DateTime.now();
    String horaTexto = "${ahora.hour}:${ahora.minute}:${ahora.second}";
    _baseDeDatosLocal.add([horaTexto, ...datos]);

    setState(() {
      _ultimoMensaje = datos;
      _conectando = false;

      try {
        // 1. TEMPERATURAS
        for (int i = 0; i < 7; i++) {
          String datoRaw = (datos.length > i) ? datos[i] : "0";
          double val = double.tryParse(datoRaw) ?? 0.0;

          // Filtro anti-picos
          if (val > 200 || val < -10) {
            val = (_historialTemps[i].isNotEmpty) ? _historialTemps[i].last.y : 0.0;
          }
          _historialTemps[i].add(FlSpot(_tiempo, val));
          _limpiarHistorial(_historialTemps[i]);
        }

        // 2. HUMEDAD
        String datoHum = (datos.length > 7) ? datos[7] : "0";
        double valHum = double.tryParse(datoHum) ?? 0.0;
        if (valHum > 100) valHum = _historialHumedad.isNotEmpty ? _historialHumedad.last.y : 0.0;

        _historialHumedad.add(FlSpot(_tiempo, valHum));
        _limpiarHistorial(_historialHumedad);

        // 3. PRESIÓN ATM
        String datoPres = (datos.length > 8) ? datos[8] : "0";
        double valPresAtm = double.tryParse(datoPres) ?? 0.0;
        if (valPresAtm > 200000) valPresAtm = 101300.0;

        _historialPresionAtm.add(FlSpot(_tiempo, valPresAtm));
        _limpiarHistorial(_historialPresionAtm);

        // 4. TEMP AMB
        String datoAmb = (datos.length > 9) ? datos[9] : "0";
        double valTempAmb = double.tryParse(datoAmb) ?? 0.0;

        _historialTempAmb.add(FlSpot(_tiempo, valTempAmb));
        _limpiarHistorial(_historialTempAmb);

        // 5. POTENCIA (Usamos el índice 22 basado en tus fotos)
        if(datos.length > 22){
          String potRaw = datos[22]; // Indice 22 es Potencia según tus fotos (168)
          double valPot = double.tryParse(potRaw) ?? 0.0;

          if (valPot > 5000) valPot = 0.0; // Filtro básico

          _historialPotencia.add(FlSpot(_tiempo, valPot));
          _limpiarHistorial(_historialPotencia);
        }

        _tiempo++;

      } catch (e) {
        print("Error datos: $e");
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

  // ... (Tus funciones _iniciarSimulacion, _detenerTodo, _conectar, etc. van aquí igual que antes) ...
  // COPIA AQUÍ LAS FUNCIONES QUE FALTAN:
  void _iniciarSimulacion() {
    setState(() {
      _conectando = true;
      _dispositivoSeleccionado = const BluetoothDevice(address: '00:00', name: 'SIMULADOR');
      _limpiarTodosLosHistoriales();
      _tiempo = 0;
    });

    _timerDemo = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulación simple
      _procesarNuevosDatos("20.5a21.0a22.0a23.0a24.0a25.0a26.0a50.0a101300a25.0a0.2a0.0a0.0a80000.0a0.0a0.0a0.0a0a0a0a0a110.0a160.0a1.5a");
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
    // TODO: implement build
    throw UnimplementedError();
  }
}