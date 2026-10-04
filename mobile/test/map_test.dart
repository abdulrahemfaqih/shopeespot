import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/config/env.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/features/map/data/tile_cache_manager.dart';
import 'package:shopeespot/features/map/presentation/map_controller.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/map/presentation/widgets/filter_bar.dart';
import 'package:shopeespot/features/map/presentation/widgets/gps_layer.dart';
import 'package:shopeespot/features/map/presentation/widgets/map_controls.dart';
import 'package:shopeespot/features/map/presentation/widgets/map_key_missing_hint.dart';
import 'package:shopeespot/features/map/presentation/widgets/quick_pin_fab.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Map camera and cache manager', () {
    test('MapCameraNotifier loads default and saves position', () async {
      SharedPreferences.setMockInitialValues({
        prefLastLat: -6.2,
        prefLastLng: 106.8,
        prefLastZoom: 16.0,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(mapCameraProvider.future);
      expect(state.center.latitude, -6.2);
      expect(state.center.longitude, 106.8);
      expect(state.zoom, 16.0);

      await container
          .read(mapCameraProvider.notifier)
          .saveCameraPosition(const LatLng(-7.0, 110.0), 14.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(prefLastLat), -7.0);
      expect(prefs.getDouble(prefLastLng), 110.0);
      expect(prefs.getDouble(prefLastZoom), 14.0);
    });

    test(
      'TileCacheManager updates last clean key if older than 7 days',
      () async {
        final oldDate = DateTime.utc(2026, 8, 1);
        final currentDate = DateTime.utc(2026, 10, 4);

        SharedPreferences.setMockInitialValues({
          TileCacheManager.lastCleanKey: oldDate.toIso8601String(),
        });

        final prefs = await SharedPreferences.getInstance();
        await TileCacheManager.initialize(
          prefs: prefs,
          clock: FixedClock(currentDate),
        );

        final updatedDateStr = prefs.getString(TileCacheManager.lastCleanKey);
        expect(updatedDateStr, isNotNull);
        expect(DateTime.parse(updatedDateStr!), currentDate);
      },
    );
  });

  group('MapScreen and Widgets', () {
    testWidgets(
      'MapScreen renders FlutterMap, controls, attribution, GPS layer, filter bar, and QuickPinFab',
      (tester) async {
        final loc = UserLocation(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracy: 10.0,
          timestamp: DateTime.utc(2026, 10, 4, 10, 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userLocationProvider.overrideWith(
                () => _TestLocationNotifier(LocationAvailable(loc)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        if (Env.stadiaApiKey.isNotEmpty) {
          expect(find.byType(TileLayer), findsOneWidget);
        } else {
          expect(find.text('Kunci peta belum diisi'), findsOneWidget);
          expect(find.byType(TileLayer), findsNothing);
        }
        expect(find.byType(GpsLayer), findsOneWidget);
        expect(find.byType(MyLocationButton), findsOneWidget);
        expect(find.byType(QuickPinFab), findsOneWidget);
        expect(find.byType(FilterBar), findsOneWidget);
        expect(find.byType(MapAttribution), findsOneWidget);
        expect(
          find.text('© Stadia Maps, © OpenMapTiles, © OpenStreetMap'),
          findsOneWidget,
        );

        // Tap QuickPinFab opens SpotFormScreen
        await tester.tap(find.byType(QuickPinFab));
        await tester.pumpAndSettle();

        expect(find.byType(SpotFormScreen), findsOneWidget);
        expect(find.text('Spot baru'), findsOneWidget);
      },
    );

    testWidgets(
      'GpsLayer renders driver dot and accuracy circle when location is available',
      (tester) async {
        final loc = UserLocation(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracy: 15.0,
          timestamp: DateTime.utc(2026, 10, 4, 10, 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userLocationProvider.overrideWith(
                () => _TestLocationNotifier(LocationAvailable(loc)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(-6.2088, 106.8456),
                    initialZoom: 15.0,
                  ),
                  children: [GpsLayer()],
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(CircleLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsOneWidget);
      },
    );

    testWidgets(
      'MapKeyMissingHint renders "Kunci peta belum diisi" correctly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: Stack(children: [MapKeyMissingHint()])),
          ),
        );

        expect(find.byType(MapKeyMissingHint), findsOneWidget);
        expect(find.text('Kunci peta belum diisi'), findsOneWidget);
      },
    );
  });
}

class _TestLocationNotifier extends UserLocationNotifier {
  _TestLocationNotifier(this._initialState);
  final LocationState _initialState;

  @override
  LocationState build() => _initialState;
}
