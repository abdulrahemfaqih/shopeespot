import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spots/presentation/spots_providers.dart';
import '../data/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final spotRepo = ref.watch(spotRepositoryProvider);
  return OrderRepository(db: db, spotRepository: spotRepo);
});

final spotOrdersCountTodayProvider = FutureProvider.autoDispose
    .family<int, String>((ref, spotId) {
      final repo = ref.watch(orderRepositoryProvider);
      return repo.countOrdersForSpotToday(spotId);
    });
