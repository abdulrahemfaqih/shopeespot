import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/time/clock.dart';

class TileCacheManager {
  const TileCacheManager._();

  static const String lastCleanKey = 'tile_cache_last_clean_date';
  static const int maxCacheSizeBytes = 200 * 1024 * 1024; // 200 MB
  static const Duration freshAge = Duration(days: 14);
  static const Duration cleanInterval = Duration(days: 21);

  static Future<void> initialize({
    SharedPreferences? prefs,
    Clock clock = const SystemClock(),
    String? cacheDirectory,
  }) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    final now = clock.now();
    final lastCleanStr = preferences.getString(lastCleanKey);

    if (lastCleanStr != null) {
      final lastClean = DateTime.tryParse(lastCleanStr);
      if (lastClean != null && now.difference(lastClean) > cleanInterval) {
        if (cacheDirectory != null) {
          try {
            final provider = BuiltInMapCachingProvider.getOrCreateInstance(
              cacheDirectory: cacheDirectory,
            );
            await provider.destroy(deleteCache: true);
          } catch (_) {}
        }
        await preferences.setString(lastCleanKey, now.toIso8601String());
      }
    } else {
      await preferences.setString(lastCleanKey, now.toIso8601String());
    }

    if (cacheDirectory != null) {
      try {
        BuiltInMapCachingProvider.getOrCreateInstance(
          cacheDirectory: cacheDirectory,
          maxCacheSize: maxCacheSizeBytes,
          overrideFreshAge: freshAge,
          tileKeyGenerator: (url) {
            try {
              final uri = Uri.parse(url);
              final cleanUri = uri.replace(queryParameters: {});
              return BuiltInMapCachingProvider.uuidTileKeyGenerator(
                cleanUri.toString(),
              );
            } catch (_) {
              return BuiltInMapCachingProvider.uuidTileKeyGenerator(url);
            }
          },
        );
      } catch (_) {}
    }
  }
}
