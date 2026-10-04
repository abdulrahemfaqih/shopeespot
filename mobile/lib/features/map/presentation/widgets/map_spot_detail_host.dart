import 'package:flutter/material.dart';

import '../../../spots/domain/spot.dart';
import '../../../spots/presentation/widgets/spot_detail_sheet.dart';

class MapSpotDetailHost extends StatelessWidget {
  const MapSpotDetailHost({
    super.key,
    required this.spot,
    required this.onExtentChanged,
    required this.onClose,
  });

  final Spot spot;
  final ValueChanged<double> onExtentChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          onExtentChanged(notification.extent);
          return false;
        },
        child: DraggableScrollableSheet(
          initialChildSize: 0.28,
          minChildSize: 0.15,
          maxChildSize: 0.75,
          snap: true,
          snapSizes: const [0.28, 0.75],
          builder: (context, scrollController) {
            return SpotDetailSheet(
              spot: spot,
              scrollController: scrollController,
              onClose: onClose,
            );
          },
        ),
      ),
    );
  }
}
