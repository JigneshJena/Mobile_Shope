import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import 'common/glass_card.dart';

/// A modern glassmorphic card representing an inventory spare part item.
class InventoryCard extends StatelessWidget {
  const InventoryCard({
    super.key,
    required this.item,
    this.onMarkReturned,
    this.onTap,
  });

  final InventoryModel item;
  final VoidCallback? onMarkReturned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLowStock = !item.isReturned && item.quantity <= 2;

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.zero,
      borderColor: isLowStock
          ? Colors.orange.withValues(alpha: 0.4)
          : null,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + Category Chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CategoryChip(category: item.category),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: Quantity + Low stock badge
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: isLowStock
                          ? Colors.orange.shade800
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Qty: ${item.quantity}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isLowStock
                            ? Colors.orange.shade800
                            : theme.colorScheme.onSurface,
                        fontWeight: isLowStock
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Low Stock',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Row 3: Unit price & Total
                Row(
                  children: [
                    Icon(Icons.sell_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${Formatters.currency(item.purchasePricePerUnit)} / unit',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.calculate_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${Formatters.currency(item.totalValue)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 4: Supplier & Date added
                Row(
                  children: [
                    if (item.supplier != null && item.supplier!.isNotEmpty) ...[
                      Icon(Icons.store_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.supplier!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.calendar_today_outlined,
                        size: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.date(item.dateAdded),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Mark as Returned action (Only allowed if stock is still remaining)
                if (!item.isReturned && item.quantity > 0 && onMarkReturned != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: onMarkReturned,
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text(
                        'Mark as Returned',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Returned badge
          if (item.isReturned)
            Positioned(
              top: 10,
              right: -24,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.red.shade700,
                  child: const Text(
                    'RETURNED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final String category;

  Color _color() {
    switch (category) {
      case InventoryCategory.screen:      return Colors.blue;
      case InventoryCategory.battery:     return Colors.green;
      case InventoryCategory.charger:     return Colors.orange;
      case InventoryCategory.speaker:     return Colors.purple;
      case InventoryCategory.camera:      return Colors.teal;
      case InventoryCategory.motherboard: return Colors.red;
      default:                            return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        InventoryCategory.label(category),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}