import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import 'common/app_progress_bar.dart';
import 'common/glass_card.dart';
import 'status_badge.dart';

/// A modern, professional grid card for Customer repair records.
class CustomerGridCard extends StatelessWidget {
  const CustomerGridCard({
    super.key,
    required this.customer,
    this.onTap,
  });

  final CustomerModel customer;
  final VoidCallback? onTap;

  Color _statusColor() {
    switch (customer.status) {
      case 'pending':
        return AppColors.statusPending;
      case 'in_progress':
        return AppColors.statusInProgress;
      case 'repaired':
        return AppColors.statusRepaired;
      case 'delivered':
        return AppColors.statusDelivered;
      default:
        return AppColors.disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor();
    final hasPhoto = customer.imageUrls.isNotEmpty;
    final firstPhoto = hasPhoto ? customer.imageUrls.first : null;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 18,
      borderColor: statusColor.withValues(alpha: isDark ? 0.35 : 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image / Avatar Header
          Stack(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: firstPhoto != null
                    ? CachedNetworkImage(
                        imageUrl: firstPhoto,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: AppProgressBar(),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildAvatarFallback(theme, isDark),
                      )
                    : _buildAvatarFallback(theme, isDark),
              ),
              // Top Right Status Badge Overlay
              Positioned(
                top: 8,
                right: 8,
                child: StatusBadge(status: customer.status),
              ),
            ],
          ),

          // Card Info Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Name
                      Text(
                        customer.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Device Model
                      Row(
                        children: [
                          Icon(
                            Icons.smartphone_outlined,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.mobileModel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Phone Number
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.phone.isEmpty || customer.phone.toLowerCase() == 'add later'
                                  ? 'No Phone (Add Later)'
                                  : customer.phone,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: customer.phone.isEmpty || customer.phone.toLowerCase() == 'add later'
                                    ? AppColors.secondary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Financial Due / Advance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Adv: ${Formatters.currency(customer.advanceAmount)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        customer.totalPrice != null
                            ? 'Due: ${Formatters.currency(customer.remainingBalance)}'
                            : 'Pending',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: customer.remainingBalance > 0
                              ? AppColors.debitRed
                              : AppColors.creditGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(ThemeData theme, bool isDark) {
    final initials = customer.name.trim().isNotEmpty
        ? customer.name.trim()[0].toUpperCase()
        : '?';

    return Center(
      child: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

