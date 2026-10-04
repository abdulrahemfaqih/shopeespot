import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/data/order_dao.dart';
import '../../spots/data/spot_dao.dart';
import '../../spots/presentation/spots_providers.dart';
import '../data/sync_service.dart';
import '../data/sync_state_store.dart';

final isSyncingProvider = StreamProvider.autoDispose<bool>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.isSyncingStream;
});

final lastSyncedAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final stateStore = ref.watch(syncStateStoreProvider);
  return stateStore.getLastSyncedAt();
});

final dirtySpotsCountStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SpotDao(db).watchDirtyCount();
});

final dirtyOrdersCountStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OrderDao(db).watchDirtyCount();
});

final totalDirtyCountProvider = Provider.autoDispose<int>((ref) {
  final spots = ref.watch(dirtySpotsCountStreamProvider).value ?? 0;
  final orders = ref.watch(dirtyOrdersCountStreamProvider).value ?? 0;
  return spots + orders;
});

class SyncManualState {
  final bool isSyncing;
  final String? errorMessage;

  const SyncManualState({this.isSyncing = false, this.errorMessage});
}

class SyncManualNotifier extends StateNotifier<SyncManualState> {
  final Ref _ref;

  SyncManualNotifier(this._ref) : super(const SyncManualState());

  Future<bool> syncNow() async {
    if (state.isSyncing) return false;
    state = const SyncManualState(isSyncing: true);

    try {
      final service = _ref.read(syncServiceProvider);
      final success = await service.triggerSync();
      _ref.invalidate(lastSyncedAtProvider);
      _ref.invalidate(activeSpotsStreamProvider);
      state = SyncManualState(
        isSyncing: false,
        errorMessage: success
            ? null
            : 'Sinkronisasi gagal. Periksa koneksi internet.',
      );
      return success;
    } catch (e) {
      state = SyncManualState(
        isSyncing: false,
        errorMessage: 'Sinkronisasi gagal: $e',
      );
      return false;
    }
  }
}

final syncManualProvider =
    StateNotifierProvider.autoDispose<SyncManualNotifier, SyncManualState>((
      ref,
    ) {
      return SyncManualNotifier(ref);
    });

String formatLastSyncedAt(DateTime? dt) {
  if (dt == null) return 'Belum pernah sinkron';
  final local = dt.toLocal();
  final now = DateTime.now();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  if (isToday) {
    return 'Terakhir sinkron: $h:$m';
  }
  return 'Terakhir sinkron: ${local.day} ${months[local.month - 1]} $h:$m';
}

String formatSyncSubtitle({
  required DateTime? lastSyncedAt,
  required int dirtyCount,
  required bool isExpired,
}) {
  if (isExpired) {
    return 'Sesi berakhir. Masuk lagi untuk sinkronisasi.';
  }

  final syncText = formatLastSyncedAt(lastSyncedAt);
  if (dirtyCount > 0) {
    return '$syncText · $dirtyCount perubahan menunggu';
  }
  return syncText;
}
