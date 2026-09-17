import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// A sleek modern pill badge showing repair status with an indicator dot.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  Color _color(bool isDark) {
    switch (status) {
      case RepairStatus.pending:
        return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
      case RepairStatus.inProgress:
        return isDark ? Colors.blue.shade300 : Colors.blue.shade800;
      case RepairStatus.repaired:
        return isDark ? Colors.teal.shade300 : Colors.teal.shade800;
      case RepairStatus.delivered:
        return isDark ? Colors.green.shade300 : Colors.green.shade800;
      default:
        return isDark ? Colors.grey.shade300 : Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _color(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.45 : 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            RepairStatus.label(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}