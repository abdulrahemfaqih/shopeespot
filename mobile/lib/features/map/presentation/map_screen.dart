import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/env.dart';
import '../../../core/location/location_provider.dart';
import '../../../core/location/location_service.dart';
import '../../spots/domain/spot.dart';
import '../../spots/presentation/spot_form_screen.dart';
import '../../spots/presentation/spots_providers.dart';
import 'map_controller.dart';
import 'widgets/filter_bar.dart';
import 'widgets/gps_layer.dart';
import 'widgets/map_controls.dart';
import 'widgets/quick_pin_fab.dart';
import '../../spots/presentation/widgets/nearby_sheet.dart';
import '../../spots/presentation/widgets/spot_detail_sheet.dart';
import 'widgets/spot_markers_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  Timer? _debounceTimer;
  MapCamera? _currentCamera;
  Spot? _selectedSpot;
  double _sheetExtent = 0.28;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _enableWakelock();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Gracefully ignore on platforms/environments without wakelock support
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Gracefully ignore
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    _disableWakelock();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCamera = camera;

    if (!hasGesture) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref
          .read(mapCameraProvider.notifier)
          .saveCameraPosition(camera.center, camera.zoom);
    });
  }

  void _onMyLocationPressed() {
    final locationState = ref.read(userLocationProvider);

    if (locationState is LocationAvailable) {
      final loc = locationState.location;
      _mapController.move(
        LatLng(loc.latitude, loc.longitude),
        _mapController.camera.zoom.clamp(14.0, 18.0),
      );
    } else if (locationState is LocationDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izin lokasi diperlukan untuk fitur ini.'),
          action: SnackBarAction(
            label: 'Pengaturan',
            onPressed: () {
              ref.read(locationServiceProvider).openAppSettings();
            },
          ),
        ),
      );
    } else if (locationState is LocationServiceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GPS belum aktif. Aktifkan lokasi di perangkat.'),
          action: SnackBarAction(
            label: 'Pengaturan',
            onPressed: () {
              ref.read(locationServiceProvider).openLocationSettings();
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Menunggu sinyal GPS...')));
    }
  }

  Future<void> _onQuickPinPressed() async {
    final locationState = ref.read(userLocationProvider);
    double? lat;
    double? lng;

    if (locationState is LocationAvailable) {
      lat = locationState.location.latitude;
      lng = locationState.location.longitude;
    } else if (locationState is LocationDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Izin lokasi diperlukan untuk mengambil posisi otomatis.',
          ),
          action: SnackBarAction(
            label: 'Pengaturan',
            onPressed: () {
              ref.read(locationServiceProvider).openAppSettings();
            },
          ),
        ),
      );
      return;
    } else {
      final lastPos = await ref
          .read(locationServiceProvider)
          .getLastKnownPosition();
      if (lastPos != null) {
        lat = lastPos.latitude;
        lng = lastPos.longitude;
      } else {
        final cameraCenter =
            _currentCamera?.center ?? const LatLng(defaultLat, defaultLng);
        lat = cameraCenter.latitude;
        lng = cameraCenter.longitude;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS belum dapat, menggunakan posisi tengah peta.'),
            ),
          );
        }
      }
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) =>
            SpotFormScreen(initialLatitude: lat!, initialLongitude: lng!),
      ),
    );
  }

  String _getTileUrl(Brightness brightness) {
    final style = brightness == Brightness.dark ? 'dark_all' : 'light_all';
    final keyParam = Env.cartoApiKey.isNotEmpty
        ? '?key=${Env.cartoApiKey}'
        : '';
    return 'https://basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}{r}.png$keyParam';
  }

  Future<void> _onNearbyListPressed() async {
    if (_selectedSpot != null) {
      setState(() {
        _selectedSpot = null;
        _sheetExtent = 0.0;
      });
    }

    final selectedSpot = await showModalBottomSheet<Spot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => NearbySheet(
        onSpotSelected: (spot) {
          Navigator.of(sheetContext).pop(spot);
        },
      ),
    );

    if (selectedSpot != null && mounted) {
      _mapController.move(
        LatLng(selectedSpot.latitude, selectedSpot.longitude),
        _mapController.camera.zoom.clamp(15.0, 19.0),
      );
      setState(() {
        _selectedSpot = selectedSpot;
        _sheetExtent = 0.28;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(mapCameraProvider);
    final spots = ref.watch(filteredSpotsProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Keep _selectedSpot in sync if it was edited or deleted
    if (_selectedSpot != null) {
      final current = spots.where((s) => s.id == _selectedSpot!.id).firstOrNull;
      if (current == null) {
        _selectedSpot = null;
        _sheetExtent = 0.0;
      } else if (current != _selectedSpot) {
        _selectedSpot = current;
      }
    }

    return PopScope(
      canPop: _selectedSpot == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedSpot != null) {
          setState(() {
            _selectedSpot = null;
            _sheetExtent = 0.0;
          });
        }
      },
      child: Scaffold(
        body: cameraState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _buildMap(
            initialCenter: const LatLng(defaultLat, defaultLng),
            initialZoom: defaultZoom,
            spots: spots,
            theme: theme,
            tokens: tokens,
          ),
          data: (savedCamera) => _buildMap(
            initialCenter: savedCamera.center,
            initialZoom: savedCamera.zoom,
            spots: spots,
            theme: theme,
            tokens: tokens,
          ),
        ),
      ),
    );
  }

  Widget _buildMap({
    required LatLng initialCenter,
    required double initialZoom,
    required List<Spot> spots,
    required ThemeData theme,
    required AppTokens tokens,
  }) {
    final isRetina = MediaQuery.of(context).devicePixelRatio > 1.5;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSheetOpen = _selectedSpot != null;
    final sheetOffset = isSheetOpen ? _sheetExtent * screenHeight : 0.0;
    final hideControls = isSheetOpen && _sheetExtent > 0.5;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            minZoom: 5.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              setState(() {
                _currentCamera = _mapController.camera;
              });
            },
            onPositionChanged: (camera, hasGesture) {
              setState(() {
                _onPositionChanged(camera, hasGesture);
              });
            },
            onTap: (tapPosition, point) {
              if (_selectedSpot != null) {
                setState(() {
                  _selectedSpot = null;
                  _sheetExtent = 0.0;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _getTileUrl(theme.brightness),
              userAgentPackageName: 'com.example.shopeespot',
              retinaMode: isRetina,
            ),
            if (_currentCamera != null)
              SpotMarkersLayer(
                spots: spots,
                camera: _currentCamera!,
                selectedSpotId: _selectedSpot?.id,
                onSpotTap: (spot) {
                  setState(() {
                    _selectedSpot = spot;
                    _sheetExtent = 0.28;
                  });
                },
                onClusterTap: (cluster) {
                  final targetZoom =
                      ((_currentCamera?.zoom ?? initialZoom) + 2.0).clamp(
                        5.0,
                        19.0,
                      );
                  _mapController.move(
                    LatLng(cluster.latitude, cluster.longitude),
                    targetZoom,
                  );
                },
              ),
            const GpsLayer(),
          ],
        ),
        if (!hideControls) ...[
          // Quick Pin FAB (floating right bottom)
          Positioned(
            right: tokens.space16,
            bottom: tokens.space24 + sheetOffset,
            child: QuickPinFab(onPressed: _onQuickPinPressed),
          ),
          // My Location Button (floating right, above Quick Pin FAB)
          Positioned(
            right: tokens.space16,
            bottom: tokens.space24 + 56.0 + tokens.space12 + sheetOffset,
            child: MyLocationButton(onPressed: _onMyLocationPressed),
          ),
          // Nearby List Button (floating left bottom)
          Positioned(
            left: tokens.space16,
            bottom: tokens.space24 + sheetOffset,
            child: NearbyListButton(onPressed: _onNearbyListPressed),
          ),
        ],
        // CARTO and OSM Attribution (always visible bottom left)
        Positioned(
          left: 0,
          bottom: (isSheetOpen && !hideControls) ? 8.0 + sheetOffset : 8.0,
          child: const MapAttribution(),
        ),
        // Filter Bar (floating top, safeArea + 8)
        Positioned(
          top: MediaQuery.paddingOf(context).top + tokens.space8,
          left: 0,
          right: 0,
          child: const FilterBar(),
        ),
        // Detail Sheet
        if (_selectedSpot != null)
          Positioned.fill(
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() {
                  _sheetExtent = notification.extent;
                });
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.28,
                minChildSize: 0.15,
                maxChildSize: 0.75,
                snap: true,
                snapSizes: const [0.28, 0.75],
                builder: (context, scrollController) {
                  return SpotDetailSheet(
                    spot: _selectedSpot!,
                    scrollController: scrollController,
                    onClose: () {
                      setState(() {
                        _selectedSpot = null;
                        _sheetExtent = 0.0;
                      });
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
