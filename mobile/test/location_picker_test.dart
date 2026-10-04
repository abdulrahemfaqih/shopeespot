import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/core/widgets/category_marker.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/presentation/location_picker_screen.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';

void main() {
  group('LocationPickerScreen widget', () {
    testWidgets('renders map, pin in center, instruction banner, and buttons', (
      tester,
    ) async {
      LatLng? pickedLocation;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedLocation = await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) => const LocationPickerScreen(
                          initialPosition: LatLng(-6.2088, 106.8456),
                          category: Category.shopeefood,
                        ),
                      ),
                    );
                  },
                  child: const Text('Pick Location'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Location'));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(CategoryMarker), findsOneWidget);
      expect(find.text('Geser peta untuk mengatur posisi'), findsOneWidget);
      expect(find.text('-6.208800, 106.845600'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Batal'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Simpan posisi ini'),
        findsOneWidget,
      );

      // Tap Simpan posisi ini
      await tester.tap(find.widgetWithText(AppButton, 'Simpan posisi ini'));
      await tester.pumpAndSettle();

      expect(pickedLocation, isNotNull);
      expect(pickedLocation!.latitude, -6.2088);
      expect(pickedLocation!.longitude, 106.8456);
    });

    testWidgets('tapping Batal cancels and returns null', (tester) async {
      LatLng? pickedLocation;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickedLocation = await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) => const LocationPickerScreen(
                          initialPosition: LatLng(-6.2088, 106.8456),
                        ),
                      ),
                    );
                  },
                  child: const Text('Pick Location'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Location'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(pickedLocation, isNull);
    });
  });

  group('SpotFormScreen location adjustment and last_verified_at update', () {
    late AppDatabase db;
    late SpotRepository repo;
    late FixedClock clock;

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 10, 4, 10, 0));
      db = AppDatabase(NativeDatabase.memory());
      repo = SpotRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'adjusting location in LocationPickerScreen updates form and updates last_verified_at',
      (tester) async {
        // 1. Create initial spot at t0
        final spot = await repo.createSpot(
          name: 'Spot Lama',
          category: Category.shopeefood,
          latitude: -6.2000,
          longitude: 106.8000,
        );
        expect(spot.lastVerifiedAt, DateTime.utc(2026, 10, 4, 10, 0));

        // Advance clock by 2 hours
        clock.setTime(DateTime.utc(2026, 10, 4, 12, 0));

        // Open SpotFormScreen in edit mode
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              spotRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: SpotFormScreen(
                spot: spot,
                initialLatitude: spot.latitude,
                initialLongitude: spot.longitude,
              ),
            ),
          ),
        );

        // Scroll down to reveal location button
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Tap 'Atur posisi di peta'
        await tester.tap(find.text('Atur posisi di peta'));
        await tester.pumpAndSettle();

        expect(find.byType(LocationPickerScreen), findsOneWidget);

        // Save position from LocationPickerScreen
        await tester.tap(find.widgetWithText(AppButton, 'Simpan posisi ini'));
        await tester.pumpAndSettle();

        // Back on SpotFormScreen, tap Simpan
        await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
        await tester.pumpAndSettle();

        final updatedSpot = await repo.getSpotById(spot.id);
        expect(updatedSpot, isNotNull);
        // last_verified_at should be updated to 12:00
        expect(updatedSpot!.lastVerifiedAt, DateTime.utc(2026, 10, 4, 12, 0));
        expect(updatedSpot.updatedAt, DateTime.utc(2026, 10, 4, 12, 0));
      },
    );
  });
}
