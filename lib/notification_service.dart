import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // Para colores si se necesitan

class NotificacionService {
  // Singleton para usar la misma instancia en toda la app
  static final NotificacionService _instance = NotificacionService._internal();
  factory NotificacionService() => _instance;
  NotificacionService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Configuración para Android (usamos el icono por defecto 'app_icon' o 'mipmap/ic_launcher')
    // Asegúrate de que '@mipmap/ic_launcher' exista (es el logo de la app por defecto)
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Pedir permiso en Android 13+ (importante)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Función para mostrar notificación instantánea
  Future<void> mostrarNotificacion({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'canal_alertas_destilacion', // ID del canal
      'Alertas del Monitor',       // Nombre del canal
      channelDescription: 'Canal para alertas de fugas y temporizadores',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Colors.red, // Color del icono pequeño (opcional)
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      titulo,
      cuerpo,
      platformChannelSpecifics,
    );
  }
}