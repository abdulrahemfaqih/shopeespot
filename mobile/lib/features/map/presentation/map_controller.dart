import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefLastLat = 'map_last_lat';
const String prefLastLng = 'map_last_lng';
const String prefLastZoom = 'map_last_zoom';

const double defaultLat = -6.1754;
const double defaultLng = 106.8272;
const double defaultZoom = 15.0;

class MapCameraState {
  const MapCameraState({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

final mapCameraProvider =
    AsyncNotifierProvider<MapCameraNotifier, MapCameraState>(
      MapCameraNotifier.new,
    );

class MapCameraNotifier extends AsyncNotifier<MapCameraState> {
  SharedPreferences? _prefs;

  @override
  Future<MapCameraState> build() async {
    _prefs ??= await SharedPreferences.getInstance();
    final lat = _prefs?.getDouble(prefLastLat) ?? defaultLat;
    final lng = _prefs?.getDouble(prefLastLng) ?? defaultLng;
    final zoom = _prefs?.getDouble(prefLastZoom) ?? defaultZoom;

    return MapCameraState(center: LatLng(lat, lng), zoom: zoom);
  }

  Future<void> saveCameraPosition(LatLng center, double zoom) async {
    state = AsyncData(MapCameraState(center: center, zoom: zoom));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble(prefLastLat, center.latitude);
    await _prefs?.setDouble(prefLastLng, center.longitude);
    await _prefs?.setDouble(prefLastZoom, zoom);
  }
}
