import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/excel_export_helper.dart';
import '../models/customer_model.dart';
import '../models/inventory_model.dart';
import '../models/manual_ledger_model.dart';
import '../models/weekly_report_model.dart';

/// Builds Excel workbooks from app data and shares them via the system
/// share sheet using [SharePlus].
class ExcelExportService {
  final DateFormat _fileDateFmt = DateFormat('dd-MM-yyyy');

  // ──────────────────────────────────────────────
  // Daily Hisaab export
  // ──────────────────────────────────────────────

  /// Exports the daily summary ledger as an Excel file and opens the
  /// platform share sheet.
  Future<void> exportDailyHisaab({
    required DateTime date,
    required Map<String, dynamic> ledgerData,
    required double finalCredit,
    required double finalDebit,
    required double netBalance,
    required List<ManualLedgerEntry> manualEntries,
    required List<CustomerModel> customers,
    required List<InventoryModel> inventoryItems,
  }) async {
    final List<String> headers = [
      'Category / Section',
      'Model / Customer',
      'Work / Description',
      'Cash (INR)',
      'Online / UPI (INR)',
      'Total Amount (INR)',
      'Status / Details',
    ];

    final List<List<dynamic>> rows = [];

    // Financial Summary Section
    rows.add(['FINANCIAL SUMMARY', 'Cash IN (Credit)', '-', '-', '-', finalCredit, 'Auto + Manual Total']);
    rows.add(['FINANCIAL SUMMARY', 'Cash OUT (Debit)', '-', '-', '-', finalDebit, 'Auto + Manual Total']);
    rows.add(['FINANCIAL SUMMARY', 'Net Balance', '-', '-', '-', netBalance, netBalance >= 0 ? 'Surplus' : 'Deficit']);
    rows.add(['-', '-', '-', '-', '-', '-', '-']);

    // Manual Spreadsheet Ledger Section
    if (manualEntries.isNotEmpty) {
      double totalCash = 0;
      double totalOnline = 0;
      double totalRevenue = 0;

      rows.add(['MANUAL SPREADSHEET', 'Model', 'Work Description', 'Cash (INR)', 'Online (INR)', 'Total (INR)', 'Remark']);
      for (final item in manualEntries) {
        totalCash += item.cashAmount;
        totalOnline += item.onlineAmount;
        totalRevenue += item.totalAmount;
        rows.add([
          'MANUAL ENTRY',
          item.model,
          item.work,
          item.cashAmount,
          item.onlineAmount,
          item.totalAmount,
          'Spreadsheet Entry',
        ]);
      }
      rows.add(['MANUAL TALLY TOTAL', 'TOTALS:', '-', totalCash, totalOnline, totalRevenue, 'Tally Summary']);
      rows.add(['-', '-', '-', '-', '-', '-', '-']);
    }

    // Customer Records Section
    rows.add(['CUSTOMER REPAIRS', 'Customer Name', 'Phone & Model', 'Advance (INR)', 'Total (INR)', 'Due (INR)', 'Status']);
    for (final c in customers) {
      rows.add([
        'CUSTOMER',
        c.name,
        '${c.phone} (${c.mobileModel})',
        c.advanceAmount,
        c.totalPrice ?? 0,
        c.remainingBalance,
        c.status.toUpperCase(),
      ]);
    }
    rows.add(['-', '-', '-', '-', '-', '-', '-']);

    // Inventory Stock Section
    rows.add(['STOCK PARTS', 'Item Name', 'Category', 'Quantity', 'Unit Price (INR)', 'Total Value (INR)', 'Status']);
    for (final i in inventoryItems) {
      rows.add([
        'STOCK',
        i.itemName,
        i.category.toUpperCase(),
        i.quantity,
        i.purchasePricePerUnit,
        i.totalValue,
        i.isReturned ? 'Returned' : 'Active',
      ]);
    }

    final bytes = ExcelExportHelper.buildExcel(
      sheetName: 'Daily Ledger Sheet',
      headers: headers,
      rows: rows,
    );

    final safeDateStr = _fileDateFmt.format(date);
    await _shareExcel(
      bytes,
      'daily_hisaab_$safeDateStr.xlsx',
    );
  }

  // ──────────────────────────────────────────────
  // Weekly Report export
  // ──────────────────────────────────────────────

  /// Exports a weekly inventory report as an Excel file and opens the
  /// platform share sheet.
  Future<void> exportWeeklyReport(
    WeeklyReportModel report,
    List<InventoryModel> items,
  ) async {
    final headers = [
      'Item Name',
      'Category',
      'Quantity',
      'Purchase Price',
      'Total Value',
      'Supplier',
      'Status',
    ];

    final rows = items
        .map((i) => [
              i.itemName,
              i.category,
              i.quantity,
              i.purchasePrice,
              i.totalValue,
              i.supplierName ?? 'Direct',
              i.isReturned ? 'Returned' : 'Active',
            ])
        .toList();

    final bytes = ExcelExportHelper.buildExcel(
      sheetName: 'Weekly Report',
      headers: headers,
      rows: rows,
    );

    final safeDateStr = _fileDateFmt.format(report.weekStart);
    await _shareExcel(
      bytes,
      'weekly_report_$safeDateStr.xlsx',
    );
  }

  // ──────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────

  /// Writes [bytes] to the OS temp directory as [filename] and invokes the
  /// system share sheet.
  Future<void> _shareExcel(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: filename,
    );
  }
}
