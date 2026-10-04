import 'package:drift/drift.dart';
import 'converters.dart';

@DataClassName('SpotEntry')
@TableIndex(name: 'spots_deleted_at_idx', columns: {#deletedAt})
@TableIndex(name: 'spots_dirty_idx', columns: {#dirty})
class Spots extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get category => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get notes =>
      text().withLength(max: 500).withDefault(const Constant(''))();
  TextColumn get peakHours => text()
      .map(const PeakHoursConverter())
      .withDefault(const Constant('[]'))();
  DateTimeColumn get lastVerifiedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OrderEntry')
@TableIndex(name: 'orders_spot_ordered_idx', columns: {#spotId, #orderedAt})
@TableIndex(name: 'orders_dirty_idx', columns: {#dirty})
@TableIndex(name: 'orders_dow_hour_idx', columns: {#localDow, #localHour})
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get spotId => text()();
  DateTimeColumn get orderedAt => dateTime()();
  IntColumn get localDow => integer()();
  IntColumn get localHour => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
