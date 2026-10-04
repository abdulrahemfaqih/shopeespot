import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_provider.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/navigation/navigation_launcher.dart';
import '../../auth/domain/session_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sync/presentation/sync_providers.dart';
import 'account_dialog.dart';
import 'backup_sheet.dart';
import 'preferences_sheet.dart';
import 'settings_tiles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final themeMode = ref.watch(themeModeProvider);
    final navApp = ref.watch(navigationAppProvider);
    final session = ref.watch(sessionStateProvider);

    final lastSynced = ref.watch(lastSyncedAtProvider).value;
    final dirtyCount = ref.watch(totalDirtyCountProvider);
    final isSyncing = ref.watch(syncManualProvider).isSyncing;

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
          SettingsRow(
            title: 'Tema',
            subtitle: _themeModeLabel(themeMode),
            onTap: () => showThemePicker(context, ref, themeMode),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 2. Navigasi
          SettingsRow(
            title: 'Aplikasi navigasi',
            subtitle: navApp.label,
            onTap: () => showNavigationPicker(context, ref, navApp),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 3. Cadangan
          SettingsRow(
            title: 'Cadangan',
            subtitle: 'Ekspor dan impor data (JSON)',
            onTap: () => showBackupOptions(context, ref),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 4. Sinkronisasi
          SettingsRow(
            title: 'Sinkronisasi',
            subtitle: formatSyncSubtitle(
              lastSyncedAt: lastSynced,
              dirtyCount: dirtyCount,
              isExpired: session.isExpired,
            ),
            trailing: _buildSyncTrailing(
              context,
              ref,
              isSyncing: isSyncing,
              session: session,
            ),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 5. Akun
          SettingsRow(
            title: 'Akun',
            subtitle: _accountSubtitle(session),
            trailing: _buildAccountTrailing(
              context,
              ref,
              session: session,
              dirtyCount: dirtyCount,
            ),
          ),
          Divider(
            height: 1.0,
            thickness: tokens.borderWidth,
            color: tokens.border,
          ),

          // 6. Versi aplikasi
          const SettingsRow(title: 'Versi aplikasi', subtitle: '1.0.0'),
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

  static String _accountSubtitle(SessionState session) {
    if (session.isExpired) {
      final email = session.userEmail;
      return email != null && email.isNotEmpty
          ? '$email · Sesi berakhir'
          : 'Sesi berakhir';
    }
    if (session.isAuthenticated) {
      return session.userEmail ?? 'Sesi aktif';
    }
    return 'Belum masuk';
  }

  Widget? _buildSyncTrailing(
    BuildContext context,
    WidgetRef ref, {
    required bool isSyncing,
    required SessionState session,
  }) {
    final tokens = context.tokens;

    if (isSyncing) {
      return SizedBox(
        width: 24.0,
        height: 24.0,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: tokens.actionFill,
          ),
        ),
      );
    }

    if (session.isExpired) {
      return TextButton(
        onPressed: () => context.push('/login'),
        child: Text(
          'Masuk lagi',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: tokens.actionFill,
          ),
        ),
      );
    }

    if (session.isAuthenticated) {
      return TextButton(
        onPressed: () => handleManualSync(context, ref),
        child: Text(
          'Sinkronkan sekarang',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: tokens.actionFill,
          ),
        ),
      );
    }

    return null;
  }

  Widget? _buildAccountTrailing(
    BuildContext context,
    WidgetRef ref, {
    required SessionState session,
    required int dirtyCount,
  }) {
    final tokens = context.tokens;

    if (session.isAuthenticated || session.isExpired) {
      return TextButton(
        onPressed: () => showLogoutConfirmationDialog(context, ref, dirtyCount),
        child: Text(
          'Keluar',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: tokens.danger,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: () => context.push('/login'),
      child: Text(
        'Masuk',
        style: TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          color: tokens.actionFill,
        ),
      ),
    );
  }
}
