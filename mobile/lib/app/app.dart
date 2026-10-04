import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/map/presentation/map_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class SpotShopeeApp extends ConsumerWidget {
  const SpotShopeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'SpotShopee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const MapScreen(),
    );
  }
}
