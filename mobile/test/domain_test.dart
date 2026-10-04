import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/features/orders/domain/order_log.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';

void main() {
  group('Domain models serialization and immutability', () {
    test('Category parses correctly and preserves values', () {
      expect(Category.fromString('shopeefood'), Category.shopeefood);
      expect(Category.fromString('SHOPEEFOOD'), Category.shopeefood);
      expect(Category.fromString('spx'), Category.spx);
      expect(Category.fromString('SPX'), Category.spx);
      expect(Category.fromString('unknown'), Category.shopeefood);

      expect(Category.shopeefood.value, 'shopeefood');
      expect(Category.shopeefood.label, 'ShopeeFood');
      expect(Category.spx.value, 'spx');
      expect(Category.spx.label, 'SPX');
    });

    test('PeakRange round-trip serialization and methods', () {
      const range = PeakRange(days: [1, 2, 3, 4, 5], start: 660, end: 840);

      final json = range.toJson();
      final fromJson = PeakRange.fromJson(json);

      expect(fromJson, range);
      expect(fromJson.days, [1, 2, 3, 4, 5]);
      expect(fromJson.start, 660);
      expect(fromJson.end, 840);
      expect(fromJson.crossesMidnight, false);

      const overnight = PeakRange(days: [6, 7], start: 1320, end: 120);
      expect(overnight.crossesMidnight, true);

      final updated = range.copyWith(start: 700);
      expect(updated.start, 700);
      expect(updated.end, 840);
      expect(updated != range, true);
    });

    test('Spot round-trip sync serialization', () {
      final now = DateTime.utc(2026, 10, 4, 8, 30);
      final lastVerified = DateTime.utc(2026, 10, 4, 9, 0);
      const peak = PeakRange(days: [1, 2, 3], start: 600, end: 720);

      final spot = Spot(
        id: 'spot-uuid-1',
        name: 'Depot Nasi Kuning Ibu Hj',
        category: Category.shopeefood,
        latitude: -7.123456,
        longitude: 112.654321,
        notes: 'Masuk gang kecil sebelah alfamart',
        peakHours: const [peak],
        lastVerifiedAt: lastVerified,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        dirty: false,
      );

      final json = spot.toJson();
      expect(json['id'], 'spot-uuid-1');
      expect(json['name'], 'Depot Nasi Kuning Ibu Hj');
      expect(json['category'], 'shopeefood');
      expect(json['latitude'], -7.123456);
      expect(json['longitude'], 112.654321);
      expect(json['notes'], 'Masuk gang kecil sebelah alfamart');
      expect(json['peak_hours'], isA<List>());
      expect(json['last_verified_at'], lastVerified.toIso8601String());
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
      expect(json['deleted_at'], isNull);

      final restored = Spot.fromJson(json);
      expect(restored, spot);

      // Test with deleted_at
      final deletedTime = DateTime.utc(2026, 10, 4, 10, 0);
      final deletedSpot = spot.copyWith(deletedAt: deletedTime, dirty: true);
      expect(deletedSpot.isDeleted, true);
      expect(deletedSpot.dirty, true);

      final deletedJson = deletedSpot.toJson();
      final restoredDeleted = Spot.fromJson(deletedJson, dirty: true);
      expect(restoredDeleted, deletedSpot);
    });

    test('OrderLog round-trip sync serialization', () {
      final orderedAt = DateTime.utc(2026, 10, 4, 12, 15);
      final now = DateTime.utc(2026, 10, 4, 12, 16);

      final order = OrderLog(
        id: 'order-uuid-99',
        spotId: 'spot-uuid-1',
        orderedAt: orderedAt,
        localDow: 7,
        localHour: 19,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        dirty: false,
      );

      final json = order.toJson();
      expect(json['id'], 'order-uuid-99');
      expect(json['spot_id'], 'spot-uuid-1');
      expect(json['ordered_at'], orderedAt.toIso8601String());
      expect(json['local_dow'], 7);
      expect(json['local_hour'], 19);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
      expect(json['deleted_at'], isNull);

      final restored = OrderLog.fromJson(json);
      expect(restored, order);

      // Test soft deleted order
      final deletedTime = DateTime.utc(2026, 10, 4, 12, 20);
      final deletedOrder = order.copyWith(deletedAt: deletedTime, dirty: true);
      expect(deletedOrder.isDeleted, true);
      expect(deletedOrder.dirty, true);

      final deletedJson = deletedOrder.toJson();
      final restoredDeleted = OrderLog.fromJson(deletedJson, dirty: true);
      expect(restoredDeleted, deletedOrder);
    });
  });
}
