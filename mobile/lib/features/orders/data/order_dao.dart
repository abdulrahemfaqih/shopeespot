import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';

part 'order_dao.g.dart';

class PeakHourAggregation {
  const PeakHourAggregation({
    required this.spotId,
    required this.localHour,
    required this.count,
  });

  final String spotId;
  final int localHour;
  final int count;
}

@DriftAccessor(tables: [Orders])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  Stream<List<OrderEntry>> watchOrdersForSpot(String spotId) {
    return (select(orders)
          ..where((tbl) => tbl.spotId.equals(spotId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.orderedAt)]))
        .watch();
  }

  Future<List<OrderEntry>> getOrdersForSpot(String spotId) {
    return (select(orders)
          ..where((tbl) => tbl.spotId.equals(spotId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.orderedAt)]))
        .get();
  }

  Future<List<OrderEntry>> getActiveOrders() {
    return (select(orders)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.orderedAt)]))
        .get();
  }

  Future<OrderEntry?> getOrderById(String id) {
    return (select(
      orders,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertOrder(OrdersCompanion order) {
    return into(orders).insert(order, mode: InsertMode.insertOrReplace);
  }

  Future<void> softDeleteOrder(String id, DateTime deletedAt) {
    return (update(orders)..where((tbl) => tbl.id.equals(id))).write(
      OrdersCompanion(
        deletedAt: Value(deletedAt),
        dirty: const Value(true),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> softDeleteOrdersBySpotId(String spotId, DateTime deletedAt) {
    return (update(orders)
          ..where((tbl) => tbl.spotId.equals(spotId) & tbl.deletedAt.isNull()))
        .write(
          OrdersCompanion(
            deletedAt: Value(deletedAt),
            dirty: const Value(true),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<int> countOrdersToday(DateTime startOfDay) async {
    final countExp = orders.id.count();
    final query = selectOnly(orders)
      ..addColumns([countExp])
      ..where(
        orders.deletedAt.isNull() &
            orders.orderedAt.isBiggerOrEqualValue(startOfDay),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> countOrdersForSpotToday(
    String spotId,
    DateTime startOfDay,
  ) async {
    final countExp = orders.id.count();
    final query = selectOnly(orders)
      ..addColumns([countExp])
      ..where(
        orders.spotId.equals(spotId) &
            orders.deletedAt.isNull() &
            orders.orderedAt.isBiggerOrEqualValue(startOfDay),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<List<OrderEntry>> getDirtyOrders({int limit = 200}) {
    return (select(orders)
          ..where((tbl) => tbl.dirty.equals(true))
          ..limit(limit))
        .get();
  }

  Future<int> markClean(String id, DateTime updatedAt) {
    return (update(orders)
          ..where((tbl) => tbl.id.equals(id) & tbl.updatedAt.equals(updatedAt)))
        .write(const OrdersCompanion(dirty: Value(false)));
  }

  Stream<int> watchDirtyCount() {
    final countExp = orders.id.count();
    return (selectOnly(orders)
          ..addColumns([countExp])
          ..where(orders.dirty.equals(true)))
        .watchSingle()
        .map((row) => row.read(countExp) ?? 0);
  }

  Future<int> countDirty() async {
    final countExp = orders.id.count();
    final row =
        await (selectOnly(orders)
              ..addColumns([countExp])
              ..where(orders.dirty.equals(true)))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<List<PeakHourAggregation>> getPeakOrderAggregation({
    required DateTime since,
    required int dowMin,
    required int dowMax,
  }) async {
    final cnt = orders.id.count();
    final query = selectOnly(orders)
      ..addColumns([orders.spotId, orders.localHour, cnt])
      ..where(
        orders.deletedAt.isNull() &
            orders.orderedAt.isBiggerOrEqualValue(since) &
            orders.localDow.isBiggerOrEqualValue(dowMin) &
            orders.localDow.isSmallerOrEqualValue(dowMax),
      )
      ..groupBy([orders.spotId, orders.localHour]);

    final rows = await query.get();
    return rows.map((r) {
      return PeakHourAggregation(
        spotId: r.read(orders.spotId)!,
        localHour: r.read(orders.localHour)!,
        count: r.read(cnt) ?? 0,
      );
    }).toList();
  }
}
