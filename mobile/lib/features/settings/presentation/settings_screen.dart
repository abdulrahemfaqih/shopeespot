import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/navigation/navigation_launcher.dart';
import '../../backup/domain/backup_models.dart';
import '../../backup/presentation/backup_providers.dart';
import '../../peak/presentation/peak_provider.dart';
import '../../spots/presentation/spots_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final themeMode = ref.watch(themeModeProvider);
    final navApp = ref.watch(navigationAppProvider);

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        children: [
          // 1. Tema
          _SettingsRow(
            title: 'Tema',
            subtitle: _themeModeLabel(themeMode),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 2. Navigasi
          _SettingsRow(
            title: 'Aplikasi navigasi',
            subtitle: navApp.label,
            onTap: () => _showNavigationPicker(context, ref, navApp),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 3. Cadangan
          _SettingsRow(
            title: 'Cadangan',
            subtitle: 'Ekspor dan impor data (JSON)',
            onTap: () => _showBackupOptions(context, ref),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 4. Sinkronisasi (akan diisi di T-30)
          const _SettingsRow(
            title: 'Sinkronisasi',
            subtitle: 'Belum terhubung ke server',
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 5. Akun (akan diisi di T-30)
          const _SettingsRow(title: 'Akun', subtitle: 'Belum masuk'),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 6. Versi aplikasi
          const _SettingsRow(title: 'Versi aplikasi', subtitle: '1.0.0'),
        ],
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sistem';
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
    }
  }

  void _showThemePicker(
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
                _OptionTile<ThemeMode>(
                  title: 'Sistem',
                  subtitle: 'Mengikuti tema perangkat',
                  value: ThemeMode.system,
                  groupValue: currentMode,
                  onSelect: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _OptionTile<ThemeMode>(
                  title: 'Terang',
                  value: ThemeMode.light,
                  groupValue: currentMode,
                  onSelect: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _OptionTile<ThemeMode>(
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

  void _showNavigationPicker(
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
                _OptionTile<NavigationApp>(
                  title: 'Google Maps',
                  subtitle: 'Mode sepeda motor',
                  value: NavigationApp.googleMaps,
                  groupValue: currentApp,
                  onSelect: (app) {
                    ref.read(navigationAppProvider.notifier).setApp(app);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _OptionTile<NavigationApp>(
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

  void _showBackupOptions(BuildContext context, WidgetRef ref) {
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
                    'Cadangan',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: tokens.space8),
                _ActionTile(
                  title: 'Ekspor semua data',
                  subtitle: 'Spot dan riwayat order',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleExport(context, ref, BackupScope.all);
                  },
                ),
                _ActionTile(
                  title: 'Ekspor hanya spot',
                  subtitle: 'Tanpa riwayat order',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleExport(context, ref, BackupScope.spotsOnly);
                  },
                ),
                _ActionTile(
                  title: 'Impor data (JSON)',
                  subtitle: 'Gabungkan dari berkas cadangan',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleImport(context, ref);
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

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    BackupScope scope,
  ) async {
    try {
      final service = ref.read(backupServiceProvider);
      await service.exportAndShare(scope: scope);
    } catch (e) {
      if (!context.mounted) return;
      final tokens = context.tokens;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengekspor data: $e',
            style: TextStyle(color: tokens.actionOnFill),
          ),
          backgroundColor: tokens.danger,
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(backupServiceProvider);
      final summary = await service.importFromFile();
      if (!context.mounted || summary == null) return;

      ref.invalidate(activeSpotsStreamProvider);
      ref.invalidate(peakIndexProvider);

      final tokens = context.tokens;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              side: BorderSide(color: tokens.border, width: tokens.borderWidth),
            ),
            title: Text(
              'Ringkasan Impor',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            content: Text(
              summary.formatSummary(),
              style: TextStyle(fontSize: 14.0, color: tokens.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Tutup',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      final tokens = context.tokens;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is InvalidBackupException
                ? e.message
                : 'Gagal mengimpor data: $e',
            style: TextStyle(color: tokens.actionOnFill),
          ),
          backgroundColor: tokens.danger,
        ),
      );
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48.0),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.space4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64.0),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.space4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onSelect,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onSelect(value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: tokens.space4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 20.0, color: tokens.textPrimary),
          ],
        ),
      ),
    );
  }
}
