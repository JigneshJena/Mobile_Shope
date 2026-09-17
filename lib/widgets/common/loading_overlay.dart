import 'package:flutter/material.dart';
import 'app_progress_bar.dart';

/// Wraps any [child] widget with a semi-transparent blocking overlay and
/// a single horizontal progress bar while [isLoading] is true.
///
/// Prevents user interaction during background ops and image uploads.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.label,
  });

  final Widget child;
  final bool isLoading;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppProgressBar(height: 6, borderRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
