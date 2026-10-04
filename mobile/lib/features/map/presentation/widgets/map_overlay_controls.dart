import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import 'map_controls.dart';
import 'quick_pin_fab.dart';

class MapOverlayControls extends StatelessWidget {
  const MapOverlayControls({
    super.key,
    required this.sheetOffset,
    required this.hideControls,
    required this.isSheetOpen,
    required this.onQuickPinPressed,
    required this.onMyLocationPressed,
    required this.onNearbyListPressed,
  });

  final double sheetOffset;
  final bool hideControls;
  final bool isSheetOpen;
  final VoidCallback onQuickPinPressed;
  final VoidCallback onMyLocationPressed;
  final VoidCallback onNearbyListPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Stack(
      children: [
        if (!hideControls) ...[
          // Quick Pin FAB (floating right bottom)
          Positioned(
            right: tokens.space16,
            bottom: tokens.space24 + sheetOffset,
            child: QuickPinFab(onPressed: onQuickPinPressed),
          ),
          // My Location Button (floating right, above Quick Pin FAB)
          Positioned(
            right: tokens.space16,
            bottom: tokens.space24 + 56.0 + tokens.space12 + sheetOffset,
            child: MyLocationButton(onPressed: onMyLocationPressed),
          ),
          // Nearby List Button (floating left bottom)
          Positioned(
            left: tokens.space16,
            bottom: tokens.space24 + sheetOffset,
            child: NearbyListButton(onPressed: onNearbyListPressed),
          ),
        ],
        // CARTO and OSM Attribution (always visible bottom left)
        Positioned(
          left: 0,
          bottom: (isSheetOpen && !hideControls) ? 8.0 + sheetOffset : 8.0,
          child: const MapAttribution(),
        ),
      ],
    );
  }
}
