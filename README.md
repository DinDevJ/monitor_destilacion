# Monitor de Destilación (v1.0)

**Proyecto de Servicio Social**
Desarrollado por: Julio Cesar Araujo Hernandez y Katia Aguilar Calderon.

Este proyecto es una aplicación móvil desarrollada en **Flutter** para el monitoreo en tiempo real, control y registro de datos de una columna de destilación automatizada.

## Descripción General

Esta aplicación representa una remasterización completa de la versión anterior utilizada en el laboratorio. Aunque se conservó la lógica fundamental del protocolo de comunicación serial para interpretar los códigos de la máquina, el núcleo de la aplicación ha sido reescrito desde cero utilizando tecnologías modernas.

**Mejoras clave respecto a la versión anterior:**
* **Optimización del Algoritmo:** El decodificador de tramas de datos fue refactorizado para mayor velocidad y para implementar filtros de ruido en las lecturas de los sensores.
* **Arquitectura Robusta:** Implementación de servicios aislados para Bluetooth, Excel y Notificaciones.
* **Segundo Plano:** Capacidad de operar, alertar y registrar datos con la pantalla apagada o la aplicación minimizada.
* **Interfaz Moderna:** Gráficas vectoriales en tiempo real e interfaz de usuario (UI) adaptativa.

## Tecnologías y Dependencias

Para futuros desarrolladores que deseen modificar o mantener este proyecto, a continuación se listan las librerías y tecnologías principales utilizadas:

* **Lenguaje:** Dart (Flutter SDK).
* **Comunicación Serial:** `flutter_bluetooth_serial` - Manejo de la conexión SPP con módulos HC-05/HC-06.
* **Visualización de Datos:** `fl_chart` - Renderizado de gráficas lineales de alto rendimiento para temperaturas y presiones.
* **Persistencia y Exportación:**
    * `excel` - Generación de archivos .xlsx nativos.
    * `share_plus` - Integración con el sistema para compartir archivos (Drive, WhatsApp, Correo).
    * `shared_preferences` - Almacenamiento local de configuraciones de usuario.
* **Sistema y Segundo Plano:**
    * `flutter_background` - Servicio para mantener la ejecución viva (Foreground Service) en Android.
    * `wakelock_plus` - Prevención del bloqueo automático de pantalla durante el monitoreo.
    * `flutter_local_notifications` - Sistema de alertas locales para errores críticos y temporizadores.
    * `permission_handler` - Gestión de permisos en tiempo de ejecución (Ubicación, Bluetooth, Notificaciones).

## Estructura del Proyecto

A continuación se describe la arquitectura de archivos y la responsabilidad de cada componente dentro del directorio `/lib`:

### Núcleo y Servicios (Raíz de /lib)
* **main.dart**:
    * Es el punto de entrada de la aplicación.
    * Orquesta el ciclo de vida de la app, inicializa los servicios globales y contiene la lógica central de procesamiento de datos (parsing de tramas, filtros de señal y detección de errores).
* **bluetooth_service.dart**:
    * Maneja la capa de comunicación con el hardware.
    * Gestiona la conexión asíncrona, el flujo de datos (Stream) y la reconexión automática.
* **excel_service.dart**:
    * Encargado de la persistencia de datos.
    * Genera reportes con formato estilizado y sincroniza eventos externos (como el disparo de la cámara térmica) dentro de la hoja de cálculo.
* **notification_service.dart**:
    * Singleton encargado de las alertas del sistema.
    * Lanza notificaciones críticas y avisos de procesos finalizados.

### Interfaz y Componentes Visuales (/lib/widgets)
Este directorio contiene todas las pantallas y los widgets reutilizables de la aplicación:

* **vista_conexion.dart**:
    * Primera pantalla de la aplicación. Escanea dispositivos Bluetooth y gestiona la conexión.
* **vista_monitor.dart**:
    * Dashboard Principal. Muestra el resumen de sensores, gráficas en tiempo real y contiene el menú de control de actuadores (Válvulas, Resistencias, Cámara).
* **pantalla_detalle.dart**:
    * Vista de enfoque. Permite analizar un sensor específico con mayor detalle al seleccionarlo desde el monitor.
* **pantalla_configuracion.dart**:
    * Menú de ajustes. Controla la grabación automática, visualización de terminal (debug) y el simulador de errores.
* **sensor_chart.dart**:
    * Componente de gráfica lineal simple (usado para Humedad, Ambiente, Potencia).
* **sensor_chart_multi.dart**:
    * Componente de gráfica avanzada para múltiples líneas simultáneas (usado para comparar Platos de Destilación y Presiones).

## Instalación y Despliegue

1.  Clonar el repositorio.
2.  Asegurar tener Flutter SDK instalado y configurado.
3.  Ejecutar `flutter pub get` en la terminal para instalar las dependencias listadas.
4.  Para generar el instalable final (APK) optimizado:
    ```bash
    flutter build apk --release
    ```

---
*Servicio Social - Ingeniería en Sistemas Computacionales - Instituto Tecnologico de Morelia*
