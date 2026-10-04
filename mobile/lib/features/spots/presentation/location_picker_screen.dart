import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/env.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/category_marker.dart';
import '../../map/presentation/widgets/map_controls.dart';
import '../domain/category.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.initialPosition,
    this.category = Category.shopeefood,
  });

  final LatLng initialPosition;
  final Category category;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialPosition;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _getTileUrl(Brightness brightness) {
    final style = brightness == Brightness.dark
        ? 'alidade_smooth_dark'
        : 'alidade_smooth';
    final key = Env.stadiaApiKey;
    final keyParam = key.isNotEmpty ? '?api_key=$key' : '';
    return 'https://tiles.stadiamaps.com/tiles/$style/{z}/{x}/{y}{r}.png$keyParam';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isRetina = MediaQuery.of(context).devicePixelRatio > 1.5;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Moving map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 16.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                setState(() {
                  _currentCenter = camera.center;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(theme.brightness),
                userAgentPackageName: 'com.example.shopeespot',
                retinaMode: isRetina,
              ),
            ],
          ),

          // 2. Fixed Pin at screen center (tip points exactly to center)
          Center(
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(0.0, -0.5),
                child: SizedBox(
                  width: 44.0,
                  height: 50.0,
                  child: CategoryMarker(
                    category: widget.category,
                    isSelected: true,
                    showLabel: false,
                  ),
                ),
              ),
            ),
          ),

          // 3. Top instruction banner with coordinates
          Positioned(
            top: MediaQuery.paddingOf(context).top + tokens.space16,
            left: tokens.space16,
            right: tokens.space16,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space16,
                vertical: tokens.space12,
              ),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.border,
                  width: tokens.borderWidth,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Geser peta untuk mengatur posisi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Stadia Maps and OSM Attribution
          const Positioned(left: 0, bottom: 88.0, child: MapAttribution()),

          // 5. Bottom action bar with buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(
                  top: BorderSide(
                    color: tokens.border,
                    width: tokens.borderWidth,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(tokens.space16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton.outline(
                          label: 'Batal',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: AppButton.primary(
                          label: 'Simpan posisi ini',
                          onPressed: () =>
                              Navigator.of(context).pop(_currentCenter),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
