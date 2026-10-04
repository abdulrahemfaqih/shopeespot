import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase and DAOs', () {
    test(
      'insert and query spot with peak_hours converter and soft delete',
      () async {
        final now = DateTime.utc(2026, 10, 4, 10, 0);
        const peakRange = PeakRange(
          days: [1, 2, 3, 4, 5],
          start: 660,
          end: 840,
        );

        final spotCompanion = SpotsCompanion.insert(
          id: 'spot-123',
          name: 'Warung Makan Barokah',
          category: 'shopeefood',
          latitude: -6.2088,
          longitude: 106.8456,
          notes: const Value('Dekat lampu merah'),
          peakHours: const Value([peakRange]),
          createdAt: now,
          updatedAt: now,
          dirty: const Value(true),
        );

        await db.spotDao.insertSpot(spotCompanion);

        final spots = await db.spotDao.getActiveSpots();
        expect(spots.length, 1);
        final spot = spots.first;
        expect(spot.id, 'spot-123');
        expect(spot.name, 'Warung Makan Barokah');
        expect(spot.category, 'shopeefood');
        expect(spot.latitude, -6.2088);
        expect(spot.longitude, 106.8456);
        expect(spot.notes, 'Dekat lampu merah');
        expect(spot.peakHours.length, 1);
        expect(spot.peakHours.first.start, 660);
        expect(spot.peakHours.first.end, 840);
        expect(spot.peakHours.first.days, [1, 2, 3, 4, 5]);
        expect(spot.dirty, true);

        // Test soft delete
        final deleteTime = DateTime.utc(2026, 10, 4, 12, 0);
        await db.spotDao.softDeleteSpot('spot-123', deleteTime);

        final activeAfterDelete = await db.spotDao.getActiveSpots();
        expect(activeAfterDelete, isEmpty);

        final rawSpot = await db.spotDao.getSpotById('spot-123');
        expect(rawSpot, isNotNull);
        expect(rawSpot!.deletedAt!.toUtc(), deleteTime);
        expect(rawSpot.dirty, true);
      },
    );

    test('insert and query order, count today, and peak aggregation', () async {
      final now = DateTime.utc(2026, 10, 4, 11, 30);
      final startOfDay = DateTime.utc(2026, 10, 4, 0, 0);

      final orderCompanion = OrdersCompanion.insert(
        id: 'order-001',
        spotId: 'spot-123',
        orderedAt: now,
        localDow: 7, // Sunday
        localHour: 11,
        createdAt: now,
        updatedAt: now,
        dirty: const Value(true),
      );

      await db.orderDao.insertOrder(orderCompanion);

      final orders = await db.orderDao.getOrdersForSpot('spot-123');
      expect(orders.length, 1);
      expect(orders.first.id, 'order-001');
      expect(orders.first.localHour, 11);

      final countToday = await db.orderDao.countOrdersToday(startOfDay);
      expect(countToday, 1);

      final spotCountToday = await db.orderDao.countOrdersForSpotToday(
        'spot-123',
        startOfDay,
      );
      expect(spotCountToday, 1);

      // Test peak aggregation
      final since = DateTime.utc(2026, 7, 1);
      final agg = await db.orderDao.getPeakOrderAggregation(
        since: since,
        dowMin: 6,
        dowMax: 7,
      );
      expect(agg.length, 1);
      expect(agg.first.spotId, 'spot-123');
      expect(agg.first.localHour, 11);
      expect(agg.first.count, 1);
    });

    test('sync metadata key-value storage', () async {
      await db.setMeta('cursor_spots', '100');
      final val = await db.getMeta('cursor_spots');
      expect(val, '100');

      await db.setMeta('cursor_spots', '200');
      final updatedVal = await db.getMeta('cursor_spots');
      expect(updatedVal, '200');
    });
  });
}
