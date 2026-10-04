import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final bgColor = isSelected ? tokens.actionFill : tokens.surface;
    final fgColor = isSelected ? tokens.actionOnFill : tokens.textPrimary;
    final borderColor = isSelected ? tokens.actionFill : tokens.border;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: tokens.minTouchTarget,
            minHeight: tokens.minTouchTarget,
          ),
          child: Center(
            child: Container(
              height: 40.0,
              padding: EdgeInsets.symmetric(horizontal: tokens.space12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: borderColor,
                  width: tokens.borderWidth,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18.0, color: fgColor),
                    SizedBox(width: tokens.space4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: fgColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
