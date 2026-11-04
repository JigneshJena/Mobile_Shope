import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/inventory_grid_card.dart';
import 'add_inventory_screen.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  Future<void> _handleMarkReturned(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    String itemName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Returned?'),
        content: Text('Are you sure you want to mark "$itemName" as defective / returned?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(inventoryNotifierProvider.notifier).markReturned(itemId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item marked as returned.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to mark item returned: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _openAddInventory(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const AddInventoryScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(filteredInventoryProvider);
    final currentCategory = ref.watch(inventoryCategoryFilterProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Parts'),
      ),
      body: Column(
        children: [
          // 1. Category Filter Chips (Horizontal Scroll)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      'All',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentCategory == null
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    selected: currentCategory == null,
                    selectedColor: AppColors.primary,
                    onSelected: (_) {
                      ref.read(inventoryCategoryFilterProvider.notifier).state = null;
                    },
                  ),
                ),
                ...InventoryCategory.all.map((cat) {
                  final isSelected = currentCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        InventoryCategory.label(cat),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      onSelected: (selected) {
                        ref.read(inventoryCategoryFilterProvider.notifier).state =
                            selected ? cat : null;
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // 2. Summary Bar
          inventoryAsync.when(
            data: (items) {
              final activeItems = items.where((i) => !i.isReturned).toList();
              final totalQuantity = activeItems.fold(0, (sum, i) => sum + i.quantity);
              final totalValue = activeItems.fold(0.0, (sum, i) => sum + i.totalValue);

              return GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Items: ${items.length} ($totalQuantity units)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOwner)
                      Text(
                        'Total Value: ${Formatters.currency(totalValue)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),

          // 3. Inventory Grid View
          Expanded(
            child: inventoryAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No inventory items found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button at the bottom to add new spare parts.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inventoryStreamProvider);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 200,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return AnimatedEntrance(
                            delay: Duration(milliseconds: (index % 8) * 35),
                            child: InventoryGridCard(
                              item: item,
                              onMarkReturned: (item.isReturned || item.quantity <= 0)
                                  ? null
                                  : () => _handleMarkReturned(
                                        context,
                                        ref,
                                        item.id,
                                        item.itemName,
                                      ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: AppProgressBar(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading inventory: $err'),
                ),
              ),
            ),
          ),
        ],
      ),
      // Sleek circular FAB safely above the bottom navigation bar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95, right: 6),
        child: FloatingActionButton(
          heroTag: 'inventory_list_add_fab',
          onPressed: () => _openAddInventory(context),
          elevation: 4,
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          tooltip: 'Add Part',
          child: const Icon(Icons.add_rounded, size: 24),
        ),
      ),
    );
  }
}
