import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/spot_repository.dart';
import '../domain/spot.dart';

import '../../../core/time/clock.dart';
import '../../map/presentation/map_filter_provider.dart';
import '../../peak/domain/peak_index.dart';
import '../../peak/presentation/peak_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SpotRepository(db: db);
});

final activeSpotsStreamProvider = StreamProvider<List<Spot>>((ref) {
  final repo = ref.watch(spotRepositoryProvider);
  return repo.watchActiveSpots();
});

final filteredSpotsProvider = Provider<List<Spot>>((ref) {
  final spots = ref.watch(activeSpotsStreamProvider).value ?? const <Spot>[];
  final filter = ref.watch(mapFilterProvider);
  final peakIndex = ref.watch(peakIndexProvider).value ?? const PeakIndex();
  final clock = ref.watch(clockProvider);
  return filter.apply(spots, peakIndex: peakIndex, now: clock.now());
});
