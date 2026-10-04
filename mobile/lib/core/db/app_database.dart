import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'converters.dart';
import 'tables.dart';
import '../../features/orders/data/order_dao.dart';
import '../../features/spots/data/spot_dao.dart';
import '../../features/spots/domain/peak_range.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Spots, Orders, SyncMeta], daos: [SpotDao, OrderDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'shopeespot');
  }

  Future<String?> getMeta(String key) async {
    final row = await (select(
      syncMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) {
    return into(syncMeta).insert(
      SyncMetaCompanion(key: Value(key), value: Value(value)),
      mode: InsertMode.insertOrReplace,
    );
  }
}
