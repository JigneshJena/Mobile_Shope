import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/customer_model.dart';
import '../models/inventory_model.dart';
import '../models/manual_ledger_model.dart';

/// Service to generate and export/print Daily Ledger PDF reports.
class PdfLedgerService {
  PdfLedgerService._();
  static final PdfLedgerService instance = PdfLedgerService._();

  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  String _pdfCurrency(double amount) {
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  Future<void> generateAndShareDailyLedgerPdf({
    required DateTime date,
    required double finalCredit,
    required double finalDebit,
    required double netBalance,
    required List<ManualLedgerEntry> manualEntries,
    required List<CustomerModel> customers,
    required List<InventoryModel> inventoryItems,
  }) async {
    final pdf = pw.Document();
    final formattedDate = _dateFmt.format(date);

    double totalSpreadsheetCash = manualEntries.fold(0.0, (sum, i) => sum + i.cashAmount);
    double totalSpreadsheetOnline = manualEntries.fold(0.0, (sum, i) => sum + i.onlineAmount);
    double totalSpreadsheetGrand = manualEntries.fold(0.0, (sum, i) => sum + i.totalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. Header & Shop Branding
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SP MOBILE REPAIR',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.Text(
                      'DAILY LEDGER SPREADSHEET REPORT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date: $formattedDate',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${_dateFmt.format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 10),

            // 2. Financial Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Cash IN (Credit)',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800)),
                      pw.SizedBox(height: 3),
                      pw.Text(_pdfCurrency(finalCredit),
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900)),
                    ],
                  ),
                  pw.Container(height: 20, width: 1, color: PdfColors.grey400),
                  pw.Column(
                    children: [
                      pw.Text('Cash OUT (Debit)',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red800)),
                      pw.SizedBox(height: 3),
                      pw.Text(_pdfCurrency(finalDebit),
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900)),
                    ],
                  ),
                  pw.Container(height: 20, width: 1, color: PdfColors.grey400),
                  pw.Column(
                    children: [
                      pw.Text('Net Balance',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800)),
                      pw.SizedBox(height: 3),
                      pw.Text(_pdfCurrency(netBalance),
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: netBalance >= 0
                                  ? PdfColors.green900
                                  : PdfColors.red900)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 3. Manual Spreadsheet Ledger Table Section
            pw.Text('Manual Ledger Spreadsheet Entries:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (manualEntries.isEmpty)
              pw.Text('No manual spreadsheet entries recorded for this date.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else ...[
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Model Name', 'Work Description', 'Cash (INR)', 'Online (INR)', 'Total (INR)'],
                data: manualEntries
                    .map((item) => [
                          item.model,
                          item.work,
                          _pdfCurrency(item.cashAmount),
                          _pdfCurrency(item.onlineAmount),
                          _pdfCurrency(item.totalAmount),
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 6),

              // Spreadsheet Tally Summary Footer Box
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SPREADSHEET TALLY TOTALS:',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'Cash: ${_pdfCurrency(totalSpreadsheetCash)}  |  Online: ${_pdfCurrency(totalSpreadsheetOnline)}  |  GRAND TOTAL: ${_pdfCurrency(totalSpreadsheetGrand)}',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 14),

            // 4. Customers of the Day
            pw.Text('Customer Repair Records (${customers.length} entries):',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (customers.isEmpty)
              pw.Text('No customer transactions recorded for this date.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                headers: [
                  'Customer Name',
                  'Phone',
                  'Mobile Model',
                  'Status',
                  'Advance',
                  'Total Price',
                  'Due Balance'
                ],
                data: customers.map((c) {
                  return [
                    c.name,
                    c.phone,
                    c.mobileModel,
                    c.status.toUpperCase(),
                    _pdfCurrency(c.advanceAmount),
                    c.totalPrice != null ? _pdfCurrency(c.totalPrice!) : 'Pending',
                    _pdfCurrency(c.remainingBalance),
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 14),

            // 5. Stock & Spare Parts Used
            pw.Text(
                'Stock & Spare Parts Recorded (${inventoryItems.length} items):',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (inventoryItems.isEmpty)
              pw.Text('No stock parts recorded on this date.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Item Name', 'Category', 'Quantity', 'Unit Price', 'Total Value'],
                data: inventoryItems.map((i) {
                  return [
                    i.itemName,
                    i.category.toUpperCase(),
                    '${i.quantity} units',
                    _pdfCurrency(i.purchasePricePerUnit.toDouble()),
                    _pdfCurrency(i.totalValue),
                  ];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Daily_Ledger_$formattedDate.pdf',
    );
  }
}
