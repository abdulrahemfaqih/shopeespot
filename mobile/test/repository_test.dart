import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SpotRepository spotRepo;
  late OrderRepository orderRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 10, 4, 10, 0));
    spotRepo = SpotRepository(db: db, clock: clock);
    orderRepo = OrderRepository(db: db, spotRepository: spotRepo, clock: clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('SpotRepository and OrderRepository', () {
    test(
      'createSpot sets dirty = true, updated_at, and last_verified_at',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0);
        clock.setTime(t1);

        final spot = await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot Barokah',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        expect(spot.dirty, true);
        expect(spot.createdAt, t1);
        expect(spot.updatedAt, t1);
        expect(spot.lastVerifiedAt, t1);
        expect(spot.isDeleted, false);

        final fetched = await spotRepo.getSpotById('spot-1');
        expect(fetched, isNotNull);
        expect(fetched!.dirty, true);
        expect(fetched.lastVerifiedAt, t1);
      },
    );

    test(
      'updateSpot sets dirty = true, updated_at, and updates last_verified_at',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0);
        clock.setTime(t1);
        await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot Barokah',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        final t2 = DateTime.utc(2026, 10, 4, 11, 0);
        clock.setTime(t2);

        final updated = await spotRepo.updateSpot(
          id: 'spot-1',
          name: 'Spot Barokah Update',
          category: Category.shopeefood,
          latitude: -6.21,
          longitude: 106.81,
        );

        expect(updated.name, 'Spot Barokah Update');
        expect(updated.dirty, true);
        expect(updated.updatedAt, t2);
        expect(updated.lastVerifiedAt, t2);
      },
    );

    test(
      'softDeleteSpot sets deleted_at, dirty = true, and cascades to orders',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0);
        clock.setTime(t1);
        await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot Barokah',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        await orderRepo.recordOrder(spotId: 'spot-1', id: 'order-1');

        final t2 = DateTime.utc(2026, 10, 4, 12, 0);
        clock.setTime(t2);

        await spotRepo.softDeleteSpot('spot-1');

        final activeSpots = await spotRepo.getActiveSpots();
        expect(activeSpots, isEmpty);

        final rawSpot = await spotRepo.getSpotById('spot-1');
        expect(rawSpot, isNotNull);
        expect(rawSpot!.isDeleted, true);
        expect(rawSpot.deletedAt, t2);
        expect(rawSpot.dirty, true);

        final activeOrders = await orderRepo.getOrdersForSpot('spot-1');
        expect(activeOrders, isEmpty);
      },
    );

    test(
      'recordOrder updates spot last_verified_at and sets dirty = true',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0);
        clock.setTime(t1);
        await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot SPX Hub',
          category: Category.spx,
          latitude: -6.2,
          longitude: 106.8,
        );

        final t2 = DateTime.utc(2026, 10, 4, 14, 30);
        clock.setTime(t2);

        final order = await orderRepo.recordOrder(
          spotId: 'spot-1',
          id: 'order-1',
        );

        expect(order.dirty, true);
        expect(order.createdAt, t2);
        expect(order.updatedAt, t2);

        final spot = await spotRepo.getSpotById('spot-1');
        expect(spot, isNotNull);
        expect(spot!.lastVerifiedAt, t2);
        expect(spot.dirty, true);
      },
    );

    test(
      'countOrdersToday counts only non-deleted orders for current day',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0);
        clock.setTime(t1);
        await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot Food',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        await orderRepo.recordOrder(spotId: 'spot-1', id: 'order-1');
        await orderRepo.recordOrder(spotId: 'spot-1', id: 'order-2');

        var count = await orderRepo.countOrdersToday();
        expect(count, 2);

        // Soft delete order-1
        await orderRepo.softDeleteOrder('order-1');
        count = await orderRepo.countOrdersToday();
        expect(count, 1);
      },
    );
  });
}
