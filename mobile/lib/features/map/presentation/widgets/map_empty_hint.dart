import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

class MapEmptyHint extends StatelessWidget {
  const MapEmptyHint({super.key, required this.bottomOffset});

  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Positioned(
      left: tokens.space16,
      right: tokens.space16,
      bottom: bottomOffset,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space12,
            vertical: tokens.space8,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: tokens.border, width: tokens.borderWidth),
          ),
          child: Text(
            'Belum ada spot. Tap + untuk menandai spot pertama.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
