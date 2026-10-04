import '../../../core/geo/haversine.dart';
import '../../../core/time/day_type.dart';
import '../../peak/domain/peak_index.dart';
import 'spot.dart';

enum NearbyRadius {
  oneKm(1.0, '1 km'),
  twoKm(2.0, '2 km'),
  fiveKm(5.0, '5 km');

  const NearbyRadius(this.km, this.label);
  final double km;
  final String label;
}

enum NearbySortOrder {
  distance('Urut: Jarak'),
  orderCount('Urut: Order jam ini');

  const NearbySortOrder(this.label);
  final String label;
}

class NearbySpotItem {
  const NearbySpotItem({
    required this.spot,
    required this.distanceKm,
    required this.isPeakNow,
    required this.orderCountThisHour,
  });

  final Spot spot;
  final double distanceKm;
  final bool isPeakNow;
  final int orderCountThisHour;
}

/// Pure function that filters [spots] within [radiusKm] from ([userLat], [userLng])
/// and sorts them by [sortOrder].
List<NearbySpotItem> computeNearbySpots({
  required List<Spot> spots,
  required double userLat,
  required double userLng,
  required double radiusKm,
  required NearbySortOrder sortOrder,
  required PeakIndex peakIndex,
  required DateTime now,
}) {
  final dayType = DayType.fromDateTime(now.toLocal());
  final currentHour = now.toLocal().hour;

  final items = <NearbySpotItem>[];

  for (final spot in spots) {
    final distKm = haversine(userLat, userLng, spot.latitude, spot.longitude);

    if (distKm <= radiusKm) {
      final isPeakNow = peakIndex.isPeakAt(spot, now);
      final count = peakIndex.orderCountAt(
        spotId: spot.id,
        dayType: dayType,
        hour: currentHour,
      );

      items.add(
        NearbySpotItem(
          spot: spot,
          distanceKm: distKm,
          isPeakNow: isPeakNow,
          orderCountThisHour: count,
        ),
      );
    }
  }

  items.sort((a, b) {
    if (sortOrder == NearbySortOrder.distance) {
      final cmp = a.distanceKm.compareTo(b.distanceKm);
      if (cmp != 0) return cmp;
      return a.spot.name.compareTo(b.spot.name);
    } else {
      // Order count descending
      final cmp = b.orderCountThisHour.compareTo(a.orderCountThisHour);
      if (cmp != 0) return cmp;
      // Tie breaker: distance ascending
      final distCmp = a.distanceKm.compareTo(b.distanceKm);
      if (distCmp != 0) return distCmp;
      return a.spot.name.compareTo(b.spot.name);
    }
  });

  return items;
}
