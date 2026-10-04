import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';

part 'spot_dao.g.dart';

@DriftAccessor(tables: [Spots])
class SpotDao extends DatabaseAccessor<AppDatabase> with _$SpotDaoMixin {
  SpotDao(super.db);

  Stream<List<SpotEntry>> watchActiveSpots() {
    return (select(spots)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  Future<List<SpotEntry>> getActiveSpots() {
    return (select(spots)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<SpotEntry?> getSpotById(String id) {
    return (select(spots)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertSpot(SpotsCompanion spot) {
    return into(spots).insert(spot, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateSpot(SpotsCompanion spot) {
    return (update(
      spots,
    )..where((tbl) => tbl.id.equals(spot.id.value))).write(spot);
  }

  Future<void> softDeleteSpot(String id, DateTime deletedAt) {
    return (update(spots)..where((tbl) => tbl.id.equals(id))).write(
      SpotsCompanion(
        deletedAt: Value(deletedAt),
        dirty: const Value(true),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<List<SpotEntry>> getDirtySpots({int limit = 200}) {
    return (select(spots)
          ..where((tbl) => tbl.dirty.equals(true))
          ..limit(limit))
        .get();
  }

  Future<int> markClean(String id, DateTime updatedAt) {
    return (update(spots)
          ..where((tbl) => tbl.id.equals(id) & tbl.updatedAt.equals(updatedAt)))
        .write(const SpotsCompanion(dirty: Value(false)));
  }

  Stream<int> watchDirtyCount() {
    final countExp = spots.id.count();
    return (selectOnly(spots)
          ..addColumns([countExp])
          ..where(spots.dirty.equals(true)))
        .watchSingle()
        .map((row) => row.read(countExp) ?? 0);
  }

  Future<int> countDirty() async {
    final countExp = spots.id.count();
    final row =
        await (selectOnly(spots)
              ..addColumns([countExp])
              ..where(spots.dirty.equals(true)))
            .getSingle();
    return row.read(countExp) ?? 0;
  }
}
