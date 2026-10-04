import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../auth/data/token_store.dart';
import '../../orders/data/order_dao.dart';
import '../../spots/data/spot_dao.dart';
import '../../spots/domain/peak_range.dart';
import '../../spots/presentation/spots_providers.dart';
import '../domain/merge_rules.dart';
import '../domain/sync_models.dart';
import 'sync_api.dart';
import 'sync_state_store.dart';

class SyncService {
  final ISyncApi _api;
  final ISyncStateStore _stateStore;
  final SpotDao _spotDao;
  final OrderDao _orderDao;
  final ITokenStore _tokenStore;
  final Connectivity _connectivity;

  bool _isSyncing = false;
  bool _pendingSync = false;
  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  AppLifecycleListener? _lifecycleListener;
  final _syncingController = StreamController<bool>.broadcast();

  Stream<bool> get isSyncingStream => _syncingController.stream;
  bool get isSyncing => _isSyncing;

  SyncService({
    required ISyncApi api,
    required ISyncStateStore stateStore,
    required SpotDao spotDao,
    required OrderDao orderDao,
    required ITokenStore tokenStore,
    Connectivity? connectivity,
  }) : _api = api,
       _stateStore = stateStore,
       _spotDao = spotDao,
       _orderDao = orderDao,
       _tokenStore = tokenStore,
       _connectivity = connectivity ?? Connectivity();

  void initListeners() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        triggerSync();
      }
    });

    _lifecycleListener = AppLifecycleListener(onResume: () => triggerSync());
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _lifecycleListener?.dispose();
    _syncingController.close();
  }

  void notifyLocalChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      triggerSync();
    });
  }

  Future<bool> triggerSync() async {
    final hasSession = await _tokenStore.hasValidSession();
    if (!hasSession) {
      return false;
    }

    if (_isSyncing) {
      _pendingSync = true;
      return false;
    }

    _isSyncing = true;
    _syncingController.add(true);
    try {
      await _runSyncLoop();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSyncing = false;
      _syncingController.add(false);
      if (_pendingSync) {
        _pendingSync = false;
        unawaited(triggerSync());
      }
    }
  }

  Future<void> _runSyncLoop() async {
    bool hasMore;
    bool hasDirty;

    do {
      final dirtySpots = await _spotDao.getDirtySpots(limit: 200);
      final dirtyOrders = await _orderDao.getDirtyOrders(limit: 200);
      final cursors = await _stateStore.getCursors();

      final spotDtos = dirtySpots.map(_spotToDto).toList();
      final orderDtos = dirtyOrders.map(_orderToDto).toList();

      final response = await _api.sync(
        SyncRequestDto(cursors: cursors, spots: spotDtos, orders: orderDtos),
      );

      for (final spot in response.spots) {
        await _applyServerSpot(spot);
      }
      for (final order in response.orders) {
        await _applyServerOrder(order);
      }

      for (final pushed in dirtySpots) {
        await _spotDao.markClean(pushed.id, pushed.updatedAt);
      }
      for (final pushed in dirtyOrders) {
        await _orderDao.markClean(pushed.id, pushed.updatedAt);
      }

      await _stateStore.saveCursors(response.cursors);
      await _stateStore.saveLastSyncedAt(response.serverTime);

      hasMore = response.hasMore;
      final remainingSpots = await _spotDao.getDirtySpots(limit: 1);
      final remainingOrders = await _orderDao.getDirtyOrders(limit: 1);
      hasDirty = remainingSpots.isNotEmpty || remainingOrders.isNotEmpty;
    } while (hasMore || hasDirty);
  }

  Future<void> _applyServerSpot(SyncSpotDto s) async {
    final local = await _spotDao.getSpotById(s.id);
    final action = decideMerge(
      localUpdatedAt: local?.updatedAt,
      localDirty: local?.dirty ?? false,
      incomingUpdatedAt: s.updatedAt,
    );

    if (action == MergeAction.insert || action == MergeAction.update) {
      final ranges = s.peakHours.map((ph) {
        if (ph is Map<String, dynamic>) {
          return PeakRange.fromJson(ph);
        } else if (ph is Map) {
          return PeakRange.fromJson(Map<String, dynamic>.from(ph));
        }
        return const PeakRange(days: [], start: 0, end: 0);
      }).toList();

      await _spotDao.insertSpot(
        SpotsCompanion(
          id: Value(s.id),
          name: Value(s.name),
          category: Value(s.category),
          latitude: Value(s.latitude),
          longitude: Value(s.longitude),
          notes: Value(s.notes),
          peakHours: Value(ranges),
          lastVerifiedAt: Value(s.lastVerifiedAt),
          createdAt: Value(s.createdAt),
          updatedAt: Value(s.updatedAt),
          deletedAt: Value(s.deletedAt),
          dirty: const Value(false),
        ),
      );
    }
  }

  Future<void> _applyServerOrder(SyncOrderDto o) async {
    final local = await _orderDao.getOrderById(o.id);
    final action = decideMerge(
      localUpdatedAt: local?.updatedAt,
      localDirty: local?.dirty ?? false,
      incomingUpdatedAt: o.updatedAt,
    );

    if (action == MergeAction.insert || action == MergeAction.update) {
      await _orderDao.insertOrder(
        OrdersCompanion(
          id: Value(o.id),
          spotId: Value(o.spotId),
          orderedAt: Value(o.orderedAt),
          localDow: Value(o.localDow),
          localHour: Value(o.localHour),
          createdAt: Value(o.createdAt),
          updatedAt: Value(o.updatedAt),
          deletedAt: Value(o.deletedAt),
          dirty: const Value(false),
        ),
      );
    }
  }

  SyncSpotDto _spotToDto(SpotEntry s) {
    final ph = s.peakHours.map((pr) => pr.toJson()).toList();

    return SyncSpotDto(
      id: s.id,
      name: s.name,
      category: s.category,
      latitude: s.latitude,
      longitude: s.longitude,
      notes: s.notes,
      peakHours: ph,
      lastVerifiedAt: s.lastVerifiedAt,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      deletedAt: s.deletedAt,
    );
  }

  SyncOrderDto _orderToDto(OrderEntry o) {
    return SyncOrderDto(
      id: o.id,
      spotId: o.spotId,
      orderedAt: o.orderedAt,
      localDow: o.localDow,
      localHour: o.localHour,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      deletedAt: o.deletedAt,
    );
  }

  Future<int> getDirtyCount() async {
    final spots = await _spotDao.getDirtySpots(limit: 500);
    final orders = await _orderDao.getDirtyOrders(limit: 500);
    return spots.length + orders.length;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final api = ref.watch(syncApiProvider);
  final stateStore = ref.watch(syncStateStoreProvider);
  final db = ref.watch(appDatabaseProvider);
  final tokenStore = ref.watch(tokenStoreProvider);

  final service = SyncService(
    api: api,
    stateStore: stateStore,
    spotDao: SpotDao(db),
    orderDao: OrderDao(db),
    tokenStore: tokenStore,
  );

  service.initListeners();
  ref.onDispose(service.dispose);

  return service;
});

final dirtyCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getDirtyCount();
});
