import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/features/orders/data/order_dao.dart';
import 'package:shopeespot/features/spots/data/spot_dao.dart';
import 'package:shopeespot/features/sync/data/sync_api.dart';
import 'package:shopeespot/features/sync/data/sync_service.dart';
import 'package:shopeespot/features/sync/data/sync_state_store.dart';
import 'package:shopeespot/features/sync/domain/sync_models.dart';

import 'auth_test.dart';

class MockSyncApi implements ISyncApi {
  SyncResponseDto? responseToReturn;
  final List<SyncRequestDto> recordedRequests = [];

  // In-memory server simulation for two-device sync test
  final List<SyncSpotDto> serverSpots = [];
  final List<SyncOrderDto> serverOrders = [];
  int serverSeq = 1;
  Future<void> Function()? onSync;

  @override
  Future<SyncResponseDto> sync(SyncRequestDto request) async {
    recordedRequests.add(request);

    if (onSync != null) {
      await onSync!();
    }

    if (responseToReturn != null) {
      return responseToReturn!;
    }

    // Default mock server implementation: upsert incoming and pull updates
    for (final s in request.spots) {
      final idx = serverSpots.indexWhere((existing) => existing.id == s.id);
      final withSeq = SyncSpotDto(
        id: s.id,
        name: s.name,
        category: s.category,
        latitude: s.latitude,
        longitude: s.longitude,
        notes: s.notes,
        peakHours: s.peakHours,
        lastVerifiedAt: s.lastVerifiedAt,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
        deletedAt: s.deletedAt,
        seq: serverSeq++,
      );
      if (idx >= 0) {
        if (s.updatedAt.isAfter(serverSpots[idx].updatedAt)) {
          serverSpots[idx] = withSeq;
        }
      } else {
        serverSpots.add(withSeq);
      }
    }

    for (final o in request.orders) {
      final idx = serverOrders.indexWhere((existing) => existing.id == o.id);
      final withSeq = SyncOrderDto(
        id: o.id,
        spotId: o.spotId,
        orderedAt: o.orderedAt,
        localDow: o.localDow,
        localHour: o.localHour,
        createdAt: o.createdAt,
        updatedAt: o.updatedAt,
        deletedAt: o.deletedAt,
        seq: serverSeq++,
      );
      if (idx >= 0) {
        if (o.updatedAt.isAfter(serverOrders[idx].updatedAt)) {
          serverOrders[idx] = withSeq;
        }
      } else {
        serverOrders.add(withSeq);
      }
    }

    final pulledSpots = serverSpots
        .where((s) => (s.seq ?? 0) > request.cursors.spots)
        .toList();
    final pulledOrders = serverOrders
        .where((o) => (o.seq ?? 0) > request.cursors.orders)
        .toList();

    var nextSpotCursor = request.cursors.spots;
    for (final s in pulledSpots) {
      if ((s.seq ?? 0) > nextSpotCursor) nextSpotCursor = s.seq!;
    }
    var nextOrderCursor = request.cursors.orders;
    for (final o in pulledOrders) {
      if ((o.seq ?? 0) > nextOrderCursor) nextOrderCursor = o.seq!;
    }

    return SyncResponseDto(
      cursors: SyncCursors(spots: nextSpotCursor, orders: nextOrderCursor),
      spots: pulledSpots,
      orders: pulledOrders,
      hasMore: false,
      serverTime: DateTime.now().toUtc(),
    );
  }
}

