import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class VistaConexion extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final bool conectando;
  final Function(BluetoothDevice) onConectar;
  final VoidCallback onDemo;

  const VistaConexion({
    super.key,
    required this.devices,
    required this.conectando,
    required this.onConectar,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    if (conectando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Conectando con el dispositivo..."),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Cabecera y Botón Demo
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Dispositivos Vinculados",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: onDemo,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("MODO DEMO"),
              )
            ],
          ),
        ),

        // Lista de dispositivos
        Expanded(
          child: devices.isEmpty
              ? const Center(child: Text("No hay dispositivos vinculados."))
              : ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth, color: Colors.blue),
                  title: Text(device.name ?? "Desconocido"),
                  subtitle: Text(device.address),
                  trailing: ElevatedButton(
                    onPressed: () => onConectar(device),
                    child: const Text("Conectar"),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}