import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/customer_card.dart';
import '../customer/add_customer_screen.dart';
import '../customer/customer_detail_screen.dart';
import '../inventory/add_inventory_screen.dart';
import '../notes/notes_screen.dart';
import '../shell/app_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openAddCustomer(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (ctx, anim, sa) => const AddCustomerScreen(),
      transitionsBuilder: (ctx, anim, sa, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 220),
    ));
  }

  void _openAddInventory(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (ctx, anim, sa) => const AddInventoryScreen(),
      transitionsBuilder: (ctx, anim, sa, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 220),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentUserModelProvider); // triggers rebuild on user change
    final isOwner = ref.watch(isOwnerProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final today = DateTime.now();
    final dueNotesCount = ref.watch(dueNotesCountProvider);

    // ── Computed data ─────────────────────────────────────────────────────────
    final customers = customersAsync.valueOrNull ?? [];
    final inventory = inventoryAsync.valueOrNull ?? [];

    final todayCustomers = customers.where((c) =>
        c.dateReceived.year == today.year &&
        c.dateReceived.month == today.month &&
        c.dateReceived.day == today.day).toList();

    final pendingCount = customers.where((c) => c.status == RepairStatus.pending).length;
    final inProgressCount = customers.where((c) => c.status == RepairStatus.inProgress).length;
    final repairedCount = customers.where((c) => c.status == RepairStatus.repaired).length;
    final deliveredCount = customers.where((c) => c.status == RepairStatus.delivered).length;

    final todayRevenue = todayCustomers.fold(0.0, (s, c) => s + c.advanceAmount);

    final todayDelivered = customers.where((c) =>
        c.status == RepairStatus.delivered &&
        c.dateDelivered != null &&
        c.dateDelivered!.year == today.year &&
        c.dateDelivered!.month == today.month &&
        c.dateDelivered!.day == today.day).length;

    final lowStockItems = inventory.where((i) => !i.isReturned && i.quantity > 0 && i.quantity <= 2).toList();
    final activeJobs = customers.where((c) => c.status != RepairStatus.delivered).toList();

    // ── Colour helpers ────────────────────────────────────────────────────────
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Text(AppConstants.appName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isOwner ? AppColors.secondary : AppColors.primary)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isOwner ? AppColors.secondary : AppColors.primary)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOwner ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                    size: 13,
                    color: isOwner ? AppColors.secondary : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOwner ? 'OWNER' : 'STAFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOwner ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersStreamProvider);
          ref.invalidate(inventoryStreamProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── 1. Hero Stats Row ──────────────────────────────────────
                  _StatsRow(
                    today: today,
                    todayCustomers: todayCustomers.length,
                    todayDelivered: todayDelivered,
                    totalDelivered: deliveredCount,
                    pendingCount: pendingCount + inProgressCount + repairedCount,
                    isOwner: isOwner,
                    todayRevenue: todayRevenue,
                    isLoading: customersAsync.isLoading,
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    onStatTap: (status) {
                      ref.read(customerStatusFilterProvider.notifier).state = status;
                      ref.read(shellTabProvider.notifier).state = 1;
                    },
                    onLedgerTap: isOwner
                        ? () {
                            ref.read(selectedDateProvider.notifier).state = DateTime.now();
                            ref.read(shellTabProvider.notifier).state = 3;
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // ── 2. Quick Actions ──────────────────────────────────────
                  _QuickActionsRow(
                    isOwner: isOwner,
                    isDark: isDark,
                    dueNotesCount: dueNotesCount,
                    onNewRepair: () => _openAddCustomer(context),
                    onAddPart: () => _openAddInventory(context),
                    onNotes: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotesScreen()),
                      );
                    },
                    onLedger: isOwner
                        ? () {
                            ref.read(selectedDateProvider.notifier).state = DateTime.now();
                            ref.read(shellTabProvider.notifier).state = 3;
                          }
                        : () => ref.read(shellTabProvider.notifier).state = 2,
                  ),
                  const SizedBox(height: 10),

                  // ── 3. Status Breakdown ───────────────────────────────────
                  _StatusBreakdownBar(
                    pending: pendingCount,
                    inProgress: inProgressCount,
                    repaired: repairedCount,
                    delivered: deliveredCount,
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    onTap: (status) {
                      ref.read(customerStatusFilterProvider.notifier).state = status;
                      ref.read(shellTabProvider.notifier).state = 1;
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── 4. Low-stock alert ────────────────────────────────────
                  if (lowStockItems.isNotEmpty) ...[
                    _LowStockBanner(
                      count: lowStockItems.length,
                      onTap: () => ref.read(shellTabProvider.notifier).state = 2,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── 5. Active Repair Jobs header ──────────────────────────
                  Row(
                    children: [
                      Text(
                        'Active Repair Jobs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusPending.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeJobs.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusPending,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(customerStatusFilterProvider.notifier).state = null;
                          ref.read(shellTabProvider.notifier).state = 1;
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 11, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ]),
              ),
            ),

            // ── 6. Active Jobs list ──────────────────────────────────────────
            if (customersAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: AppProgressBar(),
                ),
              )
            else if (activeJobs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 36, color: AppColors.creditGreen),
                        const SizedBox(height: 8),
                        Text('All caught up!',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'No pending jobs. Tap below to create a repair job.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: size.width * 0.5,
                          child: ElevatedButton.icon(
                            onPressed: () => _openAddCustomer(context),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Job',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                sliver: SliverList.separated(
                  itemCount: activeJobs.length > 10 ? 10 : activeJobs.length,
                  separatorBuilder: (ctx, si) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final job = activeJobs[i];
                    return CustomerCard(
                      customer: job,
                      margin: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).push(PageRouteBuilder(
                        pageBuilder: (ctx, anim, sa) => CustomerDetailScreen(customer: job),
                        transitionsBuilder: (ctx, anim, sa, child) => FadeTransition(
                          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                          child: child,
                        ),
                        transitionDuration: const Duration(milliseconds: 220),
                      )),
                    );
                  },
                ),
              ),

            // bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton(
          heroTag: 'dashboard_fab',
          elevation: 3,
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          onPressed: () => _openAddCustomer(context),
          child: const Icon(Icons.person_add_rounded, size: 24),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Hero Stats Row — 2×2 mini cards
