import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_model.dart';
import '../../models/inventory_model.dart';
import '../../models/manual_ledger_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../services/pdf_ledger_service.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/customer_card.dart';
import '../customer/customer_detail_screen.dart';
import '../weekly_hisaab/weekly_hisaab_screen.dart';
import 'manual_ledger_screen.dart';


class DailyHisaabScreen extends ConsumerStatefulWidget {
  const DailyHisaabScreen({super.key});

  @override
  ConsumerState<DailyHisaabScreen> createState() => _DailyHisaabScreenState();
}

class _DailyHisaabScreenState extends ConsumerState<DailyHisaabScreen> {
  bool _isExporting = false;
  int _selectedTab = 0; // 0: Manual Ledger, 1: Repairs, 2: Stock Used

  void _changeDate(int days) {
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state =
        current.add(Duration(days: days));
  }

  Future<void> _selectDate() async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  Future<void> _showExportOptionsSheet(Map<String, dynamic> ledgerData) async {
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download Daily Ledger Report',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select format to download live spreadsheet daily report:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.creditGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: AppColors.creditGreen),
                ),
                title: const Text('Export as Excel Spreadsheet (.xlsx)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Excel workbook with Model, Work, Cash, Online & Total tally'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _exportExcel(ledgerData);
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.debitRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.debitRed),
                ),
                title: const Text('Export as PDF Document (.pdf)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Printable PDF document formatted with Cash & Online tally'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _exportPdf(ledgerData);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(Map<String, dynamic> ledgerData) async {
    setState(() => _isExporting = true);
    try {
      final selectedDate = ref.read(selectedDateProvider);
      final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final end = start.add(const Duration(days: 1));

      final customers = await ref
          .read(firestoreServiceProvider)
          .getCustomersByDateRange(start, end);

      final allInventory = ref.read(inventoryStreamProvider).value ?? [];
      final dayInventory = allInventory.where((item) {
        return item.dateAdded.year == selectedDate.year &&
            item.dateAdded.month == selectedDate.month &&
            item.dateAdded.day == selectedDate.day;
      }).toList();

      final advanceCollected = (ledgerData['advanceCollected'] as num? ?? 0).toDouble();
      final totalCollected = (ledgerData['totalCollected'] as num? ?? 0).toDouble();
      final stockValue = (ledgerData['totalStockReceivedValue'] as num? ?? 0).toDouble();

      final manualEntries = await ref
          .read(firestoreServiceProvider)
          .streamManualLedgerByDate(selectedDate)
          .first;

      double manualCashTotal = manualEntries.fold(0.0, (sum, i) => sum + i.cashAmount);
      double manualOnlineTotal = manualEntries.fold(0.0, (sum, i) => sum + i.onlineAmount);
      double manualGrandTotal = manualCashTotal + manualOnlineTotal;

      final finalCredit = totalCollected + advanceCollected + manualGrandTotal;
      final finalDebit = stockValue;
      final netBalance = finalCredit - finalDebit;

      await PdfLedgerService.instance.generateAndShareDailyLedgerPdf(
        date: selectedDate,
        finalCredit: finalCredit,
        finalDebit: finalDebit,
        netBalance: netBalance,
        manualEntries: manualEntries,
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

  Future<void> _exportExcel(Map<String, dynamic> ledgerData) async {
    setState(() => _isExporting = true);
    try {
      final selectedDate = ref.read(selectedDateProvider);
      final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final end = start.add(const Duration(days: 1));

      final customers = await ref
          .read(firestoreServiceProvider)
          .getCustomersByDateRange(start, end);

      final allInventory = ref.read(inventoryStreamProvider).value ?? [];
      final dayInventory = allInventory.where((item) {
        return item.dateAdded.year == selectedDate.year &&
            item.dateAdded.month == selectedDate.month &&
            item.dateAdded.day == selectedDate.day;
      }).toList();

      final advanceCollected = (ledgerData['advanceCollected'] as num? ?? 0).toDouble();
      final totalCollected = (ledgerData['totalCollected'] as num? ?? 0).toDouble();
      final stockValue = (ledgerData['totalStockReceivedValue'] as num? ?? 0).toDouble();

      final manualEntries = await ref
          .read(firestoreServiceProvider)
          .streamManualLedgerByDate(selectedDate)
          .first;

      double manualGrandTotal = manualEntries.fold(0.0, (sum, i) => sum + i.totalAmount);

      final finalCredit = totalCollected + advanceCollected + manualGrandTotal;
      final finalDebit = stockValue;
      final netBalance = finalCredit - finalDebit;

      await ref.read(excelExportServiceProvider).exportDailyHisaab(
            date: selectedDate,
            ledgerData: ledgerData,
            finalCredit: finalCredit,
            finalDebit: finalDebit,
            netBalance: netBalance,
            manualEntries: manualEntries,
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

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final ledgerAsync = ref.watch(dailyLedgerProvider(selectedDate));
    final allCustomers = ref.watch(customersStreamProvider).value ?? [];
    final allInventory = ref.watch(inventoryStreamProvider).value ?? [];
    final isOwner = ref.watch(isOwnerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dayCustomers = allCustomers.where((c) {
      return c.dateReceived.year == selectedDate.year &&
          c.dateReceived.month == selectedDate.month &&
          c.dateReceived.day == selectedDate.day;
    }).toList();

    final dayInventory = allInventory.where((i) {
      return i.dateAdded.year == selectedDate.year &&
          i.dateAdded.month == selectedDate.month &&
          i.dateAdded.day == selectedDate.day;
    }).toList();

    final manualEntriesAsync = ref.watch(manualLedgerStreamProvider(selectedDate));
    final manualEntries = manualEntriesAsync.valueOrNull ?? [];

    final double manualCashTotal = manualEntries.fold(0.0, (sum, i) => sum + i.cashAmount);
    final double manualOnlineTotal = manualEntries.fold(0.0, (sum, i) => sum + i.onlineAmount);
    final double manualGrandTotal = manualCashTotal + manualOnlineTotal;

    final ledgerData = ledgerAsync.valueOrNull ?? {};
    final newCount = ledgerData['newCustomersCount'] as int? ?? dayCustomers.length;
    final advanceCollected = (ledgerData['advanceCollected'] as num? ?? 0).toDouble();
    final deliveredCount = ledgerData['deliveredCount'] as int? ?? 0;
    final totalCollected = (ledgerData['totalCollected'] as num? ?? 0).toDouble();
    final stockValue = (ledgerData['totalStockReceivedValue'] as num? ?? 0).toDouble();

    final autoCredit = totalCollected + advanceCollected;
    final autoDebit = stockValue;

    final finalCredit = autoCredit + manualGrandTotal;
    final finalDebit = autoDebit;
    final netBalance = finalCredit - finalDebit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Ledger'),
        actions: [
          if (isOwner)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WeeklyHisaabScreen()),
                );
              },
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: const Text('Weekly'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppProgressBar(),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: 'Download Report (Excel / PDF)',
            onPressed: ledgerAsync.hasValue && !_isExporting
                ? () => _showExportOptionsSheet(ledgerAsync.value!)
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Compact Date Switcher
            _buildDateBar(theme, isDark, selectedDate),
            const SizedBox(height: 6),

            // 2. Compact Financial Summary Bar (Unified in one modern card)
            _buildFinancialSummary(
              theme: theme,
              isDark: isDark,
              isOwner: isOwner,
              finalCredit: finalCredit,
              finalDebit: finalDebit,
              netBalance: netBalance,
              newCount: newCount,
              deliveredCount: deliveredCount,
              advanceCollected: advanceCollected,
              stockCount: dayInventory.length,
            ),
            const SizedBox(height: 10),

            // 3. Module Selector Tabs (Manual Ledger | Customer Repairs | Stock Used)
            _buildTabSelector(
              theme: theme,
              isDark: isDark,
              manualCount: manualEntries.length,
              repairsCount: dayCustomers.length,
              stockCount: dayInventory.length,
            ),
            const SizedBox(height: 10),

            // 4. Tab Content (Zero blank space — active module is front and center!)
            if (_selectedTab == 0)
              _buildManualSpreadsheetSection(
                theme: theme,
                isDark: isDark,
                manualEntries: manualEntries,
                manualCashTotal: manualCashTotal,
                manualOnlineTotal: manualOnlineTotal,
                manualGrandTotal: manualGrandTotal,
                selectedDate: selectedDate,
              )
            else if (_selectedTab == 1)
              _buildCustomersSection(
                theme: theme,
                isDark: isDark,
                customers: dayCustomers,
                selectedDate: selectedDate,
              )
            else
              _buildStockSection(
                theme: theme,
                isDark: isDark,
                items: dayInventory,
                selectedDate: selectedDate,
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBar(ThemeData theme, bool isDark, DateTime selectedDate) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.date(selectedDate),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (!isToday) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ref.read(selectedDateProvider.notifier).state = DateTime.now();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary({
    required ThemeData theme,
    required bool isDark,
    required bool isOwner,
    required double finalCredit,
    required double finalDebit,
    required double netBalance,
    required int newCount,
    required int deliveredCount,
    required double advanceCollected,
    required int stockCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFinancialPillar(
                  theme: theme,
                  label: 'CASH IN',
                  amount: finalCredit,
                  color: AppColors.creditGreen,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                height: 32,
                width: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildFinancialPillar(
                  theme: theme,
                  label: 'CASH OUT',
                  amount: finalDebit,
                  color: AppColors.debitRed,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                height: 32,
                width: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildFinancialPillar(
                  theme: theme,
                  label: 'NET BALANCE',
                  amount: netBalance,
                  color: netBalance >= 0 ? AppColors.creditGreen : AppColors.debitRed,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildActivityBadge(
                icon: Icons.person_add_rounded,
                label: '$newCount New',
                color: AppColors.statusInProgress,
              ),
              _buildActivityBadge(
                icon: Icons.check_circle_rounded,
                label: '$deliveredCount Delivered',
                color: AppColors.creditGreen,
              ),
              if (isOwner)
                _buildActivityBadge(
                  icon: Icons.payments_rounded,
                  label: 'Adv ${Formatters.currency(advanceCollected)}',
                  color: AppColors.statusRepaired,
                ),
              _buildActivityBadge(
                icon: Icons.build_circle_rounded,
                label: '$stockCount Parts',
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPillar({
    required ThemeData theme,
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector({
    required ThemeData theme,
    required bool isDark,
    required int manualCount,
    required int repairsCount,
    required int stockCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(
            index: 0,
            label: 'Spreadsheet',
            count: manualCount,
            icon: Icons.table_chart_rounded,
            theme: theme,
            isDark: isDark,
          ),
          _buildTabButton(
            index: 1,
            label: 'Repairs',
            count: repairsCount,
            icon: Icons.phone_android_rounded,
            theme: theme,
            isDark: isDark,
          ),
          _buildTabButton(
            index: 2,
            label: 'Stock Used',
            count: stockCount,
            icon: Icons.inventory_2_rounded,
            theme: theme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.onPrimary
                    : (isDark ? Colors.white70 : AppColors.subtleText),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  count > 0 ? '$label ($count)' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.onPrimary
                        : (isDark ? Colors.white70 : AppColors.subtleText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualSpreadsheetSection({
    required ThemeData theme,
    required bool isDark,
    required List<ManualLedgerEntry> manualEntries,
    required double manualCashTotal,
    required double manualOnlineTotal,
    required double manualGrandTotal,
    required DateTime selectedDate,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Spreadsheet Entries',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ManualLedgerScreen(date: selectedDate, initialOpenAdd: true),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Add Entry',
                          style: TextStyle(
                            fontSize: 11,
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
          const SizedBox(height: 10),

          if (manualEntries.isEmpty)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManualLedgerScreen(date: selectedDate),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.post_add_rounded,
                      size: 32,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No spreadsheet entries recorded for today.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap here to open full register page and add Model, Work, Cash & Online.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManualLedgerScreen(date: selectedDate),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Open Full Spreadsheet Register',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowHeight: 38,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                columns: const [
                  DataColumn(label: Text('Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Work / Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Cash (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Online (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: manualEntries.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.model, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(item.work, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(Formatters.currency(item.cashAmount), style: const TextStyle(fontSize: 12, color: AppColors.creditGreen))),
                      DataCell(Text(Formatters.currency(item.onlineAmount), style: const TextStyle(fontSize: 12, color: AppColors.secondary))),
                      DataCell(Text(Formatters.currency(item.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ManualLedgerScreen(
                                      date: selectedDate,
                                      initialEditItem: item,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.debitRed),
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
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cash: ${Formatters.currency(manualCashTotal)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.creditGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Online: ${Formatters.currency(manualOnlineTotal)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'TOTAL: ${Formatters.currency(manualGrandTotal)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomersSection({
    required ThemeData theme,
    required bool isDark,
    required List<CustomerModel> customers,
    required DateTime selectedDate,
  }) {
    if (customers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.person_off_outlined, size: 32, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'No customer repairs on ${Formatters.date(selectedDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New repair jobs created today will automatically appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return CustomerCard(
          customer: customer,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(customer: customer),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockSection({
    required ThemeData theme,
    required bool isDark,
    required List<InventoryModel> items,
    required DateTime selectedDate,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 32, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'No stock parts recorded on ${Formatters.date(selectedDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Parts received or added on this day will be listed here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.build_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Qty: ${item.quantity} units • ${Formatters.currency(item.purchasePricePerUnit)}/unit',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(item.totalValue),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
