import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import 'encryption_service.dart';

/// Professional PDF Bill & Service Receipt generation service.
class PdfBillService {
  PdfBillService._();
  static final PdfBillService instance = PdfBillService._();

  /// Formats currency safely for PDF rendering without Unicode symbol issues.
  String _pdfCurrency(double? amount) {
    if (amount == null) return 'Pending';
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  /// Generates a PDF invoice/bill for [customer] including stored bill/device/ID photos,
  /// and invokes the printing / sharing dialog.
  Future<void> generateAndShareBill(CustomerModel customer) async {
    final pdf = pw.Document();

    // Decrypt IMEI if present
    String? imeiDecrypted;
    if (customer.imeiEncrypted != null && customer.imeiEncrypted!.isNotEmpty) {
      try {
        imeiDecrypted = EncryptionService.instance.decrypt(customer.imeiEncrypted!);
      } catch (_) {
        imeiDecrypted = customer.imeiEncrypted;
      }
    }

    final billNo =
        'INV-${customer.id.length >= 6 ? customer.id.substring(0, 6).toUpperCase() : customer.id.toUpperCase()}';

    // Download & load stored bill / device / ID photos for PDF embedding
    final List<pw.MemoryImage> pdfImages = [];
    final List<String> imageLabels = [];

    for (int i = 0; i < customer.imageUrls.length; i++) {
      final url = customer.imageUrls[i];
      try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          final response =
              await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            pdfImages.add(pw.MemoryImage(response.bodyBytes));
            imageLabels.add(i == 0
                ? 'Device / Bill Photo'
                : i == 1
                    ? 'ID Proof / Delivery Photo'
                    : 'Photo ${i + 1}');
          }
        } else {
          final file = File(url);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              pdfImages.add(pw.MemoryImage(bytes));
              imageLabels.add(i == 0
                  ? 'Device / Bill Photo'
                  : i == 1
                      ? 'ID Proof / Delivery Photo'
                      : 'Photo ${i + 1}');
            }
          }
        }
      } catch (e) {
        // Silently catch image fetch errors so PDF generation completes reliably
      }
    }

    // Page 1: Official Service Receipt & Invoice Details
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Smartphone Repair & Service Center',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Contact / Support: +91 98765 43210',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'SERVICE RECEIPT / BILL',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Bill No: $billNo',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Date: ${Formatters.date(customer.dateReceived)}',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // 2. Customer & Device Details (2 Columns)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer Info
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CUSTOMER DETAILS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            customer.name,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Phone: ${customer.phone}',
                              style: const pw.TextStyle(fontSize: 10)),
                          if (customer.address.isNotEmpty)
                            pw.Text('Address: ${customer.address}',
                                style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),

                  // Device Info
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DEVICE INFORMATION',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Model: ${customer.mobileModel}',
                            style: pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Issue: ${customer.issueDescription}',
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(
                            'Status: ${customer.status.toUpperCase().replaceAll('_', ' ')}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange900),
                          ),
                          if (customer.hasOnlineLock)
                            pw.Text('Online Lock: YES (Remote Lock Active)',
                                style: pw.TextStyle(
                                    fontSize: 9, color: PdfColors.red800)),
                          if (imeiDecrypted != null && imeiDecrypted.isNotEmpty)
                            pw.Text('IMEI: $imeiDecrypted',
                                style: const pw.TextStyle(
                                    fontSize: 9, color: PdfColors.grey800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // 3. Financial Summary Table
              pw.Text(
                'PAYMENT SUMMARY',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Total Cost Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Estimated Repair Cost / Total Price',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _pdfCurrency(customer.totalPrice),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  // Advance Paid Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Advance Amount Paid',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _pdfCurrency(customer.advanceAmount),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800),
                        ),
                      ),
                    ],
                  ),
                  // Balance Remaining Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Balance Due at Delivery',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _pdfCurrency(customer.remainingBalance),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: customer.remainingBalance > 0
                                ? PdfColors.red800
                                : PdfColors.green800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              if (pdfImages.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    '📌 Note: ${pdfImages.length} Delivery Documentation Photo(s) attached on Page 2.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 0.8, color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // 4. Terms & Signature Area
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions:',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '1. Devices not collected within 30 days are subject to shop policy.',
                          style: const pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey700)),
                      pw.Text(
                          '2. Warranty covers replaced spare parts only. Physical damage voids warranty.',
                          style: const pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 14),
                      pw.Text('Authorized Signature',
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('SP Mobile Repair',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Page 2: Dedicated Attached Delivery & Device Documentation Photos Page
    if (pdfImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ATTACHED DELIVERY & DEVICE DOCUMENTATION',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      ),
                    ),
                    pw.Text(
                      'Bill No: $billNo',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Customer: ${customer.name}  •  Model: ${customer.mobileModel}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: List.generate(pdfImages.length, (index) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 240,
                            height: 180,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  color: PdfColors.grey400, width: 1),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 7,
                              verticalRadius: 7,
                              child: pw.Image(
                                pdfImages[index],
                                fit: pw.BoxFit.cover,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              imageLabels[index],
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey900,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),

                pw.Divider(thickness: 0.8, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Documented by SP Mobile Repair',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Page 2 of 2',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // Share / Print PDF with try-catch for MissingPluginException handling during hot restarts
    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'bill_${customer.name.replaceAll(' ', '_')}_$billNo.pdf',
      );
    } on MissingPluginException {
      // Hot restart exception — requires full app restart to bind native printing channel
    } catch (_) {
      // Fallback
    }
  }
}
