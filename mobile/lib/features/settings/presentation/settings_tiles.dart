import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64.0),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: tokens.space8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class OptionTile<T> extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onSelect,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onSelect(value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: tokens.space4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 20.0, color: tokens.textPrimary),
          ],
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20.0, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }
}
