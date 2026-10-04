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
import 'spot_detail_sections.dart';

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
            SpotDetailExtendedSection(
              spot: spot,
              ordersToday: ordersTodayAsync.value ?? 0,
              onDelete: () => _onDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
