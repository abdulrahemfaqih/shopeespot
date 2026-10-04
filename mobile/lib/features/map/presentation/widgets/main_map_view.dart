import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/config/env.dart';
import '../../../spots/domain/spot.dart';
import '../../domain/clustering.dart';
import 'filter_bar.dart';
import 'gps_layer.dart';
import 'map_empty_hint.dart';
import 'map_overlay_controls.dart';
import 'map_spot_detail_host.dart';
import 'spot_markers_layer.dart';

class MainMapView extends StatelessWidget {
  const MainMapView({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.spots,
    required this.allSpots,
    required this.selectedSpot,
    required this.sheetExtent,
    required this.currentCamera,
    required this.onMapReady,
    required this.onPositionChanged,
    required this.onTapMap,
    required this.onSpotTap,
    required this.onClusterTap,
    required this.onQuickPinPressed,
    required this.onMyLocationPressed,
    required this.onNearbyListPressed,
    required this.onDetailExtentChanged,
    required this.onDetailClose,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Spot> spots;
  final List<Spot> allSpots;
  final Spot? selectedSpot;
  final double sheetExtent;
  final MapCamera? currentCamera;
  final ValueChanged<MapCamera> onMapReady;
  final void Function(MapCamera, bool) onPositionChanged;
  final VoidCallback onTapMap;
  final ValueChanged<Spot> onSpotTap;
  final ValueChanged<MapClusterItem> onClusterTap;
  final VoidCallback onQuickPinPressed;
  final VoidCallback onMyLocationPressed;
  final VoidCallback onNearbyListPressed;
  final ValueChanged<double> onDetailExtentChanged;
  final VoidCallback onDetailClose;

  static String tileUrl(Brightness brightness) {
    final style = brightness == Brightness.dark ? 'dark_all' : 'light_all';
    final keyParam = Env.cartoApiKey.isNotEmpty
        ? '?key=${Env.cartoApiKey}'
        : '';
    return 'https://a.basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}@2x.png$keyParam';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isRetina = MediaQuery.of(context).devicePixelRatio > 1.5;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSheetOpen = selectedSpot != null;
    final sheetOffset = isSheetOpen ? sheetExtent * screenHeight : 0.0;
    final hideControls = isSheetOpen && sheetExtent > 0.5;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            minZoom: 5.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => onMapReady(mapController.camera),
            onPositionChanged: onPositionChanged,
            onTap: (_, _) => onTapMap(),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl(theme.brightness),
              userAgentPackageName: 'com.example.shopeespot',
              retinaMode: isRetina,
            ),
            if (currentCamera != null)
              SpotMarkersLayer(
                spots: spots,
                camera: currentCamera!,
                selectedSpotId: selectedSpot?.id,
                onSpotTap: onSpotTap,
                onClusterTap: onClusterTap,
              ),
            const GpsLayer(),
          ],
        ),
        MapOverlayControls(
          sheetOffset: sheetOffset,
          hideControls: hideControls,
          isSheetOpen: isSheetOpen,
          onQuickPinPressed: onQuickPinPressed,
          onMyLocationPressed: onMyLocationPressed,
          onNearbyListPressed: onNearbyListPressed,
        ),
        if (allSpots.isEmpty && !isSheetOpen)
          MapEmptyHint(bottomOffset: tokens.space24 + 64.0),
        Positioned(
          top: MediaQuery.paddingOf(context).top + tokens.space8,
          left: 0,
          right: 0,
          child: const FilterBar(),
        ),
        if (selectedSpot != null)
          MapSpotDetailHost(
            spot: selectedSpot!,
            onExtentChanged: onDetailExtentChanged,
            onClose: onDetailClose,
          ),
      ],
    );
  }
}
