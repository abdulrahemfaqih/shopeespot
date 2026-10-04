import 'package:flutter/material.dart';
import '../features/map/presentation/map_screen.dart';
import 'theme/app_theme.dart';

class SpotShopeeApp extends StatelessWidget {
  const SpotShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotShopee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const MapScreen(),
    );
  }
}
