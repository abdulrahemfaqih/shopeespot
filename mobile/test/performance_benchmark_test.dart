import 'dart:math';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/features/map/domain/clustering.dart';
import 'package:shopeespot/features/map/presentation/map_controller.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/map/presentation/widgets/quick_pin_fab.dart';
import 'package:shopeespot/features/orders/data/order_dao.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/peak/domain/peak_calculator.dart';
import 'package:shopeespot/features/peak/domain/peak_index.dart';
import 'package:shopeespot/features/spots/data/spot_dao.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/sync/data/sync_api.dart';
import 'package:shopeespot/features/sync/data/sync_service.dart';
import 'package:shopeespot/features/sync/data/sync_state_store.dart';
import 'package:shopeespot/features/sync/domain/sync_models.dart';

import 'auth_test.dart';

class _StaticLocationNotifier extends UserLocationNotifier {
  _StaticLocationNotifier(this._initial);
  final LocationState _initial;

  @override
  LocationState build() => _initial;
}

class _StaticCameraNotifier extends MapCameraNotifier {
  @override
  Future<MapCameraState> build() async {
    return const MapCameraState(
      center: LatLng(defaultLat, defaultLng),
      zoom: defaultZoom,
    );
  }
}

class _BenchmarkSyncApi implements ISyncApi {
  int callCount = 0;

  @override
  Future<SyncResponseDto> sync(SyncRequestDto request) async {
    callCount++;
    return SyncResponseDto(
      cursors: SyncCursors(
        spots: request.cursors.spots + request.spots.length,
        orders: request.cursors.orders + request.orders.length,
      ),
      spots: const [],
      orders: const [],
      hasMore: false,
      serverTime: DateTime.now().toUtc(),
    );
  }
}

class _BenchmarkSyncStateStore implements ISyncStateStore {
  SyncCursors cursors = const SyncCursors();
  DateTime? lastSyncedAt;

  @override
  Future<SyncCursors> getCursors() async => cursors;

  @override
  Future<void> saveCursors(SyncCursors cursors) async {
    this.cursors = cursors;
  }

  @override
  Future<DateTime?> getLastSyncedAt() async => lastSyncedAt;

  @override
  Future<void> saveLastSyncedAt(DateTime timestamp) async {
    lastSyncedAt = timestamp;
  }

