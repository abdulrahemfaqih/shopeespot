import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/time/day_type.dart';
import 'package:shopeespot/features/peak/domain/peak_index.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/nearby_calculator.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';

void main() {
  group('computeNearbySpots pure function', () {
    final now = DateTime(2026, 10, 5, 12, 0); // Monday 12:00 (weekday)
    // User at Monas Jakarta: -6.1754, 106.8272
    const userLat = -6.1754;
    const userLng = 106.8272;

    // Spot 1: ~350 m away
    final spotNear = Spot(
      id: 'spot-near',
      name: 'Warung Dekat',
      category: Category.shopeefood,
      latitude: -6.1780,
      longitude: 106.8285,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Spot 2: ~1.5 km away
    final spotMid = Spot(
      id: 'spot-mid',
      name: 'Resto Sedang',
      category: Category.shopeefood,
      latitude: -6.1850,
      longitude: 106.8350,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Spot 3: ~3.5 km away
    final spotFar = Spot(
      id: 'spot-far',
      name: 'Hub Jauh',
      category: Category.spx,
      latitude: -6.2050,
      longitude: 106.8400,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Spot 4: ~8.0 km away (outside 5 km)
    final spotOutside = Spot(
      id: 'spot-outside',
      name: 'Ruko Luar Radius',
      category: Category.spx,
      latitude: -6.2500,
      longitude: 106.8500,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    const peakIndex = PeakIndex(
      peakHoursByDayType: {
        DayType.weekday: {
          'spot-near': {12, 13},
        },
      },
      hourlyCountsByDayType: {
        DayType.weekday: {
          'spot-near': {12: 5},
          'spot-mid': {12: 12}, // higher order count!
          'spot-far': {12: 8},
        },
      },
    );

    final allSpots = [spotNear, spotMid, spotFar, spotOutside];

    test('filters by radius 1 km, 2 km, and 5 km correctly', () {
      // 1 km: only spotNear (~350 m)
      final r1 = computeNearbySpots(
        spots: allSpots,
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.oneKm.km,
        sortOrder: NearbySortOrder.distance,
        peakIndex: peakIndex,
        now: now,
      );
      expect(r1.length, 1);
      expect(r1.first.spot.id, 'spot-near');
      expect(r1.first.isPeakNow, true);

      // 2 km: spotNear and spotMid
      final r2 = computeNearbySpots(
        spots: allSpots,
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.twoKm.km,
        sortOrder: NearbySortOrder.distance,
        peakIndex: peakIndex,
        now: now,
      );
      expect(r2.length, 2);
      expect(r2.map((i) => i.spot.id).toList(), ['spot-near', 'spot-mid']);

      // 5 km: spotNear, spotMid, spotFar (spotOutside excluded)
      final r5 = computeNearbySpots(
        spots: allSpots,
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.fiveKm.km,
        sortOrder: NearbySortOrder.distance,
        peakIndex: peakIndex,
        now: now,
      );
      expect(r5.length, 3);
      expect(r5.any((i) => i.spot.id == 'spot-outside'), false);
    });

    test('sorts by distance ascending', () {
      final items = computeNearbySpots(
        spots: allSpots,
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.fiveKm.km,
        sortOrder: NearbySortOrder.distance,
        peakIndex: peakIndex,
        now: now,
      );

      expect(items.length, 3);
      expect(items[0].spot.id, 'spot-near');
      expect(items[1].spot.id, 'spot-mid');
      expect(items[2].spot.id, 'spot-far');
      expect(items[0].distanceKm < items[1].distanceKm, true);
      expect(items[1].distanceKm < items[2].distanceKm, true);
    });

    test('sorts by order count descending with distance tie-breaker', () {
      final items = computeNearbySpots(
        spots: allSpots,
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.fiveKm.km,
        sortOrder: NearbySortOrder.orderCount,
        peakIndex: peakIndex,
        now: now,
      );

      expect(items.length, 3);
      // spot-mid has 12 orders
      expect(items[0].spot.id, 'spot-mid');
      expect(items[0].orderCountThisHour, 12);

      // spot-far has 8 orders
      expect(items[1].spot.id, 'spot-far');
      expect(items[1].orderCountThisHour, 8);

      // spot-near has 5 orders
      expect(items[2].spot.id, 'spot-near');
      expect(items[2].orderCountThisHour, 5);
    });

    test('tie-breaker in order count uses distance', () {
      // Create two spots with identical order count of 10
      final spotA = Spot(
        id: 'spot-a',
        name: 'Spot A Jauh',
        category: Category.shopeefood,
        latitude: -6.1850,
        longitude: 106.8350,
        lastVerifiedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final spotB = Spot(
        id: 'spot-b',
        name: 'Spot B Dekat',
        category: Category.shopeefood,
        latitude: -6.1770,
        longitude: 106.8280,
        lastVerifiedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      const tiePeakIndex = PeakIndex(
        hourlyCountsByDayType: {
          DayType.weekday: {
            'spot-a': {12: 10},
            'spot-b': {12: 10},
          },
        },
      );

      final items = computeNearbySpots(
        spots: [spotA, spotB],
        userLat: userLat,
        userLng: userLng,
        radiusKm: 5.0,
        sortOrder: NearbySortOrder.orderCount,
        peakIndex: tiePeakIndex,
        now: now,
      );

      expect(items.length, 2);
      // Both have 10 orders, spotB is closer so it comes first
      expect(items[0].spot.id, 'spot-b');
      expect(items[1].spot.id, 'spot-a');
    });

    test('returns empty list when no spots match radius', () {
      final items = computeNearbySpots(
        spots: [spotOutside],
        userLat: userLat,
        userLng: userLng,
        radiusKm: NearbyRadius.oneKm.km,
        sortOrder: NearbySortOrder.distance,
        peakIndex: peakIndex,
        now: now,
      );

      expect(items.isEmpty, true);
    });
  });
}