class FakeSyncStateStore implements ISyncStateStore {
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
  Future<void> clear() async {
    cursors = const SyncCursors();
    lastSyncedAt = null;
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('SyncService tests', () {
    late AppDatabase db;
    late SpotDao spotDao;
    late OrderDao orderDao;
    late FakeTokenStore tokenStore;
    late FakeSyncStateStore stateStore;
    late MockSyncApi mockApi;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      spotDao = SpotDao(db);
      orderDao = OrderDao(db);
      tokenStore = FakeTokenStore()..refreshToken = 'valid-token';
      stateStore = FakeSyncStateStore();
      mockApi = MockSyncApi();
    });

    tearDown(() async {
      await db.close();
    });

    test('pushes dirty spot and marks it clean after sync', () async {
      final now = DateTime.now().toUtc();
      await spotDao.insertSpot(
        SpotsCompanion.insert(
          id: 'spot-1',
          name: 'Spot Warung',
          category: 'shopeefood',
          latitude: -7.0,
          longitude: 112.0,
          createdAt: now,
          updatedAt: now,
          dirty: const Value(true),
        ),
      );

      final service = SyncService(
        api: mockApi,
        stateStore: stateStore,
        spotDao: spotDao,
        orderDao: orderDao,
        tokenStore: tokenStore,
      );

      final success = await service.triggerSync();
      expect(success, isTrue);

      final updatedSpot = await spotDao.getSpotById('spot-1');
      expect(updatedSpot?.dirty, isFalse);
      expect(stateStore.cursors.spots, greaterThan(0));
      expect(stateStore.lastSyncedAt, isNotNull);
    });

    test(
      'does not mark clean if spot updatedAt was modified during sync',
      () async {
        final t0 = DateTime(2026, 10, 4, 10, 0).toUtc();
        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-modified',
            name: 'Initial Name',
            category: 'shopeefood',
            latitude: -7.0,
            longitude: 112.0,
            createdAt: t0,
            updatedAt: t0,
            dirty: const Value(true),
          ),
        );

        var syncCalls = 0;
        // Simulate a local modification while sync request is in flight
        mockApi.onSync = () async {
          syncCalls++;
          if (syncCalls == 1) {
            final t1 = DateTime(2026, 10, 4, 10, 1).toUtc();
            await spotDao.updateSpot(
              SpotsCompanion(
                id: const Value('spot-modified'),
                name: const Value('Updated While Syncing'),
                updatedAt: Value(t1),
                dirty: const Value(true),
              ),
            );
          }
        };

        final service = SyncService(
          api: mockApi,
          stateStore: stateStore,
          spotDao: spotDao,
          orderDao: orderDao,
          tokenStore: tokenStore,
        );

        await service.triggerSync();

        // Because markClean on t0 did not clear dirty flag, sync ran a 2nd loop pass and synced t1
        expect(syncCalls, 2);
        expect(mockApi.serverSpots.last.name, 'Updated While Syncing');

        // Direct verification: markClean with stale updatedAt updates 0 rows
        final staleMarkResult = await spotDao.markClean('spot-modified', t0);
        expect(staleMarkResult, 0);
      },
    );

    test(
      'two devices sync simulation: data pushed from Device A appears on Device B (T-29 criteria)',
      () async {
        final sharedServerApi = MockSyncApi();

        // --- Device A setup ---
        final dbA = AppDatabase(NativeDatabase.memory());
        final spotDaoA = SpotDao(dbA);
        final orderDaoA = OrderDao(dbA);
        final storeA = FakeSyncStateStore();
        final tokenStoreA = FakeTokenStore()..refreshToken = 'token-dev-a';

        final serviceA = SyncService(
          api: sharedServerApi,
          stateStore: storeA,
          spotDao: spotDaoA,
          orderDao: orderDaoA,
          tokenStore: tokenStoreA,
        );

        // Device A creates a spot and an order
        final now = DateTime.now().toUtc();
        await spotDaoA.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-device-a',
            name: 'Spot Dari Device A',
            category: 'shopeefood',
            latitude: -7.25,
            longitude: 112.75,
            createdAt: now,
            updatedAt: now,
            dirty: const Value(true),
          ),
        );
        await orderDaoA.insertOrder(
          OrdersCompanion.insert(
            id: 'order-device-a',
            spotId: 'spot-device-a',
            orderedAt: now,
            localDow: 1,
            localHour: 12,
            createdAt: now,
            updatedAt: now,
            dirty: const Value(true),
          ),
        );

        // Device A performs sync
        final syncSuccessA = await serviceA.triggerSync();
        expect(syncSuccessA, isTrue);

        // --- Device B setup (clean initial database) ---
        final dbB = AppDatabase(NativeDatabase.memory());
        final spotDaoB = SpotDao(dbB);
        final orderDaoB = OrderDao(dbB);
        final storeB = FakeSyncStateStore(); // cursor 0
        final tokenStoreB = FakeTokenStore()..refreshToken = 'token-dev-b';

        final serviceB = SyncService(
          api: sharedServerApi,
          stateStore: storeB,
          spotDao: spotDaoB,
          orderDao: orderDaoB,
          tokenStore: tokenStoreB,
        );

        // Initially Device B has 0 spots and 0 orders
        expect(await spotDaoB.getActiveSpots(), isEmpty);
        expect(await orderDaoB.getActiveOrders(), isEmpty);

        // Device B triggers sync
        final syncSuccessB = await serviceB.triggerSync();
        expect(syncSuccessB, isTrue);

        // Verification: Data from Device A now appears on Device B!
        final spotsOnB = await spotDaoB.getActiveSpots();
        final ordersOnB = await orderDaoB.getActiveOrders();

        expect(spotsOnB.length, 1);
        expect(spotsOnB.first.id, 'spot-device-a');
        expect(spotsOnB.first.name, 'Spot Dari Device A');
        expect(spotsOnB.first.dirty, isFalse);

        expect(ordersOnB.length, 1);
        expect(ordersOnB.first.id, 'order-device-a');
        expect(ordersOnB.first.spotId, 'spot-device-a');
        expect(ordersOnB.first.dirty, isFalse);

        await dbA.close();
        await dbB.close();
      },
    );
  });
}
