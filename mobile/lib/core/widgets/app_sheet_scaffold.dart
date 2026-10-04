import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showDragHandle = true,
    this.onClose,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showDragHandle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusLg),
        ),
        border: Border(
          top: BorderSide(color: tokens.border, width: tokens.borderWidth),
          left: BorderSide(color: tokens.border, width: tokens.borderWidth),
          right: BorderSide(color: tokens.border, width: tokens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle) ...[
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: tokens.space8,
                    bottom: tokens.space4,
                  ),
                  width: 32.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
            ],
            if (title != null || onClose != null || actions != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space16,
                  vertical: tokens.space8,
                ),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (actions != null) ...actions!,
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        iconSize: 20.0,
                        color: tokens.textSecondary,
                        constraints: BoxConstraints(
                          minWidth: tokens.minTouchTarget,
                          minHeight: tokens.minTouchTarget,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(
                color: tokens.border,
                thickness: tokens.borderWidth,
                height: tokens.borderWidth,
              ),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
