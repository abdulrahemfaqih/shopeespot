import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy, timestamp);
}

sealed class LocationState {
  const LocationState();
}

class LocationWaiting extends LocationState {
  const LocationWaiting();
}

class LocationAvailable extends LocationState {
  const LocationAvailable(this.location);
  final UserLocation location;
}

class LocationDenied extends LocationState {
  const LocationDenied({this.isPermanent = false});
  final bool isPermanent;
}

class LocationServiceDisabled extends LocationState {
  const LocationServiceDisabled();
}

/// Abstract data source for Geolocator to allow testing without platform channels.
abstract class LocationDataSource {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position?> getLastKnownPosition();
  Future<Position> getCurrentPosition({LocationSettings? locationSettings});
  Stream<Position> getPositionStream({LocationSettings? locationSettings});
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class DefaultLocationDataSource implements LocationDataSource {
  const DefaultLocationDataSource();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Geolocator.getCurrentPosition(locationSettings: locationSettings);

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      Geolocator.getPositionStream(locationSettings: locationSettings);

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

class LocationService {
  LocationService({LocationDataSource? dataSource})
    : _dataSource = dataSource ?? const DefaultLocationDataSource();

  final LocationDataSource _dataSource;

  Future<LocationPermissionStatus> checkAndRequestPermission() async {
    final serviceEnabled = await _dataSource.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    var permission = await _dataSource.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _dataSource.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    return LocationPermissionStatus.granted;
  }

  Future<UserLocation?> getLastKnownPosition() async {
    try {
      final pos = await _dataSource.getLastKnownPosition();
      return pos != null ? _positionToUserLocation(pos) : null;
    } catch (_) {
      return null;
    }
  }

  Future<UserLocation?> getCurrentPosition() async {
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      final pos = await _dataSource.getCurrentPosition(
        locationSettings: settings,
      );
      return _positionToUserLocation(pos);
    } catch (_) {
      return null;
    }
  }

  Stream<UserLocation> getPositionStream({int distanceFilter = 10}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
    return _dataSource
        .getPositionStream(locationSettings: settings)
        .map(_positionToUserLocation);
  }

  Future<bool> openAppSettings() => _dataSource.openAppSettings();

  Future<bool> openLocationSettings() => _dataSource.openLocationSettings();

  static UserLocation _positionToUserLocation(Position pos) {
    return UserLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
    );
  }
}
