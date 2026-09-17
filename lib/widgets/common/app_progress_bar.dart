import 'package:flutter/material.dart';

/// A sleek horizontal linear progress bar styled with the app's theme colors.
/// Used app-wide for consistent loading states, image uploads, and data fetching.
class AppProgressBar extends StatefulWidget {
  const AppProgressBar({
    super.key,
    this.value,
    this.height = 4.0,
    this.borderRadius = 4.0,
    this.padding,
    this.color,
  });

  /// Optional value between 0.0 and 1.0 for deterministic progress.
  /// If null, displays a smooth indeterminate animated gradient line.
  final double? value;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  State<AppProgressBar> createState() => _AppProgressBarState();
}

class _AppProgressBarState extends State<AppProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        height: widget.height,
        color: primaryColor.withValues(alpha: 0.18),
        child: widget.value != null
            ? FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.value!.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                  ),
                ),
              )
            : AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: Offset(_animController.value * 2 - 1, 0),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.1),
                            primaryColor,
                            secondaryColor,
                            primaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );

    if (widget.padding != null) {
      return Padding(padding: widget.padding!, child: bar);
    }
    return bar;
  }
}
