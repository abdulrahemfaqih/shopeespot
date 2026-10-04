import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/core/widgets/category_marker.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/orders/presentation/orders_providers.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/spots/presentation/widgets/spot_detail_sheet.dart';

void main() {
  late AppDatabase db;
  late SpotRepository spotRepo;
  late OrderRepository orderRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    spotRepo = SpotRepository(db: db);
    orderRepo = OrderRepository(db: db, spotRepository: spotRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('SpotDetailSheet widget content and actions', () {
    testWidgets(
      'renders all compact and expanded contents without Card widgets',
      (tester) async {
        final now = DateTime.utc(2026, 10, 4, 10, 0);
        final spot = Spot(
          id: 'test-spot-1',
          name: 'Bebek Kaleyo Tebet',
          category: Category.shopeefood,
          latitude: -6.2088,
          longitude: 106.8456,
          notes: 'Pintu masuk samping ruko',
          peakHours: const [
            PeakRange(days: [1, 2, 3, 4, 5], start: 11 * 60, end: 13 * 60),
          ],
          lastVerifiedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final userLoc = UserLocation(
          latitude: -6.2100,
          longitude: 106.8456,
          accuracy: 10.0,
          timestamp: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              spotRepositoryProvider.overrideWithValue(spotRepo),
              orderRepositoryProvider.overrideWithValue(orderRepo),
              clockProvider.overrideWithValue(
                FixedClock(DateTime(2026, 10, 5, 10, 0)),
              ),
              userLocationProvider.overrideWith(
                () => _TestLocationNotifier(LocationAvailable(userLoc)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: SpotDetailSheet(spot: spot, onClose: () {}),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Compact info
        expect(find.text('Bebek Kaleyo Tebet'), findsOneWidget);
        expect(find.textContaining('ShopeeFood · '), findsOneWidget);
        expect(find.text('Ramai 11:00-13:00'), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, 'Dapat order di sini'),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Arahkan'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);

        // Expanded info
        expect(find.text('Hari ini: 0 order'), findsOneWidget);
        expect(find.text('Pintu masuk samping ruko'), findsOneWidget);
        expect(find.text('Hari kerja: 11:00 - 13:00'), findsOneWidget);
        expect(find.text('Terakhir diverifikasi 4 Okt 2026'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Hapus spot'), findsOneWidget);

        // Strict DESIGN.md requirement: no cards inside cards / no Card widget
        expect(find.byType(Card), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'deleting spot shows confirmation dialog and performs soft delete',
      (tester) async {
        final spot = await spotRepo.createSpot(
          name: 'Spot to Delete',
          category: Category.spx,
          latitude: -6.22,
          longitude: 106.82,
        );

        bool closed = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              spotRepositoryProvider.overrideWithValue(spotRepo),
              orderRepositoryProvider.overrideWithValue(orderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: SpotDetailSheet(spot: spot, onClose: () => closed = true),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap 'Hapus spot'
        await tester.tap(find.widgetWithText(AppButton, 'Hapus spot'));
        await tester.pumpAndSettle();

        expect(find.text('Hapus spot?'), findsOneWidget);
        expect(
          find.text('Spot ini beserta seluruh riwayat ordernya akan dihapus.'),
          findsOneWidget,
        );

        // Confirm deletion in dialog
        await tester.tap(find.widgetWithText(AppButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(closed, true);
        final spots = await spotRepo.getActiveSpots();
        expect(spots.any((s) => s.id == spot.id), false);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });

  group('MapScreen detail sheet integration', () {
    testWidgets(
      'tap marker opens SpotDetailSheet, tap map closes it, delete removes marker',
      (tester) async {
        final spot = await spotRepo.createSpot(
          name: 'Warung Soto Lamongan',
          category: Category.shopeefood,
          latitude: -6.1754,
          longitude: 106.8272,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              spotRepositoryProvider.overrideWithValue(spotRepo),
              orderRepositoryProvider.overrideWithValue(orderRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MapScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Marker is rendered on map
        expect(find.byType(CategoryMarker), findsOneWidget);
        expect(find.byType(SpotDetailSheet), findsNothing);

        // Tap marker
        await tester.tap(find.byType(CategoryMarker));
        await tester.pumpAndSettle();

        // Detail sheet is now open
        expect(find.byType(SpotDetailSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SpotDetailSheet),
            matching: find.text('Warung Soto Lamongan'),
          ),
          findsOneWidget,
        );

        // Tap empty map closes sheet
        await tester.tapAt(const Offset(50, 150));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.byType(SpotDetailSheet), findsNothing);

        // Re-open detail sheet
        await tester.tap(find.byType(CategoryMarker));
        await tester.pumpAndSettle();
        expect(find.byType(SpotDetailSheet), findsOneWidget);

        // Soft-deleting the spot removes marker and dismisses sheet
        await spotRepo.softDeleteSpot(spot.id);
        await tester.pumpAndSettle();

        // Marker disappears from map and sheet is closed
        expect(find.byType(CategoryMarker), findsNothing);
        expect(find.byType(SpotDetailSheet), findsNothing);

        // Cleanly unmount widget tree to drain pending timers
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
