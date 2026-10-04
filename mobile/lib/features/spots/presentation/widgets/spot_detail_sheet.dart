import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/geo/distance_format.dart';
import '../../../../core/geo/haversine.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/navigation/navigation_launcher.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/day_type.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../orders/presentation/orders_providers.dart';
import '../../../peak/domain/peak_index.dart';
import '../../../peak/presentation/peak_provider.dart';
import '../../domain/spot.dart';
import '../spot_form_screen.dart';
import '../spots_providers.dart';

class SpotDetailSheet extends ConsumerWidget {
  const SpotDetailSheet({
    super.key,
    required this.spot,
    required this.onClose,
    this.onRecordOrder,
    this.onNavigate,
    this.scrollController,
  });

  final Spot spot;
  final VoidCallback onClose;
  final VoidCallback? onRecordOrder;
  final VoidCallback? onNavigate;
  final ScrollController? scrollController;

  static String formatVerificationDate(DateTime? dt) {
    if (dt == null) return 'Belum diverifikasi';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = dt.toLocal();
    return 'Terakhir diverifikasi ${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDays(List<int> days) {
    if (days.length == 7) return 'Setiap hari';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Hari kerja';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Akhir pekan';
    }
    const dayNames = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };
    return days.map((d) => dayNames[d] ?? '$d').join(', ');
  }

  Future<void> _onRecordOrder(BuildContext context, WidgetRef ref) async {
    if (onRecordOrder != null) {
      onRecordOrder!();
      return;
    }

    try {
      HapticFeedback.lightImpact().ignore();
    } catch (_) {}

    final orderRepo = ref.read(orderRepositoryProvider);
    final order = await orderRepo.recordOrder(spotId: spot.id);
    ref.invalidate(spotOrdersCountTodayProvider(spot.id));
    ref.invalidate(activeSpotsStreamProvider);
    ref.invalidate(peakIndexProvider);

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Order dicatat'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Batal',
          onPressed: () async {
            await orderRepo.softDeleteOrder(order.id);
            ref.invalidate(spotOrdersCountTodayProvider(spot.id));
            ref.invalidate(activeSpotsStreamProvider);
            ref.invalidate(peakIndexProvider);
          },
        ),
      ),
    );
  }

  Future<void> _onEdit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpotFormScreen(
          spot: spot,
          initialLatitude: spot.latitude,
          initialLongitude: spot.longitude,
        ),
      ),
    );
  }

  Future<void> _onNavigate(BuildContext context, WidgetRef ref) async {
    if (onNavigate != null) {
      onNavigate!();
      return;
    }
    final app = ref.read(navigationAppProvider);
    final launcher = ref.read(navigationLauncherProvider);
    final success = await launcher.launch(
      latitude: spot.latitude,
      longitude: spot.longitude,
      app: app,
    );
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka aplikasi navigasi.')),
      );
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        title: Text(
          'Hapus spot?',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        content: Text(
          'Spot ini beserta seluruh riwayat ordernya akan dihapus.',
          style: TextStyle(fontSize: 14.0, color: tokens.textSecondary),
        ),
        actions: [
          AppButton.text(
            label: 'Batal',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton.danger(
            label: 'Hapus',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(spotRepositoryProvider).softDeleteSpot(spot.id);
      onClose();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Spot berhasil dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final locationState = ref.watch(userLocationProvider);
    final ordersTodayAsync = ref.watch(spotOrdersCountTodayProvider(spot.id));

    String distanceCaption = spot.category.label;
    if (locationState is LocationAvailable) {
      final loc = locationState.location;
      final distance = haversine(
        loc.latitude,
        loc.longitude,
        spot.latitude,
        spot.longitude,
      );
      distanceCaption = '${spot.category.label} · ${formatDistance(distance)}';
    }

    final peakIndex = ref.watch(peakIndexProvider).value ?? const PeakIndex();
    final clock = ref.watch(clockProvider);
    final dayType = DayType.fromDateTime(clock.now());
    final peakHoursSummary = peakIndex.effectiveRangesSummary(spot, dayType);

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
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Handle drag bar (32 x 4 dp)
            Center(
              child: Container(
                margin: EdgeInsets.only(
                  top: tokens.space8,
                  bottom: tokens.space8,
                ),
                width: 32.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            // Ringkas Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    distanceCaption,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    peakHoursSummary,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space16),

                  // Button row: Dapat order di sini (melebar), Arahkan, Edit
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.primary(
                          label: 'Dapat order di sini',
                          onPressed: () => _onRecordOrder(context, ref),
                        ),
                      ),
                      SizedBox(width: tokens.space8),
                      AppButton.outline(
                        label: 'Arahkan',
                        onPressed: () => _onNavigate(context, ref),
                      ),
                      SizedBox(width: tokens.space8),
                      AppButton.outline(
                        label: 'Edit',
                        onPressed: () => _onEdit(context),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space16),
                ],
              ),
            ),

            // Diperluas Section (separated by 1 dp divider, no cards in cards)
            Divider(
              color: tokens.border,
              height: tokens.borderWidth,
              thickness: tokens.borderWidth,
            ),

            // 1. Hari ini: N order
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Text(
                'Hari ini: ${ordersTodayAsync.value ?? 0} order',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),

            Divider(
              color: tokens.border,
              height: tokens.borderWidth,
              thickness: tokens.borderWidth,
            ),

            // 2. Catatan lapangan
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan lapangan',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    spot.notes.isNotEmpty ? spot.notes : 'Tidak ada catatan',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: spot.notes.isNotEmpty
                          ? tokens.textPrimary
                          : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              color: tokens.border,
              height: tokens.borderWidth,
              thickness: tokens.borderWidth,
            ),

            // 3. Jam ramai manual
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jam ramai manual',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  if (spot.peakHours.isEmpty)
                    Text(
                      'Tidak ada jam ramai manual',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: tokens.textSecondary,
                      ),
                    )
                  else
                    ...spot.peakHours.map(
                      (r) => Padding(
                        padding: EdgeInsets.symmetric(vertical: tokens.space4),
                        child: Text(
                          '${formatDays(r.days)}: ${formatTime(r.start)} - ${formatTime(r.end)}',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Divider(
              color: tokens.border,
              height: tokens.borderWidth,
              thickness: tokens.borderWidth,
            ),

            // 4. Terakhir diverifikasi
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Text(
                formatVerificationDate(spot.lastVerifiedAt),
                style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
              ),
            ),

            Divider(
              color: tokens.border,
              height: tokens.borderWidth,
              thickness: tokens.borderWidth,
            ),

            // 5. Hapus (tombol teks danger di paling bawah)
            Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: AppButton.danger(
                label: 'Hapus spot',
                isFullWidth: true,
                onPressed: () => _onDelete(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
