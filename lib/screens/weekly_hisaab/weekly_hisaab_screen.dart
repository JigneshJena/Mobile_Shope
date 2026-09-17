import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_model.dart';
import '../../models/weekly_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/inventory_card.dart';

class WeeklyHisaabScreen extends ConsumerStatefulWidget {
  const WeeklyHisaabScreen({super.key});

  @override
  ConsumerState<WeeklyHisaabScreen> createState() => _WeeklyHisaabScreenState();
}

class _WeeklyHisaabScreenState extends ConsumerState<WeeklyHisaabScreen> {
  late DateTime _weekStart;
  late DateTime _weekEnd;
  List<InventoryModel> _items = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _weekStart = _weekEnd.subtract(const Duration(days: 6));
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    setState(() => _isLoading = true);
    try {
      final items = await ref
          .read(firestoreServiceProvider)
          .getInventoryByDateRange(_weekStart, _weekEnd);
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _weekStart, end: _weekEnd),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _weekStart = picked.start;
        _weekEnd = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _loadWeekData();
    }
  }

  Future<void> _saveReport(double purchase, double returns) async {
    final report = WeeklyReportModel(
      id: '${_weekStart.millisecondsSinceEpoch}_${_weekEnd.millisecondsSinceEpoch}',
      weekStart: _weekStart,
      weekEnd: _weekEnd,
      totalPurchaseAmount: purchase,
      totalReturnAmount: returns,
      paymentStatus: 'pending',
    );

    try {
      await ref.read(weeklyReportNotifierProvider.notifier).saveReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly report saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    }
  }

  Future<void> _exportExcel(double purchase, double returns) async {
    setState(() => _isExporting = true);
    try {
      final report = WeeklyReportModel(
        id: 'export_${DateTime.now().millisecondsSinceEpoch}',
        weekStart: _weekStart,
        weekEnd: _weekEnd,
        totalPurchaseAmount: purchase,
        totalReturnAmount: returns,
        paymentStatus: 'pending',
      );

      await ref
          .read(excelExportServiceProvider)
          .exportWeeklyReport(report, _items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final pastReportsAsync = ref.watch(weeklyReportsProvider);
    final theme = Theme.of(context);

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weekly Report')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    'Access Restricted',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to view financial reports. Please contact the Owner.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Calculations
    final totalPurchase = _items
        .where((i) => !i.isReturned)
        .fold(0.0, (sum, i) => sum + i.totalValue);
    final totalReturns = _items
        .where((i) => i.isReturned)
        .fold(0.0, (sum, i) => sum + i.totalValue);
    final netPayable = totalPurchase - totalReturns;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Report (Owner Only)'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: 'Export to Excel',
            onPressed: _items.isNotEmpty && !_isExporting
                ? () => _exportExcel(totalPurchase, totalReturns)
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Date Range Picker Card
            AnimatedEntrance(
              delay: const Duration(milliseconds: 50),
              child: GlassCard(
                onTap: _pickDateRange,
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.date_range_rounded,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Week Range',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${Formatters.date(_weekStart)}  →  ${Formatters.date(_weekEnd)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Summary Card: Purchase vs Return -> Net Payable
            AnimatedEntrance(
              delay: const Duration(milliseconds: 100),
              child: GlassCard(
                tintColor: theme.colorScheme.primary,
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Stock Purchased:',
                            style: theme.textTheme.bodyMedium),
                        Text(
                          Formatters.currency(totalPurchase),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock Returned (Refund):',
                            style: theme.textTheme.bodyMedium),
                        Text(
                          '- ${Formatters.currency(totalReturns)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Net Payable to Supplier:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          Formatters.currency(netPayable),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action: Save report button
            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
              child: AppButton(
                label: 'Save Weekly Report',
                icon: Icons.save_alt_rounded,
                onPressed: _items.isNotEmpty
                    ? () => _saveReport(totalPurchase, totalReturns)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Inventory Items in this range
            Text(
              'Week Inventory Items (${_items.length} items)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_items.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(28.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 36, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(
                        'No stock items recorded for this date range',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return AnimatedEntrance(
                    delay: Duration(milliseconds: 25 * index),
                    child: InventoryCard(item: _items[index]),
                  );
                },
              ),
            const SizedBox(height: 24),

            // 4. Past Saved Reports
            Text(
              'Past Saved Reports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            pastReportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return GlassCard(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 36, color: theme.colorScheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            'No weekly reports saved yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final isPaid = report.paymentStatus == 'paid';

                    return AnimatedEntrance(
                      delay: Duration(milliseconds: 30 * index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isPaid
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_actions_rounded,
                                color: isPaid ? Colors.green : Colors.orange,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${Formatters.date(report.weekStart)} - ${Formatters.date(report.weekEnd)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Purchased: ${Formatters.currency(report.totalPurchaseAmount)} | Returned: ${Formatters.currency(report.totalReturnAmount)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.currency(report.netPayable),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (!isPaid)
                                    InkWell(
                                      onTap: () {
                                        ref
                                            .read(
                                                weeklyReportNotifierProvider
                                                    .notifier)
                                            .markPaid(report.id);
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Mark Paid',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'PAID',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, _) => GlassCard(
                tintColor: Colors.red.shade900,
                padding: const EdgeInsets.all(16),
                child: Text('Saved reports error: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
