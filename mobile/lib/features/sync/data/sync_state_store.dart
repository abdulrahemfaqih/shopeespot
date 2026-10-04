import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sync_models.dart';

abstract class ISyncStateStore {
  Future<SyncCursors> getCursors();
  Future<void> saveCursors(SyncCursors cursors);
  Future<DateTime?> getLastSyncedAt();
  Future<void> saveLastSyncedAt(DateTime timestamp);
  Future<void> clear();
}

class SyncStateStore implements ISyncStateStore {
  static const String _keySpotsCursor = 'sync_cursor_spots';
  static const String _keyOrdersCursor = 'sync_cursor_orders';
  static const String _keyLastSyncedAt = 'sync_last_synced_at';

  final SharedPreferences? _prefs;

  SyncStateStore([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<SyncCursors> getCursors() async {
    final prefs = await _getPrefs();
    final spots = prefs.getInt(_keySpotsCursor) ?? 0;
    final orders = prefs.getInt(_keyOrdersCursor) ?? 0;
    return SyncCursors(spots: spots, orders: orders);
  }

  @override
  Future<void> saveCursors(SyncCursors cursors) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keySpotsCursor, cursors.spots);
    await prefs.setInt(_keyOrdersCursor, cursors.orders);
  }

  @override
  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await _getPrefs();
    final str = prefs.getString(_keyLastSyncedAt);
    if (str == null) return null;
    return DateTime.tryParse(str)?.toUtc();
  }

  @override
  Future<void> saveLastSyncedAt(DateTime timestamp) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _keyLastSyncedAt,
      timestamp.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keySpotsCursor);
    await prefs.remove(_keyOrdersCursor);
    await prefs.remove(_keyLastSyncedAt);
  }
}

final syncStateStoreProvider = Provider<ISyncStateStore>((ref) {
  return SyncStateStore();
});
