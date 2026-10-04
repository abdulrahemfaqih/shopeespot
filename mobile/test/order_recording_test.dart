import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/orders/presentation/orders_providers.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/spots/presentation/widgets/spot_detail_sheet.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SpotRepository spotRepo;
  late OrderRepository orderRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 10, 4, 10, 30)); // Sunday 10:30 UTC
    spotRepo = SpotRepository(db: db, clock: clock);
    orderRepo = OrderRepository(db: db, spotRepository: spotRepo, clock: clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('T-16 Order Recording', () {
    test(
      'recordOrder calculates localDow, localHour, sets dirty and updates last_verified_at',
      () async {
        final spot = await spotRepo.createSpot(
          name: 'Nasi Bebek Sinjay',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        final initialSpot = await spotRepo.getSpotById(spot.id);
        expect(initialSpot, isNotNull);

        // Advance clock by 2 hours
        clock.setTime(DateTime.utc(2026, 10, 4, 12, 45));

        final order = await orderRepo.recordOrder(spotId: spot.id);

        expect(order.spotId, spot.id);
        final local = order.orderedAt.toLocal();
        expect(order.localDow, local.weekday);
        expect(order.localHour, local.hour);
        expect(order.dirty, true);
        expect(order.deletedAt, isNull);

        // Verify spot's last_verified_at was updated to the order time
        final updatedSpot = await spotRepo.getSpotById(spot.id);
        expect(updatedSpot!.lastVerifiedAt, DateTime.utc(2026, 10, 4, 12, 45));

        // Count today is 1
        final count = await orderRepo.countOrdersForSpotToday(spot.id);
        expect(count, 1);
      },
    );

    testWidgets(
      'tapping Dapat order di sini records order, shows SnackBar, updates count, and Batal soft-deletes order',
      (tester) async {
        final spot = await spotRepo.createSpot(
          name: 'Martabak Orins',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              spotRepositoryProvider.overrideWithValue(spotRepo),
              orderRepositoryProvider.overrideWithValue(orderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: SpotDetailSheet(spot: spot, onClose: () {}),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially 0 orders today
        expect(find.text('Hari ini: 0 order'), findsOneWidget);

        // Tap 'Dapat order di sini'
        await tester.tap(find.widgetWithText(AppButton, 'Dapat order di sini'));
        await tester.pumpAndSettle();

        // SnackBar appears with message and Batal action
        expect(find.text('Order dicatat'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);

        // Count updates to 1 order
        expect(find.text('Hari ini: 1 order'), findsOneWidget);

        // Verify order exists in DB
        var orders = await orderRepo.getOrdersForSpot(spot.id);
        expect(orders.length, 1);
        expect(orders.first.deletedAt, isNull);

        // Tap 'Batal' action on SnackBar
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        // Order is soft-deleted
        orders = await orderRepo.getOrdersForSpot(spot.id);
        expect(orders.isEmpty, true); // getOrdersForSpot excludes soft-deleted

        // Count updates back to 0 order
        expect(find.text('Hari ini: 0 order'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
