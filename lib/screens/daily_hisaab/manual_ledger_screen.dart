import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/manual_ledger_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../services/pdf_ledger_service.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/app_text_field.dart';

class ManualLedgerScreen extends ConsumerStatefulWidget {
  const ManualLedgerScreen({
    super.key,
    required this.date,
    this.initialOpenAdd = false,
    this.initialEditItem,
  });

  final DateTime date;
  final bool initialOpenAdd;
  final ManualLedgerEntry? initialEditItem;

  @override
  ConsumerState<ManualLedgerScreen> createState() => _ManualLedgerScreenState();
}

class _ManualLedgerScreenState extends ConsumerState<ManualLedgerScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOpenAdd || widget.initialEditItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAddEntryBottomSheet(editItem: widget.initialEditItem);
        }
      });
    }
  }

  Future<void> _showAddEntryBottomSheet({ManualLedgerEntry? editItem}) async {
    final modelController = TextEditingController(text: editItem?.model ?? '');
    final workController = TextEditingController(text: editItem?.work ?? '');
    final cashController = TextEditingController(
      text: editItem != null && editItem.cashAmount > 0
          ? editItem.cashAmount.toStringAsFixed(0)
          : '',
    );
    final onlineController = TextEditingController(
      text: editItem != null && editItem.onlineAmount > 0
          ? editItem.onlineAmount.toStringAsFixed(0)
          : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double cash = double.tryParse(cashController.text.trim()) ?? 0.0;
            final double online = double.tryParse(onlineController.text.trim()) ?? 0.0;
            final double total = cash + online;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editItem != null ? 'Edit Spreadsheet Entry' : 'Add Spreadsheet Entry',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Mobile Model *',
                      hint: 'e.g. Redmi Note 8 / Vivo Y20',
                      controller: modelController,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Work Description / Remark *',
                      hint: 'e.g. Display & Touch / Charging Jack',
                      controller: workController,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Cash (₹)',
                            hint: '0',
                            controller: cashController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Online / UPI (₹)',
                            hint: '0',
                            controller: onlineController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Live Total Preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.creditGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.creditGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Row Total (Cash + Online):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.creditGreen,
                            ),
                          ),
                          Text(
                            Formatters.currency(total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.creditGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        final model = modelController.text.trim();
                        final work = workController.text.trim();
                        if (model.isNotEmpty && work.isNotEmpty && (cash > 0 || online > 0)) {
                          final firestore = ref.read(firestoreServiceProvider);
                          if (editItem != null) {
                            await firestore.updateManualLedgerEntry(
                              editItem.copyWith(
                                model: model,
                                work: work,
                                cashAmount: cash,
                                onlineAmount: online,
                              ),
                            );
                          } else {
                            await firestore.addManualLedgerEntry(
                              ManualLedgerEntry(
                                id: '',
                                model: model,
                                work: work,
                                cashAmount: cash,
                                onlineAmount: online,
                                date: widget.date,
                              ),
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter Model, Work, and at least one payment amount.'),
                            ),
                          );
                        }
                      },
                      child: Text(editItem != null ? 'Update Row' : 'Save Row Entry'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportExcel(List<ManualLedgerEntry> entries) async {
    setState(() => _isExporting = true);
    try {
      final start = DateTime(widget.date.year, widget.date.month, widget.date.day);
      final end = start.add(const Duration(days: 1));

      final customers = await ref
          .read(firestoreServiceProvider)
          .getCustomersByDateRange(start, end);

      final allInventory = ref.read(inventoryStreamProvider).value ?? [];
      final dayInventory = allInventory.where((item) {
        return item.dateAdded.year == widget.date.year &&
            item.dateAdded.month == widget.date.month &&
            item.dateAdded.day == widget.date.day;
      }).toList();

      final ledgerData = await ref.read(firestoreServiceProvider).getDailyLedger(widget.date);
      final advanceCollected = (ledgerData['advanceCollected'] as num? ?? 0).toDouble();
      final totalCollected = (ledgerData['totalCollected'] as num? ?? 0).toDouble();
      final stockValue = (ledgerData['totalStockReceivedValue'] as num? ?? 0).toDouble();

      double manualGrandTotal = entries.fold(0.0, (sum, i) => sum + i.totalAmount);

      final finalCredit = totalCollected + advanceCollected + manualGrandTotal;
      final finalDebit = stockValue;
      final netBalance = finalCredit - finalDebit;

      await ref.read(excelExportServiceProvider).exportDailyHisaab(
            date: widget.date,
            ledgerData: ledgerData,
            finalCredit: finalCredit,
            finalDebit: finalDebit,
            netBalance: netBalance,
            manualEntries: entries,
            customers: customers,
            inventoryItems: dayInventory,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel export error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf(List<ManualLedgerEntry> entries) async {
    setState(() => _isExporting = true);
    try {
      final start = DateTime(widget.date.year, widget.date.month, widget.date.day);
      final end = start.add(const Duration(days: 1));

      final customers = await ref
          .read(firestoreServiceProvider)
          .getCustomersByDateRange(start, end);

      final allInventory = ref.read(inventoryStreamProvider).value ?? [];
      final dayInventory = allInventory.where((item) {
        return item.dateAdded.year == widget.date.year &&
            item.dateAdded.month == widget.date.month &&
            item.dateAdded.day == widget.date.day;
      }).toList();

      final ledgerData = await ref.read(firestoreServiceProvider).getDailyLedger(widget.date);
      final advanceCollected = (ledgerData['advanceCollected'] as num? ?? 0).toDouble();
      final totalCollected = (ledgerData['totalCollected'] as num? ?? 0).toDouble();
      final stockValue = (ledgerData['totalStockReceivedValue'] as num? ?? 0).toDouble();

      double manualCashTotal = entries.fold(0.0, (sum, i) => sum + i.cashAmount);
      double manualOnlineTotal = entries.fold(0.0, (sum, i) => sum + i.onlineAmount);
      double manualGrandTotal = manualCashTotal + manualOnlineTotal;

      final finalCredit = totalCollected + advanceCollected + manualGrandTotal;
      final finalDebit = stockValue;
      final netBalance = finalCredit - finalDebit;

      await PdfLedgerService.instance.generateAndShareDailyLedgerPdf(
        date: widget.date,
        finalCredit: finalCredit,
        finalDebit: finalDebit,
        netBalance: netBalance,
        manualEntries: entries,
        customers: customers,
        inventoryItems: dayInventory,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(manualLedgerStreamProvider(widget.date));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entries = entriesAsync.valueOrNull ?? [];

    final double cashTotal = entries.fold(0.0, (sum, i) => sum + i.cashAmount);
    final double onlineTotal = entries.fold(0.0, (sum, i) => sum + i.onlineAmount);
    final double grandTotal = cashTotal + onlineTotal;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spreadsheet Register',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              Formatters.date(widget.date),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: AppProgressBar())
                : const Icon(Icons.table_chart_rounded),
            tooltip: 'Export Excel (.xlsx)',
            onPressed: !_isExporting ? () => _exportExcel(entries) : null,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF (.pdf)',
            onPressed: !_isExporting ? () => _exportPdf(entries) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Action & Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_list_numbered_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Entries (${entries.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _showAddEntryBottomSheet(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add Entry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Spreadsheet Table View (4 Fix Headings: Model, Work, Cash, Online, Total)
          Expanded(
            child: entriesAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_rows_rounded,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Spreadsheet Entries',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the "+ Add Entry" button above to enter Model, Work, Cash and Online payments.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowHeight: 44,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 56,
                      headingRowColor: WidgetStateProperty.all(
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'MODEL',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'WORK',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'CASH (₹)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ONLINE (₹)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'TOTAL (₹)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ACTIONS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                      rows: items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                item.model,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                item.work,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                Formatters.currency(item.cashAmount),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.creditGreen,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                Formatters.currency(item.onlineAmount),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                Formatters.currency(item.totalAmount),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showAddEntryBottomSheet(editItem: item),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debitRed),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      await ref
                                          .read(firestoreServiceProvider)
                                          .deleteManualLedgerEntry(item.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: AppProgressBar(),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error loading entries: $err'),
              ),
            ),
          ),

          // FIXED BOTTOM SEPARATE TOTALS BAR (Requested by User)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Separate Cash Total
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CASH TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.creditGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Formatters.currency(cashTotal),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.creditGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  // Separate Online Total
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ONLINE TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Formatters.currency(onlineTotal),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  // Grand Total
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GRAND TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Formatters.currency(grandTotal),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}