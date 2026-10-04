import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/app.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/features/map/presentation/map_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Smoke test builds SpotShopeeApp without error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userLocationProvider.overrideWith(
            () => _StaticLocationNotifier(const LocationWaiting()),
          ),
          mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
        ],
        child: const SpotShopeeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SpotShopeeApp), findsOneWidget);
  });
}

class _StaticLocationNotifier extends UserLocationNotifier {
  _StaticLocationNotifier(this._state);
  final LocationState _state;

  @override
  LocationState build() => _state;
}

class _StaticCameraNotifier extends MapCameraNotifier {
  @override
  Future<MapCameraState> build() async {
    return const MapCameraState(
      center: LatLng(defaultLat, defaultLng),
      zoom: defaultZoom,
    );
  }
}
