import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Helper for generating Excel files in memory and returning the raw bytes.
abstract class ExcelExportHelper {
  /// Builds an [.xlsx] workbook with a single sheet containing [headers]
  /// and [rows], and returns the encoded bytes as [Uint8List].
  ///
  /// - [sheetName] - Name of the worksheet.
  /// - [headers]   - Column header strings written to row 0 in bold.
  /// - [rows]      - 2-D list of cell values written starting at row 1.
  ///                 Supported types: [int], [double], [num], [String], [null].
  static Uint8List buildExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final excel = Excel.createExcel();

    // Remove the default sheet if it has a different name
    const defaultSheet = 'Sheet1';
    if (sheetName != defaultSheet) {
      excel.delete(defaultSheet);
    }

    final sheet = excel[sheetName];

    // Write headers (bold)
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Write data rows
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        final val = rows[r][c];

        final CellValue cellValue;
        if (val is int) {
          cellValue = IntCellValue(val);
        } else if (val is double) {
          cellValue = DoubleCellValue(val);
        } else if (val is num) {
          cellValue = DoubleCellValue(val.toDouble());
        } else {
          cellValue = TextCellValue(val?.toString() ?? '');
        }

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = cellValue;
      }
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Failed to encode Excel file.');
    }

    return Uint8List.fromList(encoded);
  }
}
