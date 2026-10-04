import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../domain/category.dart';
import '../domain/peak_range.dart';
import '../domain/spot.dart';

class SpotRepository {
  SpotRepository({
    required AppDatabase db,
    Clock clock = const SystemClock(),
    Uuid uuid = const Uuid(),
  }) : _db = db,
       _clock = clock,
       _uuid = uuid;

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  Stream<List<Spot>> watchActiveSpots() {
    return _db.spotDao.watchActiveSpots().map(
      (entries) => entries.map(_entryToDomain).toList(),
    );
  }

  Future<List<Spot>> getActiveSpots() async {
    final entries = await _db.spotDao.getActiveSpots();
    return entries.map(_entryToDomain).toList();
  }

  Future<Spot?> getSpotById(String id) async {
    final entry = await _db.spotDao.getSpotById(id);
    return entry != null ? _entryToDomain(entry) : null;
  }

  Future<Spot> createSpot({
    String? id,
    required String name,
    required Category category,
    required double latitude,
    required double longitude,
    String notes = '',
    List<PeakRange> peakHours = const [],
  }) async {
    final now = _clock.now().toUtc();
    final spotId = id ?? _uuid.v4();

    final spot = Spot(
      id: spotId,
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      peakHours: peakHours,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      dirty: true,
    );

    await _db.spotDao.insertSpot(_domainToCompanion(spot));
    return spot;
  }

  Future<Spot> updateSpot({
    required String id,
    required String name,
    required Category category,
    required double latitude,
    required double longitude,
    String notes = '',
    List<PeakRange> peakHours = const [],
    bool updateVerifiedAt = true,
  }) async {
    final now = _clock.now().toUtc();
    final existing = await getSpotById(id);
    if (existing == null) {
      throw StateError('Spot with ID $id does not exist');
    }

    final updated = existing.copyWith(
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      peakHours: peakHours,
      lastVerifiedAt: updateVerifiedAt ? now : existing.lastVerifiedAt,
      updatedAt: now,
      dirty: true,
    );

    await _db.spotDao.updateSpot(_domainToCompanion(updated));
    return updated;
  }

  Future<void> touchVerifiedAt(String id) async {
    final now = _clock.now().toUtc();
    final existing = await getSpotById(id);
    if (existing != null) {
      final updated = existing.copyWith(
        lastVerifiedAt: now,
        updatedAt: now,
        dirty: true,
      );
      await _db.spotDao.updateSpot(_domainToCompanion(updated));
    }
  }

  Future<void> softDeleteSpot(String id) async {
    final now = _clock.now().toUtc();
    await _db.transaction(() async {
      await _db.spotDao.softDeleteSpot(id, now);
      await _db.orderDao.softDeleteOrdersBySpotId(id, now);
    });
  }

  Future<List<Spot>> getDirtySpots({int limit = 200}) async {
    final entries = await _db.spotDao.getDirtySpots(limit: limit);
    return entries.map(_entryToDomain).toList();
  }

  Future<int> markClean(String id, DateTime updatedAt) {
    return _db.spotDao.markClean(id, updatedAt);
  }

  Future<void> upsertFromSync(List<Spot> spots) async {
    await _db.batch((batch) {
      for (final spot in spots) {
        batch.insert(
          _db.spots,
          _domainToCompanion(spot),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  static Spot _entryToDomain(SpotEntry entry) {
    return Spot(
      id: entry.id,
      name: entry.name,
      category: Category.fromString(entry.category),
      latitude: entry.latitude,
      longitude: entry.longitude,
      notes: entry.notes,
      peakHours: entry.peakHours,
      lastVerifiedAt: entry.lastVerifiedAt?.toUtc(),
      createdAt: entry.createdAt.toUtc(),
      updatedAt: entry.updatedAt.toUtc(),
      deletedAt: entry.deletedAt?.toUtc(),
      dirty: entry.dirty,
    );
  }

  static SpotsCompanion _domainToCompanion(Spot spot) {
    return SpotsCompanion(
      id: Value(spot.id),
      name: Value(spot.name),
      category: Value(spot.category.value),
      latitude: Value(spot.latitude),
      longitude: Value(spot.longitude),
      notes: Value(spot.notes),
      peakHours: Value(spot.peakHours),
      lastVerifiedAt: Value(spot.lastVerifiedAt),
      createdAt: Value(spot.createdAt),
      updatedAt: Value(spot.updatedAt),
      deletedAt: Value(spot.deletedAt),
      dirty: Value(spot.dirty),
    );
  }
}
