import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {

  Future<bool> exportarDatos(List<List<String>> datos) async {
    try {
      var excel = Excel.createExcel();
      String nombreHoja = "Reporte Completo";
      Sheet sheetObject = excel[nombreHoja];
      excel.setDefaultSheet(nombreHoja);

      // 1. ENCABEZADOS (Tus 24 variables)
      List<String> titulosString = [
        "Hora Lectura",
        "T1 (Entrada)", "T2", "T3", "T4", "T5", "T6", "T7",
        "Humedad Amb", "Presión Atm", "Temp Amb",
        "P. Hervidor", "P. Sensor 2", "P. Sensor 3", "P. Sensor 4",
        "P. Sensor 5", "P. Sensor 6", "P. Sensor 7",
        "Err Sensor", "Err Reflujo", "Err Fuga", "Err Válvula",
        "Corriente (A)", "Voltaje (V)", "Potencia (W)"
      ];

      List<CellValue> filaEncabezados = titulosString.map((e) => TextCellValue(e)).toList();
      sheetObject.appendRow(filaEncabezados);

      // 2. DATOS
      for (var fila in datos) {
        List<CellValue> filaExcel = fila.map((dato) {
          double? valorNumerico = double.tryParse(dato);
          if(valorNumerico != null) {
            return DoubleCellValue(valorNumerico);
          }
          return TextCellValue(dato);
        }).toList();

        sheetObject.appendRow(filaExcel);
      }

      // 3. GENERAR NOMBRE CON FECHA Y HORA
      // Obtenemos la fecha actual
      DateTime now = DateTime.now();

      // Formateamos manual: AÑO-MES-DIA_HORA-MINUTO (Ej: 2025-10-25_14-30)
      // Usamos .padLeft(2, '0') para asegurar que "5" se convierta en "05"
      String fecha = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
      String hora = "${now.hour.toString().padLeft(2,'0')}-${now.minute.toString().padLeft(2,'0')}";

      String nombreArchivo = "Reporte_Destilacion_${fecha}_$hora.xlsx";


      // 4. GUARDAR Y COMPARTIR
      var fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();

        // Usamos el nombre dinámico aquí
        final String filePath = '${directory.path}/$nombreArchivo';

        File file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Adjunto reporte generado el $fecha a las $hora.',
            subject: 'Reporte Destilación $fecha'
        );
        return true;
      }
      return false;

    } catch (e) {
      print("Error en ExcelService: $e");
      return false;
    }
  }
}