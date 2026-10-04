import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final userLocationProvider =
    NotifierProvider<UserLocationNotifier, LocationState>(
      UserLocationNotifier.new,
    );

class UserLocationNotifier extends Notifier<LocationState> {
  StreamSubscription<UserLocation>? _subscription;

  @override
  LocationState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Start location initialization asynchronously
    unawaited(initialize());

    return const LocationWaiting();
  }

  Future<void> initialize() async {
    final service = ref.read(locationServiceProvider);

    final status = await service.checkAndRequestPermission();
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        state = const LocationServiceDisabled();
        return;
      case LocationPermissionStatus.denied:
        state = const LocationDenied(isPermanent: false);
        return;
      case LocationPermissionStatus.deniedForever:
        state = const LocationDenied(isPermanent: true);
        return;
      case LocationPermissionStatus.granted:
        break;
    }

    // Attempt to emit cached position first to avoid waiting for GPS lock
    final lastKnown = await service.getLastKnownPosition();
    if (lastKnown != null && state is LocationWaiting) {
      state = LocationAvailable(lastKnown);
    }

    // Subscribe to continuous GPS position stream with distanceFilter 10
    await _subscription?.cancel();
    _subscription = service
        .getPositionStream(distanceFilter: 10)
        .listen(
          (location) {
            state = LocationAvailable(location);
          },
          onError: (_) {
            // If already available, retain last position; otherwise service disabled or error
          },
        );
  }

  Future<void> retry() async {
    state = const LocationWaiting();
    await initialize();
  }
}
