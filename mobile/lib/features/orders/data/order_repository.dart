import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../spots/data/spot_repository.dart';
import '../domain/order_log.dart';
import 'order_dao.dart';

class OrderRepository {
  OrderRepository({
    required AppDatabase db,
    SpotRepository? spotRepository,
    Clock clock = const SystemClock(),
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _spotRepository = spotRepository,
       _clock = clock,
       _uuid = uuid;

  final AppDatabase _db;
  final SpotRepository? _spotRepository;
  final Clock _clock;
  final Uuid _uuid;

  Stream<List<OrderLog>> watchOrdersForSpot(String spotId) {
    return _db.orderDao
        .watchOrdersForSpot(spotId)
        .map((entries) => entries.map(_entryToDomain).toList());
  }

  Future<List<OrderLog>> getOrdersForSpot(String spotId) async {
    final entries = await _db.orderDao.getOrdersForSpot(spotId);
    return entries.map(_entryToDomain).toList();
  }

  Future<List<OrderLog>> getActiveOrders() async {
    final entries = await _db.orderDao.getActiveOrders();
    return entries.map(_entryToDomain).toList();
  }

  Future<OrderLog?> getOrderById(String id) async {
    final entry = await _db.orderDao.getOrderById(id);
    return entry != null ? _entryToDomain(entry) : null;
  }

  Future<void> upsertOrder(OrderLog order) async {
    await _db.orderDao.insertOrder(_domainToCompanion(order));
  }

  Future<OrderLog> recordOrder({
    required String spotId,
    DateTime? orderedAt,
    String? id,
  }) async {
    final clockNow = _clock.now();
    final orderTime = orderedAt ?? clockNow;
    final utcNow = clockNow.toUtc();
    final orderId = id ?? _uuid.v4();

    final localTime = orderTime.toLocal();
    final localDow = localTime.weekday; // 1 = Mon ... 7 = Sun
    final localHour = localTime.hour; // 0..23

    final order = OrderLog(
      id: orderId,
      spotId: spotId,
      orderedAt: orderTime.toUtc(),
      localDow: localDow,
      localHour: localHour,
      createdAt: utcNow,
      updatedAt: utcNow,
      deletedAt: null,
      dirty: true,
    );

    await _db.orderDao.insertOrder(_domainToCompanion(order));

    // Update spot's last_verified_at when order is recorded
    if (_spotRepository != null) {
      await _spotRepository.touchVerifiedAt(spotId);
    } else {
      final spot = await _db.spotDao.getSpotById(spotId);
      if (spot != null) {
        await _db.spotDao.updateSpot(
          SpotsCompanion(
            id: Value(spot.id),
            lastVerifiedAt: Value(utcNow),
            updatedAt: Value(utcNow),
            dirty: const Value(true),
          ),
        );
      }
    }

    return order;
  }

  Future<void> softDeleteOrder(String id) async {
    final now = _clock.now().toUtc();
    await _db.orderDao.softDeleteOrder(id, now);
  }

  Future<int> countOrdersToday({DateTime? currentDateTime}) {
    final now = currentDateTime ?? _clock.now();
    final local = now.toLocal();
    final startOfTodayLocal = DateTime(local.year, local.month, local.day);
    return _db.orderDao.countOrdersToday(startOfTodayLocal.toUtc());
  }

  Future<int> countOrdersForSpotToday(
    String spotId, {
    DateTime? currentDateTime,
  }) {
    final now = currentDateTime ?? _clock.now();
    final local = now.toLocal();
    final startOfTodayLocal = DateTime(local.year, local.month, local.day);
    return _db.orderDao.countOrdersForSpotToday(
      spotId,
      startOfTodayLocal.toUtc(),
    );
  }

  Future<List<OrderLog>> getDirtyOrders({int limit = 200}) async {
    final entries = await _db.orderDao.getDirtyOrders(limit: limit);
    return entries.map(_entryToDomain).toList();
  }

  Future<int> markClean(String id, DateTime updatedAt) {
    return _db.orderDao.markClean(id, updatedAt);
  }

  Future<void> upsertFromSync(List<OrderLog> orders) async {
    await _db.batch((batch) {
      for (final order in orders) {
        batch.insert(
          _db.orders,
          _domainToCompanion(order),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<List<PeakHourAggregation>> getPeakOrderAggregation({
    required DateTime since,
    required int dowMin,
    required int dowMax,
  }) {
    return _db.orderDao.getPeakOrderAggregation(
      since: since,
      dowMin: dowMin,
      dowMax: dowMax,
    );
  }

  static OrderLog _entryToDomain(OrderEntry entry) {
    return OrderLog(
      id: entry.id,
      spotId: entry.spotId,
      orderedAt: entry.orderedAt.toUtc(),
      localDow: entry.localDow,
      localHour: entry.localHour,
      createdAt: entry.createdAt.toUtc(),
      updatedAt: entry.updatedAt.toUtc(),
      deletedAt: entry.deletedAt?.toUtc(),
      dirty: entry.dirty,
    );
  }

  static OrdersCompanion _domainToCompanion(OrderLog order) {
    return OrdersCompanion(
      id: Value(order.id),
      spotId: Value(order.spotId),
      orderedAt: Value(order.orderedAt),
      localDow: Value(order.localDow),
      localHour: Value(order.localHour),
      createdAt: Value(order.createdAt),
      updatedAt: Value(order.updatedAt),
      deletedAt: Value(order.deletedAt),
      dirty: Value(order.dirty),
    );
  }
}
