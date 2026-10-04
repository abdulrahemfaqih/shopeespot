import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/geo/distance_format.dart';
import '../../../../core/geo/haversine.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/time/clock.dart';
import '../../../peak/domain/peak_index.dart';
import '../../../peak/presentation/peak_provider.dart';
import '../../domain/category.dart';
import '../../domain/nearby_calculator.dart';
import '../../domain/spot.dart';
import '../spots_providers.dart';

class NearbySheet extends ConsumerStatefulWidget {
  const NearbySheet({
    super.key,
    required this.onSpotSelected,
    this.initialRadius = NearbyRadius.oneKm,
    this.initialSortOrder = NearbySortOrder.distance,
    this.scrollController,
  });

  final ValueChanged<Spot> onSpotSelected;
  final NearbyRadius initialRadius;
  final NearbySortOrder initialSortOrder;
  final ScrollController? scrollController;

  @override
  ConsumerState<NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends ConsumerState<NearbySheet> {
  late NearbyRadius _radius;
  late NearbySortOrder _sortOrder;
  UserLocation? _referenceLocation;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
    _sortOrder = widget.initialSortOrder;

    final locState = ref.read(userLocationProvider);
    if (locState is LocationAvailable) {
      _referenceLocation = locState.location;
    }
  }

  void _checkLocationUpdate(UserLocation newLocation) {
    if (_referenceLocation == null) {
      _referenceLocation = newLocation;
      return;
    }

    // Only update reference location and recompute if user moved >= 50m
    final distKm = haversine(
      _referenceLocation!.latitude,
      _referenceLocation!.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );
    if (distKm * 1000.0 >= 50.0) {
      setState(() {
        _referenceLocation = newLocation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spots = ref.watch(filteredSpotsProvider);
    final peakIndex =
        ref.watch(peakIndexProvider).valueOrNull ?? const PeakIndex();
    final clock = ref.watch(clockProvider);
    final locationState = ref.watch(userLocationProvider);

    if (locationState is LocationAvailable) {
      _checkLocationUpdate(locationState.location);
    }

    final now = clock.now();

    List<NearbySpotItem> items = const [];
    String? emptyMessage;

    if (_referenceLocation == null) {
      if (locationState is LocationDenied) {
        emptyMessage = 'Izin lokasi diperlukan untuk melihat spot terdekat.';
      } else if (locationState is LocationServiceDisabled) {
        emptyMessage = 'GPS belum aktif di perangkat.';
      } else {
        emptyMessage = 'Menunggu sinyal GPS...';
      }
    } else {
      items = computeNearbySpots(
        spots: spots,
        userLat: _referenceLocation!.latitude,
        userLng: _referenceLocation!.longitude,
        radiusKm: _radius.km,
        sortOrder: _sortOrder,
        peakIndex: peakIndex,
        now: now,
      );

      if (items.isEmpty) {
        emptyMessage = 'Tidak ada spot dalam radius ini.';
      }
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
            // Drag handle
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
            // Header: Radius segmented control and sort order button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space16,
                vertical: tokens.space8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RadiusSegmentedControl(
                    selectedRadius: _radius,
                    onChanged: (newRadius) {
                      setState(() => _radius = newRadius);
                    },
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _sortOrder = _sortOrder == NearbySortOrder.distance
                            ? NearbySortOrder.orderCount
                            : NearbySortOrder.distance;
                      });
                    },
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space8,
                        vertical: tokens.space4,
                      ),
                      child: Text(
                        _sortOrder.label,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1.0,
              thickness: tokens.borderWidth,
              color: tokens.border,
            ),
            // Body: Empty message or Spot rows
            if (emptyMessage != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space16,
                  vertical: tokens.space24,
                ),
                child: Center(
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  controller: widget.scrollController,
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1.0,
                    thickness: tokens.borderWidth,
                    color: tokens.border,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NearbySpotRow(
                      item: item,
                      onTap: () => widget.onSpotSelected(item.spot),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadiusSegmentedControl extends StatelessWidget {
  const _RadiusSegmentedControl({
    required this.selectedRadius,
    required this.onChanged,
  });

  final NearbyRadius selectedRadius;
  final ValueChanged<NearbyRadius> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: 36.0,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.border, width: tokens.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: NearbyRadius.values.map((radius) {
          final isSelected = radius == selectedRadius;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(radius),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: tokens.space12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? tokens.actionFill : Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radiusSm - 1),
              ),
              child: Text(
                radius.label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? tokens.actionOnFill : tokens.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NearbySpotRow extends StatelessWidget {
  const _NearbySpotRow({required this.item, required this.onTap});

  final NearbySpotItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isShopeeFood = item.spot.category == Category.shopeefood;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64.0),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space16,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            // Category icon (20 dp, without circle wrapper)
            Icon(
              isShopeeFood ? Icons.restaurant : Icons.inventory_2_outlined,
              size: 20.0,
              color: isShopeeFood ? tokens.markerShopeeFood : tokens.markerSpx,
            ),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    item.isPeakNow
                        ? '${formatDistance(item.distanceKm)} · Ramai sekarang'
                        : formatDistance(item.distanceKm),
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
