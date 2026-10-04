import 'dart:math';
import '../../spots/domain/spot.dart';

class MapClusterItem {
  const MapClusterItem({
    required this.isCluster,
    this.spot,
    required this.count,
    required this.latitude,
    required this.longitude,
    required this.spotIds,
  });

  factory MapClusterItem.single(Spot spot) {
    return MapClusterItem(
      isCluster: false,
      spot: spot,
      count: 1,
      latitude: spot.latitude,
      longitude: spot.longitude,
      spotIds: [spot.id],
    );
  }

  factory MapClusterItem.cluster({
    required double latitude,
    required double longitude,
    required List<String> spotIds,
  }) {
    return MapClusterItem(
      isCluster: true,
      spot: null,
      count: spotIds.length,
      latitude: latitude,
      longitude: longitude,
      spotIds: spotIds,
    );
  }

  final bool isCluster;
  final Spot? spot;
  final int count;
  final double latitude;
  final double longitude;
  final List<String> spotIds;
}

List<MapClusterItem> computeMapClusters({
  required List<Spot> spots,
  required double minLat,
  required double maxLat,
  required double minLng,
  required double maxLng,
  required double zoom,
  double clusterDistancePixels = 48.0,
}) {
  // 1. Filter spots by bounding box with viewport padding
  final visibleSpots = <Spot>[];
  for (final s in spots) {
    if (s.isDeleted) continue;
    if (s.latitude >= minLat &&
        s.latitude <= maxLat &&
        s.longitude >= minLng &&
        s.longitude <= maxLng) {
      visibleSpots.add(s);
    }
  }

  // 2. If zoom >= 15, no clustering is performed
  if (zoom >= 15.0) {
    return visibleSpots.map(MapClusterItem.single).toList();
  }

  // 3. Zoom < 15: Grid-based clustering
  final degPerPixel = 360.0 / (256.0 * pow(2.0, zoom));
  final cellSize = clusterDistancePixels * degPerPixel;
  if (cellSize <= 0) {
    return visibleSpots.map(MapClusterItem.single).toList();
  }

  final grid = <int, Map<int, List<Spot>>>{};

  for (final s in visibleSpots) {
    final cellX = (s.longitude / cellSize).floor();
    final cellY = (s.latitude / cellSize).floor();

    grid.putIfAbsent(cellX, () => <int, List<Spot>>{});
    grid[cellX]!.putIfAbsent(cellY, () => <Spot>[]).add(s);
  }

  final results = <MapClusterItem>[];

  for (final col in grid.values) {
    for (final cellSpots in col.values) {
      if (cellSpots.length == 1) {
        results.add(MapClusterItem.single(cellSpots.first));
      } else {
        var sumLat = 0.0;
        var sumLng = 0.0;
        final ids = <String>[];

        for (final s in cellSpots) {
          sumLat += s.latitude;
          sumLng += s.longitude;
          ids.add(s.id);
        }

        results.add(
          MapClusterItem.cluster(
            latitude: sumLat / cellSpots.length,
            longitude: sumLng / cellSpots.length,
            spotIds: ids,
          ),
        );
      }
    }
  }

  return results;
}
