import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_model.dart';
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

  Future<void> _handleDeleteItem(
    BuildContext context,
    WidgetRef ref,
    InventoryModel item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.debitRed),
            SizedBox(width: 8),
            Text('Delete Inventory Part?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.itemName}" from inventory?\n\n'
          'This will remove it completely from the database.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.debitRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(inventoryNotifierProvider.notifier).deleteItem(item.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item "${item.itemName}" deleted from inventory.'),
              backgroundColor: AppColors.debitRed,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete item: $e'),
              backgroundColor: AppColors.debitRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleEditItem(
    BuildContext context,
    WidgetRef ref,
    InventoryModel item,
  ) async {
    final nameCtrl = TextEditingController(text: item.itemName);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl =
        TextEditingController(text: item.purchasePrice.toStringAsFixed(0));
    final supplierCtrl = TextEditingController(text: item.supplierName ?? '');
    String selectedCategory = item.category;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Inventory Part'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Part / Item Name *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter part name' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: InventoryCategory.all.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(InventoryCategory.label(c)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity *'),
                          validator: (v) {
                            final q = int.tryParse(v?.trim() ?? '');
                            return (q == null || q < 0) ? 'Valid qty' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Price (₹) *'),
                          validator: (v) {
                            final p = double.tryParse(v?.trim() ?? '');
                            return (p == null || p < 0) ? 'Valid price' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Supplier Name (Optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updatedItem = item.copyWith(
        itemName: nameCtrl.text.trim(),
        category: selectedCategory,
        quantity: int.tryParse(qtyCtrl.text.trim()) ?? item.quantity,
        purchasePrice:
            double.tryParse(priceCtrl.text.trim()) ?? item.purchasePrice,
        supplierName: supplierCtrl.text.trim().isEmpty
            ? null
            : supplierCtrl.text.trim(),
      );
      try {
        await ref
            .read(inventoryNotifierProvider.notifier)
            .updateItem(updatedItem);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventory part updated.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update part: $e')),
          );
        }
      }
    }
  }

  void _showItemDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    InventoryModel item,
    bool isOwner,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (item.isReturned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.debitRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('DEFECTIVE / RETURNED',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.debitRed)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow('Category', InventoryCategory.label(item.category)),
              _detailRow('Stock Quantity', '${item.quantity} units in stock'),
              _detailRow('Purchase Price', Formatters.currency(item.purchasePrice)),
              _detailRow('Total Inventory Value', Formatters.currency(item.totalValue)),
              if (item.supplierName != null && item.supplierName!.isNotEmpty)
                _detailRow('Supplier', item.supplierName!),
              _detailRow('Added On', Formatters.date(item.dateAdded)),
              const SizedBox(height: 16),
              if (isOwner) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Part'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleEditItem(context, ref, item);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.debitRed,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Delete Part'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleDeleteItem(context, ref, item);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
          // 1. Category Filter Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _CategoryDropdown(
              currentCategory: currentCategory,
              onChanged: (val) =>
                  ref.read(inventoryCategoryFilterProvider.notifier).state = val,
              theme: theme,
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
                              onEdit: isOwner
                                  ? () => _handleEditItem(context, ref, item)
                                  : null,
                              onDelete: isOwner
                                  ? () => _handleDeleteItem(context, ref, item)
                                  : null,
                              onTap: () => _showItemDetailsSheet(
                                  context, ref, item, isOwner),
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

// ─────────────────────────────────────────────────────────────────────────────
// Category filter dropdown widget
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.currentCategory,
    required this.onChanged,
    required this.theme,
  });

  final String? currentCategory;
  final ValueChanged<String?> onChanged;
  final ThemeData theme;

  String _label(String? cat) =>
      cat == null ? 'All Categories' : InventoryCategory.label(cat);

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () async {
        final box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final size = box.size;
        final allOptions = <String?>[null, ...InventoryCategory.all];

        final chosen = await showMenu<String?>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + size.height + 4,
            offset.dx + size.width,
            offset.dy + size.height + 4 + 44.0 * allOptions.length,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          items: allOptions.map((opt) {
            final isSelected = currentCategory == opt;
            return PopupMenuItem<String?>(
              value: opt,
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: isSelected ? 1.0 : 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _label(opt),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ],
              ),
            );
          }).toList(),
        );

        if (chosen != currentCategory) {
          onChanged(chosen);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: currentCategory == null ? 1.0 : 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label(currentCategory),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
