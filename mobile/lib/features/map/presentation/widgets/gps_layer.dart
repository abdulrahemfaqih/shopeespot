import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/location/location_service.dart';

class GpsLayer extends ConsumerWidget {
  const GpsLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(userLocationProvider);
    if (locationState is! LocationAvailable) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final loc = locationState.location;
    final point = LatLng(loc.latitude, loc.longitude);

    return RepaintBoundary(
      child: Stack(
        children: [
          // Accuracy circle (grey transparent 12%, no border)
          CircleLayer(
            circles: [
              CircleMarker(
                point: point,
                radius: loc.accuracy,
                useRadiusInMeter: true,
                color: tokens.textPrimary.withValues(alpha: 0.12),
                borderStrokeWidth: 0.0,
              ),
            ],
          ),
          // Driver position dot (16 dp textPrimary with 3 dp surface border)
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 22.0,
                height: 22.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.textPrimary,
                    border: Border.all(color: tokens.surface, width: 3.0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
