import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';
import '../../features/spots/domain/category.dart';

class CategoryMarker extends StatelessWidget {
  const CategoryMarker({
    super.key,
    required this.category,
    this.name,
    this.isSelected = false,
    this.showLabel = false,
    this.onTap,
  });

  final Category category;
  final String? name;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = isSelected ? 44.0 : 36.0;
    final iconSize = isSelected ? 22.0 : 18.0;

    final markerColor = category == Category.shopeefood
        ? tokens.markerShopeeFood
        : tokens.markerSpx;

    final iconData = category == Category.shopeefood
        ? Icons.restaurant
        : Icons.inventory_2_outlined;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showLabel && name != null && name!.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxWidth: 140.0),
                margin: EdgeInsets.only(bottom: tokens.space4),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space8,
                  vertical: tokens.space4,
                ),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.border,
                    width: tokens.borderWidth,
                  ),
                ),
                child: Text(
                  name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
            // Marker pin circle
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.surface, width: 2.0),
              ),
              child: Center(
                child: Icon(iconData, size: iconSize, color: tokens.markerIcon),
              ),
            ),
            // Small triangle tail pointing down (6 dp height)
            ClipPath(
              clipper: _TriangleClipper(),
              child: Container(width: 10.0, height: 6.0, color: markerColor),
            ),
          ],
        ),
      ),
    );
  }
}

class ClusterMarkerWidget extends StatelessWidget {
  const ClusterMarkerWidget({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.0,
        height: 36.0,
        decoration: BoxDecoration(
          color: tokens.actionFill,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.surface, width: 2.0),
        ),
        child: Center(
          child: Text(
            count > 999 ? '999+' : count.toString(),
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: tokens.actionOnFill,
            ),
          ),
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_TriangleClipper oldClipper) => false;
}