// ──────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.today,
    required this.todayCustomers,
    required this.todayDelivered,
    required this.totalDelivered,
    required this.pendingCount,
    required this.isOwner,
    required this.todayRevenue,
    required this.isLoading,
    required this.isDark,
    required this.cardBg,
    required this.cardBorder,
    required this.onStatTap,
    required this.onLedgerTap,
  });

  final DateTime today;
  final int todayCustomers;
  final int todayDelivered;
  final int totalDelivered;
  final int pendingCount;
  final bool isOwner;
  final double todayRevenue;
  final bool isLoading;
  final bool isDark;
  final Color cardBg;
  final Color cardBorder;
  final void Function(String? status) onStatTap;
  final VoidCallback? onLedgerTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.people_alt_rounded,
            value: '$todayCustomers',
            label: "Today's",
            sublabel: 'Customers',
            color: AppColors.statusInProgress,
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
            isLoading: isLoading,
            onTap: () => onStatTap(null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.pending_actions_rounded,
            value: '$pendingCount',
            label: 'Active',
            sublabel: 'Repairs',
            color: AppColors.statusPending,
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
            isLoading: isLoading,
            onTap: () => onStatTap(RepairStatus.pending),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '$todayDelivered',
            label: "Today's",
            sublabel: 'Delivered',
            color: AppColors.creditGreen,
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
            isLoading: isLoading,
            onTap: () => onStatTap(RepairStatus.delivered),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: isOwner
              ? _MiniStatCard(
                  icon: Icons.currency_rupee_rounded,
                  value: Formatters.compactCurrency(todayRevenue),
                  label: "Today's",
                  sublabel: 'Revenue',
                  color: AppColors.secondary,
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  isLoading: isLoading,
                  onTap: onLedgerTap,
                )
              : _MiniStatCard(
                  icon: Icons.check_circle_rounded,
                  value: '$totalDelivered',
                  label: 'Total',
                  sublabel: 'Delivered',
                  color: AppColors.statusRepaired,
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  isLoading: isLoading,
                  onTap: () => onStatTap(RepairStatus.delivered),
                ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDark,
    required this.cardBg,
    required this.cardBorder,
    required this.isLoading,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;
  final Color cardBg;
  final Color cardBorder;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              isLoading
                  ? SizedBox(
                      height: 18,
                      width: 36,
                      child: LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(4),
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                        height: 1.1,
                      ),
                    ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Quick Actions Row
// ──────────────────────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.isOwner,
    required this.isDark,
    required this.dueNotesCount,
    required this.onNewRepair,
    required this.onAddPart,
    required this.onNotes,
    required this.onLedger,
  });

  final bool isOwner;
  final bool isDark;
  final int dueNotesCount;
  final VoidCallback onNewRepair;
  final VoidCallback onAddPart;
  final VoidCallback onNotes;
  final VoidCallback onLedger;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Row(
      children: [
        _QuickTile(
          icon: Icons.person_add_alt_1_rounded,
          label: 'New Repair',
          color: AppColors.secondary,
          cardBg: cardBg,
          isDark: isDark,
          onTap: onNewRepair,
        ),
        const SizedBox(width: 8),
        _QuickTile(
          icon: Icons.add_shopping_cart_rounded,
          label: 'Add Part',
          color: AppColors.statusRepaired,
          cardBg: cardBg,
          isDark: isDark,
          onTap: onAddPart,
        ),
        const SizedBox(width: 8),
        _QuickTile(
          icon: Icons.note_alt_outlined,
          label: 'Notes',
          color: AppColors.primary,
          cardBg: cardBg,
          isDark: isDark,
          badgeCount: dueNotesCount,
          onTap: onNotes,
        ),
        const SizedBox(width: 8),
        _QuickTile(
          icon: isOwner ? Icons.account_balance_wallet_rounded : Icons.inventory_2_rounded,
          label: isOwner ? 'Ledger' : 'Stock',
          color: isOwner ? AppColors.creditGreen : AppColors.statusInProgress,
          cardBg: cardBg,
          isDark: isDark,
          onTap: onLedger,
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.cardBg,
    required this.isDark,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color cardBg;
  final bool isDark;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconWidget = Icon(icon, size: 16, color: color);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                badgeCount > 0
                    ? Badge.count(
                        count: badgeCount,
                        backgroundColor: AppColors.debitRed,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: iconWidget,
                        ),
                      )
                    : Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: iconWidget,
                      ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Status Breakdown Bar
// ──────────────────────────────────────────────────────────────────────────────
class _StatusBreakdownBar extends StatelessWidget {
  const _StatusBreakdownBar({
    required this.pending,
    required this.inProgress,
    required this.repaired,
    required this.delivered,
    required this.isDark,
    required this.cardBg,
    required this.cardBorder,
    required this.onTap,
  });

  final int pending;
  final int inProgress;
  final int repaired;
  final int delivered;
  final bool isDark;
  final Color cardBg;
  final Color cardBorder;
  final void Function(String status) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          _StatusPill(label: 'Pending', count: pending,
              color: AppColors.statusPending,
              onTap: () => onTap(RepairStatus.pending)),
          _Divider(isDark: isDark),
          _StatusPill(label: 'Working', count: inProgress,
              color: AppColors.statusInProgress,
              onTap: () => onTap(RepairStatus.inProgress)),
          _Divider(isDark: isDark),
          _StatusPill(label: 'Repaired', count: repaired,
              color: AppColors.statusRepaired,
              onTap: () => onTap(RepairStatus.repaired)),
          _Divider(isDark: isDark),
          _StatusPill(label: 'Delivered', count: delivered,
              color: AppColors.creditGreen,
              onTap: () => onTap(RepairStatus.delivered)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Low-stock banner
// ──────────────────────────────────────────────────────────────────────────────
class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.debitRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.debitRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count part${count > 1 ? 's' : ''} running low on stock (≤2 left)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.debitRed,
                  ),
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.debitRed)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: AppColors.debitRed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
