import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/geo/distance_format.dart';
import '../../domain/category.dart';
import '../../domain/nearby_calculator.dart';

class RadiusSegmentedControl extends StatelessWidget {
  const RadiusSegmentedControl({
    super.key,
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

class NearbySpotRow extends StatelessWidget {
  const NearbySpotRow({super.key, required this.item, required this.onTap});

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
