import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sync/presentation/sync_providers.dart';

Future<void> showLogoutConfirmationDialog(
  BuildContext context,
  WidgetRef ref,
  int dirtyCount,
) async {
  final tokens = context.tokens;
  final session = ref.read(sessionStateProvider);

  final String contentText;
  if (dirtyCount > 0) {
    contentText =
        'Ada $dirtyCount perubahan yang belum tersinkron. Jika keluar sekarang, perubahan ini tetap tersimpan di perangkat ini tetapi belum ada di server.';
  } else {
    final email = session.userEmail;
    contentText = email != null && email.isNotEmpty
        ? 'Keluar dari akun $email? Data lokal akan tetap tersimpan di perangkat ini.'
        : 'Keluar akun? Data lokal akan tetap tersimpan di perangkat ini.';
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: BorderSide(color: tokens.border, width: tokens.borderWidth),
        ),
        title: Text(
          'Keluar akun',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        content: Text(
          contentText,
          style: TextStyle(fontSize: 14.0, color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Keluar',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: tokens.danger,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed == true && context.mounted) {
    await ref.read(sessionStateProvider.notifier).logout();
  }
}

Future<void> handleManualSync(BuildContext context, WidgetRef ref) async {
  final success = await ref.read(syncManualProvider.notifier).syncNow();
  if (!context.mounted) return;
  final tokens = context.tokens;

  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sinkronisasi selesai',
          style: TextStyle(color: tokens.actionOnFill),
        ),
        backgroundColor: tokens.actionFill,
        duration: const Duration(seconds: 2),
      ),
    );
  } else {
    final error =
        ref.read(syncManualProvider).errorMessage ?? 'Sinkronisasi gagal';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error, style: TextStyle(color: tokens.actionOnFill)),
        backgroundColor: tokens.danger,
      ),
    );
  }
}
