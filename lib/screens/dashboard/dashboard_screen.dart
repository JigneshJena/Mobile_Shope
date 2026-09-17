import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart'; // AppSizes lives here
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/stat_card.dart';
import '../customer/add_customer_screen.dart';
import '../customer/customer_detail_screen.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModelAsync = ref.watch(currentUserModelProvider);
    final userModel = userModelAsync.valueOrNull;
    final isOwner = ref.watch(isOwnerProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final allUsersAsync = ref.watch(allUsersStreamProvider);
    final theme = Theme.of(context);


    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOwner
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOwner
                    ? AppColors.secondary.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOwner ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                  size: 14,
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersStreamProvider);
          ref.invalidate(inventoryStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clean Compact Header (No "Welcome Back" text)
              AnimatedEntrance(
                duration: const Duration(milliseconds: 350),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userModel?.name.isNotEmpty ?? false ? userModel!.name : "Shop Manager",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Shop Dashboard',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              Formatters.date(today),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Metrics / Stat Cards (2x2 Grid with overflow prevention)
              customersAsync.when(
                data: (customers) {
                  return inventoryAsync.when(
                    data: (inventory) {
                      final todayCustomers = customers.where((c) {
                        return c.dateReceived.year == today.year &&
                            c.dateReceived.month == today.month &&
                            c.dateReceived.day == today.day;
                      }).toList();

                      final pendingCount = customers
                          .where((c) => c.status != RepairStatus.delivered)
                          .length;

                      final todayStockCount = inventory.where((i) {
                        return i.dateAdded.year == today.year &&
                            i.dateAdded.month == today.month &&
                            i.dateAdded.day == today.day;
                      }).length;

                      final todayAdvance = todayCustomers.fold(
                        0.0,
                        (sum, c) => sum + c.advanceAmount,
                      );

                      final todayDeliveredCount = customers.where((c) {
                        return c.status == RepairStatus.delivered &&
                            c.dateDelivered != null &&
                            c.dateDelivered!.year == today.year &&
                            c.dateDelivered!.month == today.month &&
                            c.dateDelivered!.day == today.day;
                      }).length;

                      final totalDeliveredCount = customers
                          .where((c) => c.status == RepairStatus.delivered)
                          .length;

                      final employeeCount = allUsersAsync.valueOrNull?.length ?? 0;

                      return AnimatedEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            crossAxisSpacing: AppSizes.gridCrossAxisSpacing,
                            mainAxisSpacing: AppSizes.gridMainAxisSpacing,
                            mainAxisExtent: AppSizes.dashboardCardHeight,
                          ),
                          children: [
                            StatCard(
                              label: "Today's Customers",
                              value: '${todayCustomers.length}',
                              icon: Icons.person_add_rounded,
                              color: AppColors.statusInProgress,
                            ),
                            StatCard(
                              label: 'Pending Repairs',
                              value: '$pendingCount',
                              icon: Icons.pending_actions_rounded,
                              color: AppColors.statusPending,
                            ),
                            StatCard(
                              label: 'Delivered Devices',
                              value: '$todayDeliveredCount ($totalDeliveredCount total)',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.creditGreen,
                            ),
                            if (isOwner) ...[
                              StatCard(
                                label: "Today's Revenue",
                                value: Formatters.currency(todayAdvance),
                                icon: Icons.currency_rupee_rounded,
                                color: AppColors.creditGreen,
                              ),
                              StatCard(
                                label: 'Total Employees',
                                value: '$employeeCount',
                                icon: Icons.badge_rounded,
                                color: AppColors.secondary,
                              ),
                            ] else
                              StatCard(
                                label: 'New Parts Today',
                                value: '$todayStockCount items',
                                icon: Icons.inventory_2_rounded,
                                color: AppColors.statusRepaired,
                              ),
                          ],
                        ),
                      );

                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        child: AppProgressBar(),
                      ),
                    ),
                    error: (e, st) => const SizedBox.shrink(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: AppProgressBar(),
                  ),
                ),
                error: (err, _) => Text(
                  'Failed to load statistics: $err',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Section: Active Repair Jobs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Repair Jobs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              customersAsync.when(
                data: (customers) {
                  final activeJobs = customers
                      .where((c) => c.status != RepairStatus.delivered)
                      .take(5)
                      .toList();

                  if (activeJobs.isEmpty) {
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 44, color: AppColors.creditGreen),
                          const SizedBox(height: 10),
                          Text(
                            'All caught up!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No active repair jobs pending right now.',
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
                    itemCount: activeJobs.length,
                    itemBuilder: (context, index) {
                      final job = activeJobs[index];
                      return AnimatedEntrance(
                        delay: Duration(milliseconds: 150 + (index * 40)),
                        child: CustomerCard(
                          customer: job,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(customer: job),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_add_customer_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddCustomerScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Customer'),
      ),
    );
  }
}
