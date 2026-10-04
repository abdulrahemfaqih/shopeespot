import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/widgets/category_marker.dart';
import '../../../spots/domain/spot.dart';
import '../../domain/clustering.dart';

class SpotMarkersLayer extends StatelessWidget {
  const SpotMarkersLayer({
    super.key,
    required this.spots,
    required this.camera,
    this.selectedSpotId,
    this.onSpotTap,
    this.onClusterTap,
  });

  final List<Spot> spots;
  final MapCamera camera;
  final String? selectedSpotId;
  final ValueChanged<Spot>? onSpotTap;
  final ValueChanged<MapClusterItem>? onClusterTap;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final bounds = camera.visibleBounds;
    final latPadding = (bounds.north - bounds.south).abs() * 0.2;
    final lngPadding = (bounds.east - bounds.west).abs() * 0.2;

    final minLat = bounds.south - latPadding;
    final maxLat = bounds.north + latPadding;
    final minLng = bounds.west - lngPadding;
    final maxLng = bounds.east + lngPadding;

    final clusterItems = computeMapClusters(
      spots: spots,
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      zoom: camera.zoom,
    );

    final showLabel = camera.zoom >= 15.0;

    final markers = clusterItems.map((item) {
      if (item.isCluster) {
        return Marker(
          point: LatLng(item.latitude, item.longitude),
          width: 36.0,
          height: 36.0,
          alignment: Alignment.center,
          child: ClusterMarkerWidget(
            count: item.count,
            onTap: () => onClusterTap?.call(item),
          ),
        );
      }

      final spot = item.spot!;
      final isSelected = spot.id == selectedSpotId;
      final markerHeight = isSelected ? 44.0 : 36.0;
      final totalHeight = showLabel ? markerHeight + 48.0 : markerHeight + 6.0;

      return Marker(
        point: LatLng(spot.latitude, spot.longitude),
        width: showLabel ? 140.0 : (isSelected ? 44.0 : 36.0),
        height: totalHeight,
        alignment: Alignment.topCenter,
        child: CategoryMarker(
          category: spot.category,
          name: spot.name,
          isSelected: isSelected,
          showLabel: showLabel,
          onTap: () => onSpotTap?.call(spot),
        ),
      );
    }).toList();

    return RepaintBoundary(child: MarkerLayer(markers: markers));
  }
}
