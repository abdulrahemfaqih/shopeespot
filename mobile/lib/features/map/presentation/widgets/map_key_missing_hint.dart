import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';

class MapKeyMissingHint extends StatelessWidget {
  const MapKeyMissingHint({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + tokens.space8 + 48.0,
      left: tokens.space16,
      right: tokens.space16,
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
            'Kunci peta belum diisi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
