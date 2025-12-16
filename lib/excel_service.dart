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

      CellStyle estiloEncabezado = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString("#D9D9D9"),
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      // --- AGREGAMOS "FOTO" AL FINAL DE LOS ENCABEZADOS ---
      List<String> titulosString = [
        "Hora Lectura",
        "T. HERVIDOR", "T. PLATO 2", "T. PLATO 4", "T. PLATO 6", "T. PLATO 8", "T. PLATO 10", "T. CONDENSADOR",
        "Humedad Amb", "Presión Atm", "Temp Amb",
        "P. HERVIDOR", "P. PLATO 2", "P. PLATO 4", "P. PLATO 6",
        "P. PLATO 8", "P. PLATO 10", "P. CONDENSADOR",
        "Err Sensor", "Err Reflujo", "Err Fuga", "Err Válvula",
        "Corriente (A)", "Voltaje (V)", "Potencia (W)",
        "FOTO" // <--- NUEVA COLUMNA DE SINCRONIZACIÓN
      ];

      List<CellValue> filaEncabezados = titulosString.map((e) => TextCellValue(e)).toList();
      sheetObject.appendRow(filaEncabezados);

      for (int i = 0; i < titulosString.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = estiloEncabezado;
        sheetObject.setColumnWidth(i, 18.0);
      }

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

      DateTime now = DateTime.now();
      String fecha = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
      String hora = "${now.hour.toString().padLeft(2,'0')}-${now.minute.toString().padLeft(2,'0')}";
      String nombreArchivo = "Reporte_Destilacion_${fecha}_$hora.xlsx";

      var fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
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