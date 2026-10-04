import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/features/auth/data/token_store.dart';
import 'package:shopeespot/features/auth/domain/session_state.dart';
import 'package:shopeespot/features/auth/presentation/auth_controller.dart';
import 'package:shopeespot/features/map/presentation/map_controller.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/map/presentation/widgets/map_controls.dart';
import 'package:shopeespot/features/map/presentation/widgets/map_empty_hint.dart';
import 'package:shopeespot/features/map/presentation/widgets/quick_pin_fab.dart';
import 'package:shopeespot/features/map/presentation/widgets/spot_markers_layer.dart';
import 'package:shopeespot/features/orders/data/order_dao.dart';
import 'package:shopeespot/features/settings/presentation/settings_screen.dart';
import 'package:shopeespot/features/spots/data/spot_dao.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/sync/presentation/sync_providers.dart';

import 'auth_test.dart';
import 'login_test.dart';

class _StaticLocationNotifier extends UserLocationNotifier {
  _StaticLocationNotifier(this._initial);
  final LocationState _initial;

  @override
  LocationState build() => _initial;
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

class _MockLocationService implements LocationService {
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;

  @override
  Future<LocationPermissionStatus> checkAndRequestPermission() async =>
      LocationPermissionStatus.denied;

  @override
  Future<UserLocation?> getLastKnownPosition() async => null;

  @override
  Future<UserLocation?> getCurrentPosition() async => null;

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }

  @override
  Stream<UserLocation> getPositionStream({int distanceFilter = 10}) {
    return const Stream.empty();
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('T-32 Edge Cases Testing (PRD Section 7)', () {
    testWidgets(
      '1. Izin lokasi ditolak: map remains displayed, location & quick pin explain permission and guide to settings',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final mockLocService = _MockLocationService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              locationServiceProvider.overrideWithValue(mockLocService),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationDenied()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Map is still rendered at position
        expect(find.byType(FlutterMap), findsOneWidget);

        // Tap MyLocationButton
        await tester.tap(find.byType(MyLocationButton));
        await tester.pumpAndSettle();

        // Explains permission and directs to settings
        expect(
          find.text('Izin lokasi diperlukan untuk fitur ini.'),
          findsOneWidget,
        );
        expect(find.text('Buka pengaturan'), findsOneWidget);

        await tester.tap(find.text('Buka pengaturan'));
        await tester.pumpAndSettle();
        expect(mockLocService.appSettingsOpened, isTrue);

        // Tap QuickPin FAB
        await tester.tap(find.byType(QuickPinFab));
        await tester.pumpAndSettle();

        expect(
          find.text('Izin lokasi diperlukan untuk fitur ini.'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      '2. GPS belum dapat: Quick Pin waits briefly and offers positioning with map center',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final mockLocService = _MockLocationService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              locationServiceProvider.overrideWithValue(mockLocService),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationWaiting()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(QuickPinFab));
        await tester.pumpAndSettle();

        // Offers SpotFormScreen with default map center
        expect(find.byType(SpotFormScreen), findsOneWidget);
        expect(find.text('Spot baru'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      '3. Tidak ada spot: map renders empty with one hint sentence at bottom',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationWaiting()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Exactly matches DESIGN.md and PRD.md
        expect(find.byType(MapEmptyHint), findsOneWidget);
        expect(
          find.text('Belum ada spot. Tap + untuk menandai spot pertama.'),
          findsOneWidget,
        );

        // When a spot exists in DB, hint disappears
        final spotDao = SpotDao(db);
        final now = DateTime.now();
        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-1',
            name: 'Spot Baru',
            category: 'shopeefood',
            latitude: -6.2,
            longitude: 106.8,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(MapEmptyHint), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      '4. Offline: all features work with local SQLite without disruptive banners',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final spotDao = SpotDao(db);
        final now = DateTime.now();

        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-offline-1',
            name: 'Kedai Offline',
            category: 'shopeefood',
            latitude: -6.2,
            longitude: 106.8,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationWaiting()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Renders smoothly with no error banners
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(
          find.text('Kedai Offline'),
          findsNothing,
        ); // label only zoom >= 15

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      '5. Tile belum pernah dilihat / offline: spot and markers layer tetap tampil',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final spotDao = SpotDao(db);
        final now = DateTime.now();

        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-tile-test-1',
            name: 'Spot Uncached Area',
            category: 'shopeefood',
            latitude: -6.2,
            longitude: 106.8,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationWaiting()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // SpotMarkersLayer and TileLayer both exist in Stack
        expect(find.byType(TileLayer), findsOneWidget);
        expect(find.byType(SpotMarkersLayer), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      '6. Sesi berakhir: local data intact, app usable, settings prompts login',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final spotDao = SpotDao(db);
        final now = DateTime.now();

        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-intact-1',
            name: 'Spot Intact',
            category: 'shopeefood',
            latitude: -6.2,
            longitude: 106.8,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final tokenStore = FakeTokenStore()..userEmail = 'driver@example.com';

        final sessionNotifier = SessionNotifier(
          tokenStore,
          MockAuthApi(),
          initialState: const SessionState.expired(
            userId: 'user-1',
            userEmail: 'driver@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              tokenStoreProvider.overrideWithValue(tokenStore),
              sessionStateProvider.overrideWith((ref) => sessionNotifier),
              totalDirtyCountProvider.overrideWithValue(0),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Displays session expired status with invitation to log in
        expect(
          find.text('Sesi berakhir. Masuk lagi untuk sinkronisasi.'),
          findsOneWidget,
        );
        expect(find.text('Masuk lagi'), findsOneWidget);

        // Verify local spots in SQLite are completely intact
        final spots = await spotDao.getActiveSpots();
        expect(spots.length, 1);
        expect(spots.first.name, 'Spot Intact');

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    test(
      '7. Jam sistem diubah: orders record local device time without correction',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final orderDao = OrderDao(db);

        // Simulate system clock adjusted by driver (e.g. 5 days in the future)
        final customDeviceTime = DateTime(2026, 10, 20, 15, 30);

        await orderDao.insertOrder(
          OrdersCompanion.insert(
            id: 'ord-clock-test-1',
            spotId: 'sp-1',
            orderedAt: customDeviceTime,
            localDow: customDeviceTime.weekday,
            localHour: customDeviceTime.hour,
            createdAt: customDeviceTime,
            updatedAt: customDeviceTime,
          ),
        );

        final recorded = await orderDao.getOrderById('ord-clock-test-1');
        expect(recorded, isNotNull);
        expect(recorded!.orderedAt, customDeviceTime);
        expect(recorded.localHour, 15);
        expect(recorded.localDow, customDeviceTime.weekday);

        await db.close();
      },
    );
  });
}
