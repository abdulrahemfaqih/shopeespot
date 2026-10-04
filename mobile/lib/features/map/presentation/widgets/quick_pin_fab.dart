import 'package:flutter/material.dart';
import '../../../../app/theme/tokens.dart';

class QuickPinFab extends StatelessWidget {
  const QuickPinFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: 'Tambah spot',
      child: Material(
        color: tokens.actionFill,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          child: SizedBox(
            width: 56.0,
            height: 56.0,
            child: Center(
              child: Icon(Icons.add, size: 28.0, color: tokens.actionOnFill),
            ),
          ),
        ),
      ),
    );
  }
}
