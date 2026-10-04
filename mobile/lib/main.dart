import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'features/map/data/tile_cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? cachePath;
  if (!kIsWeb) {
    try {
      final dir = await getApplicationCacheDirectory();
      cachePath = dir.path;
    } catch (_) {
      // Ignore if cache directory is inaccessible
    }
  }

  await TileCacheManager.initialize(cacheDirectory: cachePath);

  runApp(const ProviderScope(child: SpotShopeeApp()));
}
