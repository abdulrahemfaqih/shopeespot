import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/location/location_service.dart';
import '../../spots/domain/spot.dart';
import '../../spots/presentation/spot_form_screen.dart';
import '../../spots/presentation/spots_providers.dart';
import '../../spots/presentation/widgets/nearby_sheet.dart';
import '../domain/clustering.dart';
import 'map_controller.dart';
import 'widgets/main_map_view.dart';

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
    } catch (_) {}
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
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

  void _showPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Izin lokasi diperlukan untuk fitur ini.'),
        action: SnackBarAction(
          label: 'Buka pengaturan',
          onPressed: () {
            ref.read(locationServiceProvider).openAppSettings();
          },
        ),
      ),
    );
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
      _showPermissionSnackBar();
    } else if (locationState is LocationServiceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GPS belum aktif. Aktifkan lokasi di perangkat.'),
          action: SnackBarAction(
            label: 'Buka pengaturan',
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
      _showPermissionSnackBar();
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

  Future<void> _onNearbyListPressed() async {
    final selectedSpot = await showModalBottomSheet<Spot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => NearbySheet(
        onSpotSelected: (spot) => Navigator.of(sheetContext).pop(spot),
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

  void _onClusterTap(MapClusterItem cluster, double initialZoom) {
    final targetZoom = ((_currentCamera?.zoom ?? initialZoom) + 2.0).clamp(
      5.0,
      19.0,
    );
    _mapController.move(
      LatLng(cluster.latitude, cluster.longitude),
      targetZoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(mapCameraProvider);
    final spots = ref.watch(filteredSpotsProvider);
    final allSpots =
        ref.watch(activeSpotsStreamProvider).value ?? const <Spot>[];

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
          error: (error, stackTrace) => _renderMap(
            center: const LatLng(defaultLat, defaultLng),
            zoom: defaultZoom,
            spots: spots,
            allSpots: allSpots,
          ),
          data: (savedCamera) => _renderMap(
            center: savedCamera.center,
            zoom: savedCamera.zoom,
            spots: spots,
            allSpots: allSpots,
          ),
        ),
      ),
    );
  }

  Widget _renderMap({
    required LatLng center,
    required double zoom,
    required List<Spot> spots,
    required List<Spot> allSpots,
  }) {
    return MainMapView(
      mapController: _mapController,
      initialCenter: center,
      initialZoom: zoom,
      spots: spots,
      allSpots: allSpots,
      selectedSpot: _selectedSpot,
      sheetExtent: _sheetExtent,
      currentCamera: _currentCamera,
      onMapReady: (cam) => setState(() => _currentCamera = cam),
      onPositionChanged: (cam, gesture) =>
          setState(() => _onPositionChanged(cam, gesture)),
      onTapMap: () {
        if (_selectedSpot != null) {
          setState(() {
            _selectedSpot = null;
            _sheetExtent = 0.0;
          });
        }
      },
      onSpotTap: (spot) {
        setState(() {
          _selectedSpot = spot;
          _sheetExtent = 0.28;
        });
      },
      onClusterTap: (cluster) => _onClusterTap(cluster, zoom),
      onQuickPinPressed: _onQuickPinPressed,
      onMyLocationPressed: _onMyLocationPressed,
      onNearbyListPressed: _onNearbyListPressed,
      onDetailExtentChanged: (extent) => setState(() => _sheetExtent = extent),
      onDetailClose: () => setState(() {
        _selectedSpot = null;
        _sheetExtent = 0.0;
      }),
    );
  }
}
