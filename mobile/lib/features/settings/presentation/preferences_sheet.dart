import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/navigation/navigation_launcher.dart';
import 'settings_tiles.dart';

void showThemePicker(
  BuildContext context,
  WidgetRef ref,
  ThemeMode currentMode,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final tokens = sheetContext.tokens;
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusLg),
          ),
          border: Border(
            top: BorderSide(color: tokens.border, width: tokens.borderWidth),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: tokens.space8,
                    bottom: tokens.space16,
                  ),
                  width: 32.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.space16),
                child: Text(
                  'Pilih tema',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: tokens.space8),
              OptionTile<ThemeMode>(
                title: 'Sistem',
                subtitle: 'Mengikuti tema perangkat',
                value: ThemeMode.system,
                groupValue: currentMode,
                onSelect: (mode) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
              OptionTile<ThemeMode>(
                title: 'Terang',
                value: ThemeMode.light,
                groupValue: currentMode,
                onSelect: (mode) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
              OptionTile<ThemeMode>(
                title: 'Gelap',
                value: ThemeMode.dark,
                groupValue: currentMode,
                onSelect: (mode) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
              SizedBox(height: tokens.space16),
            ],
          ),
        ),
      );
    },
  );
}

void showNavigationPicker(
  BuildContext context,
  WidgetRef ref,
  NavigationApp currentApp,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final tokens = sheetContext.tokens;
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusLg),
          ),
          border: Border(
            top: BorderSide(color: tokens.border, width: tokens.borderWidth),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: tokens.space8,
                    bottom: tokens.space16,
                  ),
                  width: 32.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.space16),
                child: Text(
                  'Pilih aplikasi navigasi',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: tokens.space8),
              OptionTile<NavigationApp>(
                title: 'Google Maps',
                subtitle: 'Mode sepeda motor',
                value: NavigationApp.googleMaps,
                groupValue: currentApp,
                onSelect: (app) {
                  ref.read(navigationAppProvider.notifier).setApp(app);
                  Navigator.of(sheetContext).pop();
                },
              ),
              OptionTile<NavigationApp>(
                title: 'Waze',
                value: NavigationApp.waze,
                groupValue: currentApp,
                onSelect: (app) {
                  ref.read(navigationAppProvider.notifier).setApp(app);
                  Navigator.of(sheetContext).pop();
                },
              ),
              SizedBox(height: tokens.space16),
            ],
          ),
        ),
      );
    },
  );
}
