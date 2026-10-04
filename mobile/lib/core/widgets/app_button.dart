import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

enum AppButtonVariant { primary, outline, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isFullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.outline;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final childWidget = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          SizedBox(width: tokens.space8),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.actionFill,
            foregroundColor: tokens.actionOnFill,
            elevation: 0,
            minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
          ),
          child: childWidget,
        );
        break;

      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.textPrimary,
            elevation: 0,
            side: BorderSide(color: tokens.border, width: tokens.borderWidth),
            minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
          ),
          child: childWidget,
        );
        break;

      case AppButtonVariant.text:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: tokens.textPrimary,
            elevation: 0,
            minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
          ),
          child: childWidget,
        );
        break;

      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.danger,
            foregroundColor: tokens.actionOnFill,
            elevation: 0,
            minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
          ),
          child: childWidget,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
