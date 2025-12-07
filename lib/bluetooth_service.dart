// lib/bluetooth_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class MonitorService {
  // Singleton: Para usar la misma conexión en toda la app
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();

  BluetoothConnection? connection;
  StreamController<List<String>> _dataStream = StreamController.broadcast();

  // Así escuchará tu pantalla los datos
  Stream<List<String>> get dataStream => _dataStream.stream;

  // Lógica de conexión
  Future<bool> conectarDispositivo(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      print('Conectado a ${device.name}');

      // Aquí empieza la magia de recibir datos
      connection!.input!.listen(_onDataReceived).onDone(() {
        print('Desconectado por el dispositivo');
      });
      return true;
    } catch (e) {
      print('Error de conexión: $e');
      return false;
    }
  }

  // Buffer para guardar pedazos de datos hasta tener el mensaje completo
  String _buffer = '';

  void _onDataReceived(Uint8List data) {
    // 1. Convertir bytes a texto
    String incoming = String.fromCharCodes(data);
    _buffer += incoming;

    // 2. El PDF dice que usan "a" como separador.
    // Asumiremos que el mensaje termina con un salto de línea o
    // que procesamos cada vez que tenemos suficientes "a".

    // NOTA: A veces los datos llegan cortados.
    // Aquí implementamos una lógica robusta:
    if (_buffer.contains('\n') || _buffer.length > 50) { // Ajuste de seguridad
      // Limpiamos espacios y saltos
      String cleanData = _buffer.trim();

      // LA LÓGICA DEL PROYECTO VIEJO: Split por "a"
      List<String> sensores = cleanData.split('a');

      // Verificamos si tenemos datos válidos (al menos 1 sensor)
      if (sensores.isNotEmpty && sensores.length > 5) {
        _dataStream.add(sensores);
        // Limpiamos el buffer solo si fue exitoso
        _buffer = '';
      }
    }
  }

  void desconectar() {
    connection?.close();
    connection = null;
  }
}