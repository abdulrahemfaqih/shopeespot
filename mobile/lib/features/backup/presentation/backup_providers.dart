import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/time/clock.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../spots/presentation/spots_providers.dart';
import '../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final spotRepo = ref.watch(spotRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final clock = ref.watch(clockProvider);

  return BackupService(
    spotRepository: spotRepo,
    orderRepository: orderRepo,
    clock: clock,
  );
});