  @override
  Future<void> clear() async {}
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('T-31 Performance Profiling (2,000 spots, 20,000 orders)', () {
    late AppDatabase db;
    late SpotRepository spotRepo;
    late OrderRepository orderRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      spotRepo = SpotRepository(db: db);
      orderRepo = OrderRepository(db: db, spotRepository: spotRepo);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Seed 2,000 spots and 20,000 orders and measure SQLite batch performance',
      () async {
        final rng = Random(42);
        final now = DateTime.now().toUtc();

        // Benchmark 2,000 spots insertion via batch
        final swSpots = Stopwatch()..start();
        final spotCompanions = <SpotsCompanion>[];
        for (var i = 0; i < 2000; i++) {
          final cat = i.isEven ? 'shopeefood' : 'spx';
          final lat = -6.2 + (rng.nextDouble() - 0.5) * 0.15;
          final lng = 106.8 + (rng.nextDouble() - 0.5) * 0.15;
          spotCompanions.add(
            SpotsCompanion.insert(
              id: 'spot-perf-$i',
              name: 'Spot $cat #$i',
              category: cat,
              latitude: lat,
              longitude: lng,
              dirty: const Value(false),
              createdAt: now.subtract(Duration(days: rng.nextInt(60))),
              updatedAt: now,
            ),
          );
        }

        await db.batch((batch) {
          batch.insertAll(db.spots, spotCompanions);
        });
        swSpots.stop();

        // Benchmark 20,000 orders insertion via batch
        final swOrders = Stopwatch()..start();
        final orderCompanions = <OrdersCompanion>[];
        for (var i = 0; i < 20000; i++) {
          final spotIdx = rng.nextInt(2000);
          final hour = 8 + rng.nextInt(14); // 8:00 - 22:00
          final dow = 1 + rng.nextInt(7); // 1 - 7
          final daysAgo = rng.nextInt(80);
          final orderedAt = now.subtract(
            Duration(days: daysAgo, hours: 24 - hour),
          );

          orderCompanions.add(
            OrdersCompanion.insert(
              id: 'order-perf-$i',
              spotId: 'spot-perf-$spotIdx',
              orderedAt: orderedAt,
              localDow: dow,
              localHour: hour,
              dirty: const Value(false),
              createdAt: orderedAt,
              updatedAt: orderedAt,
            ),
          );
        }

        // Insert in chunks of 5000 for SQLite limits
        for (var i = 0; i < orderCompanions.length; i += 5000) {
          final chunk = orderCompanions.sublist(
            i,
            min(i + 5000, orderCompanions.length),
          );
          await db.batch((batch) {
            batch.insertAll(db.orders, chunk);
          });
        }
        swOrders.stop();

        final countSpots = (await spotRepo.getActiveSpots()).length;
        final countOrders = (await db.select(db.orders).get()).length;

        expect(countSpots, 2000);
        expect(countOrders, 20000);

        // ignore: avoid_print
        print(
          '[PERF] 2,000 spots inserted in: ${swSpots.elapsedMilliseconds} ms',
        );
        // ignore: avoid_print
        print(
          '[PERF] 20,000 orders inserted in: ${swOrders.elapsedMilliseconds} ms',
        );
      },
    );

    test(
      '2. Measure PeakIndex calculation time with 20,000 orders in SQLite',
      () async {
        final rng = Random(42);
        final now = DateTime.now().toUtc();

        // Seed spots
        final spotCompanions = List.generate(
          2000,
          (i) => SpotsCompanion.insert(
            id: 'spot-peak-$i',
            name: 'Spot #$i',
            category: i.isEven ? 'shopeefood' : 'spx',
            latitude: -6.2,
            longitude: 106.8,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.batch((b) => b.insertAll(db.spots, spotCompanions));

        // Seed orders
        final orderCompanions = List.generate(20000, (i) {
          final spotIdx = rng.nextInt(2000);
          final hour = 11 + rng.nextInt(3); // Concentrated 11-13
          final dow = 1 + rng.nextInt(5); // Weekdays
          return OrdersCompanion.insert(
            id: 'order-peak-$i',
            spotId: 'spot-peak-$spotIdx',
            orderedAt: now.subtract(Duration(days: rng.nextInt(30))),
            localDow: dow,
            localHour: hour,
            createdAt: now,
            updatedAt: now,
          );
        });

        for (var i = 0; i < orderCompanions.length; i += 5000) {
          final chunk = orderCompanions.sublist(
            i,
            min(i + 5000, orderCompanions.length),
          );
          await db.batch((b) => b.insertAll(db.orders, chunk));
        }

        // Measure PeakIndex calculation
        const calculator = PeakCalculator();
        final swCalc = Stopwatch()..start();
        final peakIndex = await calculator.calculateFromRepository(orderRepo);
        swCalc.stop();

        // ignore: avoid_print
        print(
          '[PERF] PeakIndex calculation (20k orders): ${swCalc.elapsedMilliseconds} ms',
        );

        // PRD non-functional requirement: PeakIndex calculated in under 1000ms
        expect(swCalc.elapsedMilliseconds, lessThan(1000));
        expect(peakIndex, isA<PeakIndex>());
      },
    );

    test('3. Measure map clustering & viewport filtering with 2,000 spots', () {
      final rng = Random(42);
      final now = DateTime.now().toUtc();

      final spots = List.generate(
        2000,
        (i) => Spot(
          id: 's-$i',
          name: 'Warung #$i',
          category: i.isEven ? Category.shopeefood : Category.spx,
          latitude: -6.2 + (rng.nextDouble() - 0.5) * 0.2,
          longitude: 106.8 + (rng.nextDouble() - 0.5) * 0.2,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Benchmark clustering at zoomed-out level (zoom 12)
      final swZoomOut = Stopwatch()..start();
      final clusterZoomOut = computeMapClusters(
        spots: spots,
        minLat: -6.35,
        maxLat: -6.05,
        minLng: 106.65,
        maxLng: 106.95,
        zoom: 12.0,
      );
      swZoomOut.stop();

      // Benchmark clustering at street level (zoom 16)
      final swZoomIn = Stopwatch()..start();
      final clusterZoomIn = computeMapClusters(
        spots: spots,
        minLat: -6.22,
        maxLat: -6.18,
        minLng: 106.78,
        maxLng: 106.82,
        zoom: 16.0,
      );
      swZoomIn.stop();

      // ignore: avoid_print
      print(
        '[PERF] Map clustering 2k spots (zoom 12): ${swZoomOut.elapsedMicroseconds / 1000.0} ms',
      );
      // ignore: avoid_print
      print(
        '[PERF] Map clustering 2k spots (zoom 16): ${swZoomIn.elapsedMicroseconds / 1000.0} ms',
      );

      // Target is well under 16.6 ms (60 fps budget), allow headroom for concurrent runner
      expect(swZoomOut.elapsedMilliseconds, lessThan(50));
      expect(swZoomIn.elapsedMilliseconds, lessThan(50));
      expect(clusterZoomOut.isNotEmpty, isTrue);
      expect(clusterZoomIn.isNotEmpty, isTrue);
    });

    test('4. Measure batch sync processing of 500 rows', () async {
      final rng = Random(42);
      final now = DateTime.now().toUtc();

      // Seed 500 dirty spots
      final spotCompanions = List.generate(
        500,
        (i) => SpotsCompanion.insert(
          id: 'sync-spot-$i',
          name: 'Dirty Spot #$i',
          category: i.isEven ? 'shopeefood' : 'spx',
          latitude: -6.2 + (rng.nextDouble() - 0.5) * 0.05,
          longitude: 106.8 + (rng.nextDouble() - 0.5) * 0.05,
          dirty: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.batch((b) => b.insertAll(db.spots, spotCompanions));

      final tokenStore = FakeTokenStore()
        ..accessToken = 'valid'
        ..refreshToken = 'valid';
      final syncApi = _BenchmarkSyncApi();
      final stateStore = _BenchmarkSyncStateStore();

      final syncService = SyncService(
        api: syncApi,
        stateStore: stateStore,
        spotDao: SpotDao(db),
        orderDao: OrderDao(db),
        tokenStore: tokenStore,
      );

      final swSync = Stopwatch()..start();
      final success = await syncService.triggerSync();
      swSync.stop();

      // ignore: avoid_print
      print(
        '[PERF] Batch sync 500 rows processing time: ${swSync.elapsedMilliseconds} ms',
      );

      expect(success, isTrue);
      expect(swSync.elapsedMilliseconds, lessThan(3000));

      final remainingDirty = await SpotDao(db).getDirtySpots();
      expect(remainingDirty.isEmpty, isTrue);
    });

    testWidgets('5. Measure time to map display and QuickPin with 2,000 spots', (
      tester,
    ) async {
      final rng = Random(42);
      final now = DateTime.now().toUtc();

      final spotCompanions = List.generate(
        2000,
        (i) => SpotsCompanion.insert(
          id: 'widget-spot-$i',
          name: 'Spot $i',
          category: i.isEven ? 'shopeefood' : 'spx',
          latitude: -6.200 + (rng.nextDouble() - 0.5) * 0.08,
          longitude: 106.816 + (rng.nextDouble() - 0.5) * 0.08,
          dirty: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.batch((b) => b.insertAll(db.spots, spotCompanions));

      final swMapDisplay = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
            userLocationProvider.overrideWith(
              () => _StaticLocationNotifier(
                LocationAvailable(
                  UserLocation(
                    latitude: -6.2,
                    longitude: 106.816,
                    accuracy: 10,
                    timestamp: now,
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const MapScreen()),
        ),
      );
      await tester.pump();
      swMapDisplay.stop();

      // ignore: avoid_print
      print(
        '[PERF] Time to initial MapScreen first frame (2k spots in SQLite): ${swMapDisplay.elapsedMilliseconds} ms',
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(swMapDisplay.elapsedMilliseconds, lessThan(3000));

      await tester.pumpAndSettle();

      // Measure QuickPin tap to SpotFormScreen ready
      final swQuickPin = Stopwatch()..start();
      await tester.tap(find.byType(QuickPinFab));
      await tester.pump();
      await tester.pumpAndSettle();
      swQuickPin.stop();

      // ignore: avoid_print
      print(
        '[PERF] Time from QuickPin tap to SpotFormScreen ready: ${swQuickPin.elapsedMilliseconds} ms',
      );

      expect(swQuickPin.elapsedMilliseconds, lessThan(2000));
      expect(find.byType(SpotFormScreen), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    test('6. Verify seed cleanup removes all rows completely', () async {
      await db.delete(db.spots).go();
      await db.delete(db.orders).go();

      final spotsRemaining = await db.select(db.spots).get();
      final ordersRemaining = await db.select(db.orders).get();

      expect(spotsRemaining.isEmpty, isTrue);
      expect(ordersRemaining.isEmpty, isTrue);
    });
  });
}
