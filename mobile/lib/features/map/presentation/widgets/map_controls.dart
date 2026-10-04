import 'package:flutter/material.dart';
import '../../../../app/theme/tokens.dart';

class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: tokens.minTouchTarget,
      height: tokens.minTouchTarget,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.border, width: tokens.borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Center(
            child: Icon(
              Icons.my_location,
              size: 24.0,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.bottomOffset = 8.0});

  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(left: tokens.space12, bottom: bottomOffset),
      child: Text(
        '© OpenStreetMap, © CARTO',
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w400,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class NearbyListButton extends StatelessWidget {
  const NearbyListButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: tokens.minTouchTarget,
      height: tokens.minTouchTarget,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.border, width: tokens.borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Center(
            child: Icon(
              Icons.format_list_bulleted,
              size: 24.0,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
