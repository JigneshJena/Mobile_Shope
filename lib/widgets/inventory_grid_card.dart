import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/inventory_model.dart';
import 'common/app_progress_bar.dart';
import 'common/glass_card.dart';

/// A modern, professional grid card for Inventory spare parts items.
class InventoryGridCard extends StatelessWidget {
  const InventoryGridCard({
    super.key,
    required this.item,
    this.onMarkReturned,
    this.onTap,
  });

  final InventoryModel item;
  final VoidCallback? onMarkReturned;
  final VoidCallback? onTap;

  IconData _categoryIcon() {
    switch (item.category) {
      case InventoryCategory.screen:
        return Icons.smartphone_outlined;
      case InventoryCategory.battery:
        return Icons.battery_charging_full_rounded;
      case InventoryCategory.charger:
        return Icons.power_rounded;
      case InventoryCategory.speaker:
        return Icons.volume_up_rounded;
      case InventoryCategory.camera:
        return Icons.camera_alt_rounded;
      case InventoryCategory.motherboard:
        return Icons.developer_board_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  Color _categoryColor() {
    switch (item.category) {
      case InventoryCategory.screen:
        return AppColors.statusInProgress;
      case InventoryCategory.battery:
        return AppColors.creditGreen;
      case InventoryCategory.charger:
        return AppColors.statusPending;
      case InventoryCategory.speaker:
        return AppColors.secondary;
      case InventoryCategory.camera:
        return AppColors.statusRepaired;
      case InventoryCategory.motherboard:
        return AppColors.debitRed;
      default:
        return AppColors.subtleText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLowStock = !item.isReturned && item.quantity <= 2;
    final catColor = _categoryColor();
    final catIcon = _categoryIcon();
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 18,
      borderColor: isLowStock
          ? AppColors.warning.withValues(alpha: 0.5)
          : null,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image / Category Graphic Banner
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: AppProgressBar(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(catIcon, size: 32, color: catColor),
                          ),
                        ),
                      )
                    : Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            catIcon,
                            size: 32,
                            color: catColor,
                          ),
                        ),
                      ),
              ),

              // Card Info Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Name
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),


                          // Quantity & Low Stock Indicator
                          Row(
                            children: [
                              Text(
                                'Qty: ${item.quantity}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isLowStock
                                      ? AppColors.warning
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (isLowStock) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'Low',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Unit price
                          Text(
                            '${Formatters.currency(item.purchasePricePerUnit)} / unit',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Total Value & Action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total:',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                Formatters.currency(item.totalValue),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          if (!item.isReturned && onMarkReturned != null) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 30,
                              child: OutlinedButton(
                                onPressed: onMarkReturned,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.debitRed,
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(
                                    color: AppColors.debitRed.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Return',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Returned Banner Ribbon
          if (item.isReturned)
            Positioned(
              top: 10,
              right: -24,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: AppColors.debitRed,
                  child: const Text(
                    'RETURNED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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
