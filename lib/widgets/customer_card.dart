import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../core/utils/formatters.dart';
import '../core/theme/app_theme.dart';
import 'common/glass_card.dart';
import 'status_badge.dart';

/// A modern glassmorphic card representing a customer repair job.
class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer, this.onTap});

  final CustomerModel customer;
  final VoidCallback? onTap;

  Color _statusColor() {
    switch (customer.status) {
      case 'pending':     return AppColors.statusPending;
      case 'in_progress': return AppColors.statusInProgress;
      case 'repaired':    return AppColors.statusRepaired;
      case 'delivered':   return AppColors.statusDelivered;
      default:            return AppColors.disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor();
    final remaining = customer.remainingBalance;

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.zero,
      borderColor: statusColor.withValues(alpha: 0.25),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color status pill strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Card body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Name + Status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: customer.status),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Row 2: Device Model • Phone
                    Text(
                      customer.phone.isEmpty || customer.phone.toLowerCase() == 'add later'
                          ? '${customer.mobileModel}  •  (No Phone / Add Later)'
                          : '${customer.mobileModel}  •  ${customer.phone}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Row 3: Financials (Advance & Due)
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Adv: ${Formatters.currency(customer.advanceAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (customer.totalPrice != null) ...[
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${Formatters.currency(remaining)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: remaining > 0
                                  ? AppColors.debitRed
                                  : AppColors.creditGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          Text(
                            'Price: Pending',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.statusPending,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row 4: Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.date(customer.dateReceived),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Trailing arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}