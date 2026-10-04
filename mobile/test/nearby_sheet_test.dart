import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/time/day_type.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/map/presentation/widgets/map_controls.dart';
import 'package:shopeespot/features/orders/presentation/orders_providers.dart';
import 'package:shopeespot/features/peak/domain/peak_index.dart';
import 'package:shopeespot/features/peak/presentation/peak_provider.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/nearby_calculator.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/spots/presentation/widgets/nearby_sheet.dart';
import 'package:shopeespot/features/spots/presentation/widgets/spot_detail_sheet.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final now = DateTime(2026, 10, 5, 12, 0); // Monday 12:00
  const userLat = -6.1754;
  const userLng = 106.8272;

  final userLoc = UserLocation(
    latitude: userLat,
    longitude: userLng,
    accuracy: 5.0,
    timestamp: now,
  );

  final spotNear = Spot(
    id: 'spot-1',
    name: 'Soto Betawi Bang Madun',
    category: Category.shopeefood,
    latitude: -6.1770,
    longitude: 106.8280, // ~200 m
    lastVerifiedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final spotMid = Spot(
    id: 'spot-2',
    name: 'SPX Hub Gambir',
    category: Category.spx,
    latitude: -6.1850,
    longitude: 106.8350, // ~1.3 km
    lastVerifiedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  final spotFar = Spot(
    id: 'spot-3',
    name: 'Ayam Goreng Berkah',
    category: Category.shopeefood,
    latitude: -6.2050,
    longitude: 106.8400, // ~3.5 km
    lastVerifiedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  const testPeakIndex = PeakIndex(
    peakHoursByDayType: {
      DayType.weekday: {
        'spot-1': {12, 13},
      },
    },
    hourlyCountsByDayType: {
      DayType.weekday: {
        'spot-1': {12: 4},
        'spot-2': {12: 15}, // higher orders
        'spot-3': {12: 2},
      },
    },
  );

  group('NearbySheet widget UI and interactions', () {
    testWidgets(
      'renders segmented control, sort button, and spot rows with distance and peak badge',
      (tester) async {
        Spot? selectedSpot;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              filteredSpotsProvider.overrideWithValue([
                spotNear,
                spotMid,
                spotFar,
              ]),
              peakIndexProvider.overrideWith((ref) => testPeakIndex),
              clockProvider.overrideWithValue(FixedClock(now)),
              userLocationProvider.overrideWith(
                () => _TestLocationNotifier(LocationAvailable(userLoc)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: NearbySheet(
                  initialRadius: NearbyRadius.fiveKm,
                  onSpotSelected: (s) => selectedSpot = s,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Header controls
        expect(find.text('1 km'), findsOneWidget);
        expect(find.text('2 km'), findsOneWidget);
        expect(find.text('5 km'), findsOneWidget);
        expect(find.text('Urut: Jarak'), findsOneWidget);

        // Spot rows
        expect(find.text('Soto Betawi Bang Madun'), findsOneWidget);
        expect(find.text('SPX Hub Gambir'), findsOneWidget);
        expect(find.text('Ayam Goreng Berkah'), findsOneWidget);

        // Peak caption on spot-1
        expect(find.textContaining('· Ramai sekarang'), findsOneWidget);

        // Tap row triggers callback
        await tester.tap(find.text('SPX Hub Gambir'));
        await tester.pumpAndSettle();

        expect(selectedSpot?.id, 'spot-2');

        // Unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('switching radius filters visible spots', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredSpotsProvider.overrideWithValue([
              spotNear,
              spotMid,
              spotFar,
            ]),
            peakIndexProvider.overrideWith((ref) => testPeakIndex),
            clockProvider.overrideWithValue(FixedClock(now)),
            userLocationProvider.overrideWith(
              () => _TestLocationNotifier(LocationAvailable(userLoc)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: NearbySheet(
                initialRadius: NearbyRadius.oneKm,
                onSpotSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // At 1 km: only spotNear (~200 m) is visible
      expect(find.text('Soto Betawi Bang Madun'), findsOneWidget);
      expect(find.text('SPX Hub Gambir'), findsNothing);
      expect(find.text('Ayam Goreng Berkah'), findsNothing);

      // Switch to 2 km
      await tester.tap(find.text('2 km'));
      await tester.pumpAndSettle();

      expect(find.text('Soto Betawi Bang Madun'), findsOneWidget);
      expect(find.text('SPX Hub Gambir'), findsOneWidget);
      expect(find.text('Ayam Goreng Berkah'), findsNothing);

      // Switch to 5 km
      await tester.tap(find.text('5 km'));
      await tester.pumpAndSettle();

      expect(find.text('Soto Betawi Bang Madun'), findsOneWidget);
      expect(find.text('SPX Hub Gambir'), findsOneWidget);
      expect(find.text('Ayam Goreng Berkah'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('toggling sort order changes ordering to Order jam ini', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredSpotsProvider.overrideWithValue([
              spotNear,
              spotMid,
              spotFar,
            ]),
            peakIndexProvider.overrideWith((ref) => testPeakIndex),
            clockProvider.overrideWithValue(FixedClock(now)),
            userLocationProvider.overrideWith(
              () => _TestLocationNotifier(LocationAvailable(userLoc)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: NearbySheet(
                initialRadius: NearbyRadius.fiveKm,
                initialSortOrder: NearbySortOrder.distance,
                onSpotSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial: Urut: Jarak
      expect(find.text('Urut: Jarak'), findsOneWidget);

      // Tap sort button
      await tester.tap(find.text('Urut: Jarak'));
      await tester.pumpAndSettle();

      // Label changes to Urut: Order jam ini
      expect(find.text('Urut: Order jam ini'), findsOneWidget);

      // Tap sort button again toggles back
      await tester.tap(find.text('Urut: Order jam ini'));
      await tester.pumpAndSettle();

      expect(find.text('Urut: Jarak'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty message when no spots match', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredSpotsProvider.overrideWithValue(<Spot>[]),
            peakIndexProvider.overrideWith((ref) => testPeakIndex),
            clockProvider.overrideWithValue(FixedClock(now)),
            userLocationProvider.overrideWith(
              () => _TestLocationNotifier(LocationAvailable(userLoc)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: NearbySheet(
                initialRadius: NearbyRadius.oneKm,
                onSpotSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tidak ada spot dalam radius ini.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('shows message when location permission denied', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredSpotsProvider.overrideWithValue([
              spotNear,
              spotMid,
              spotFar,
            ]),
            peakIndexProvider.overrideWith((ref) => testPeakIndex),
            clockProvider.overrideWithValue(FixedClock(now)),
            userLocationProvider.overrideWith(
              () => _TestLocationNotifier(const LocationDenied()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: NearbySheet(onSpotSelected: (_) {})),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Izin lokasi diperlukan untuk melihat spot terdekat.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('MapScreen nearby integration', () {
    testWidgets(
      'tap NearbyListButton opens NearbySheet and selecting spot centers map and opens detail sheet',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              filteredSpotsProvider.overrideWithValue([
                spotNear,
                spotMid,
                spotFar,
              ]),
              activeSpotsStreamProvider.overrideWith(
                (ref) => Stream.value([spotNear, spotMid, spotFar]),
              ),
              peakIndexProvider.overrideWith((ref) => testPeakIndex),
              clockProvider.overrideWithValue(FixedClock(now)),
              userLocationProvider.overrideWith(
                () => _TestLocationNotifier(LocationAvailable(userLoc)),
              ),
              spotOrdersCountTodayProvider(
                spotNear.id,
              ).overrideWith((ref) => 1),
              spotOrdersCountTodayProvider(spotMid.id).overrideWith((ref) => 2),
              spotOrdersCountTodayProvider(spotFar.id).overrideWith((ref) => 0),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // NearbyListButton is present
        expect(find.byType(NearbyListButton), findsOneWidget);
        expect(find.byType(NearbySheet), findsNothing);

        // Tap NearbyListButton
        await tester.tap(find.byType(NearbyListButton));
        await tester.pumpAndSettle();

        // NearbySheet is now open
        expect(find.byType(NearbySheet), findsOneWidget);
        final spotItemFinder = find.descendant(
          of: find.byType(NearbySheet),
          matching: find.text('Soto Betawi Bang Madun'),
        );
        expect(spotItemFinder, findsOneWidget);

        // Tap spot row
        await tester.tap(spotItemFinder);
        await tester.pumpAndSettle();

        // NearbySheet closed, SpotDetailSheet opened for spotNear
        expect(find.byType(NearbySheet), findsNothing);
        expect(find.byType(SpotDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SpotDetailSheet),
            matching: find.text('Soto Betawi Bang Madun'),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
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
