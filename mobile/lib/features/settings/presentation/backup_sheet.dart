import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../backup/domain/backup_models.dart';
import '../../backup/presentation/backup_providers.dart';
import '../../peak/presentation/peak_provider.dart';
import '../../spots/presentation/spots_providers.dart';
import 'settings_tiles.dart';

void showBackupOptions(BuildContext context, WidgetRef ref) {
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
              ActionTile(
                title: 'Ekspor semua data',
                subtitle: 'Spot dan riwayat order',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _handleExport(context, ref, BackupScope.all);
                },
              ),
              ActionTile(
                title: 'Ekspor hanya spot',
                subtitle: 'Tanpa riwayat order',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _handleExport(context, ref, BackupScope.spotsOnly);
                },
              ),
              ActionTile(
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
          e is InvalidBackupException ? e.message : 'Gagal mengimpor data: $e',
          style: TextStyle(color: tokens.actionOnFill),
        ),
        backgroundColor: tokens.danger,
      ),
    );
  }
}
