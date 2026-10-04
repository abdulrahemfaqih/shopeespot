import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shopeespot/core/config/env.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';

class MockLocationDataSource implements LocationDataSource {
  MockLocationDataSource({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.lastKnownPosition,
  });

  bool serviceEnabled;
  LocationPermission permission;
  Position? lastKnownPosition;
  final StreamController<Position> streamController =
      StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position?> getLastKnownPosition() async => lastKnownPosition;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (lastKnownPosition != null) return lastKnownPosition!;
    throw StateError('No position');
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      streamController.stream;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('Env configuration', () {
    test('Env contains default values', () {
      expect(Env.apiBaseUrl, isNotEmpty);
      expect(Env.cartoApiKey, isA<String>());
    });
  });

  group('LocationService', () {
    test('handles disabled location service', () async {
      final mock = MockLocationDataSource(serviceEnabled: false);
      final service = LocationService(dataSource: mock);

      final status = await service.checkAndRequestPermission();
      expect(status, LocationPermissionStatus.serviceDisabled);
    });

    test('handles denied permission', () async {
      final mock = MockLocationDataSource(
        permission: LocationPermission.denied,
      );
      final service = LocationService(dataSource: mock);

      final status = await service.checkAndRequestPermission();
      expect(status, LocationPermissionStatus.denied);
    });

    test('handles permanently denied permission', () async {
      final mock = MockLocationDataSource(
        permission: LocationPermission.deniedForever,
      );
      final service = LocationService(dataSource: mock);

      final status = await service.checkAndRequestPermission();
      expect(status, LocationPermissionStatus.deniedForever);
    });

    test('returns last known position and streams positions', () async {
      final now = DateTime.utc(2026, 10, 4, 10, 0);
      final samplePos = Position(
        latitude: -6.2088,
        longitude: 106.8456,
        timestamp: now,
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final mock = MockLocationDataSource(lastKnownPosition: samplePos);
      final service = LocationService(dataSource: mock);

      final status = await service.checkAndRequestPermission();
      expect(status, LocationPermissionStatus.granted);

      final lastKnown = await service.getLastKnownPosition();
      expect(lastKnown, isNotNull);
      expect(lastKnown!.latitude, -6.2088);
      expect(lastKnown.longitude, 106.8456);
      expect(lastKnown.accuracy, 10.0);

      final streamFuture = service.getPositionStream().first;
      mock.streamController.add(samplePos);
      final streamed = await streamFuture;
      expect(streamed.latitude, -6.2088);
    });
  });

  group('userLocationProvider state transitions', () {
    test(
      'transitions to LocationAvailable with cached and streamed positions',
      () async {
        final now = DateTime.utc(2026, 10, 4, 10, 0);
        final samplePos = Position(
          latitude: -6.2088,
          longitude: 106.8456,
          timestamp: now,
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        final mock = MockLocationDataSource(lastKnownPosition: samplePos);
        final service = LocationService(dataSource: mock);

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        // Initially waiting before initialization completes
        final notifier = container.read(userLocationProvider.notifier);
        await notifier.initialize();

        final state = container.read(userLocationProvider);
        expect(state, isA<LocationAvailable>());
        final available = state as LocationAvailable;
        expect(available.location.latitude, -6.2088);
      },
    );

    test('transitions to LocationDenied when permission is denied', () async {
      final mock = MockLocationDataSource(
        permission: LocationPermission.denied,
      );
      final service = LocationService(dataSource: mock);

      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userLocationProvider.notifier);
      await notifier.initialize();

      final state = container.read(userLocationProvider);
      expect(state, isA<LocationDenied>());
    });

    test(
      'transitions to LocationServiceDisabled when GPS is turned off',
      () async {
        final mock = MockLocationDataSource(serviceEnabled: false);
        final service = LocationService(dataSource: mock);

        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(userLocationProvider.notifier);
        await notifier.initialize();

        final state = container.read(userLocationProvider);
        expect(state, isA<LocationServiceDisabled>());
      },
    );
  });
}
