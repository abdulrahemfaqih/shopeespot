import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';

void main() {
  late AppDatabase db;
  late SpotRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SpotRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildFormScreen({
    Spot? spot,
    double initialLatitude = -6.2088,
    double initialLongitude = 106.8456,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        spotRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SpotFormScreen(
          spot: spot,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
        ),
      ),
    );
  }

  group('SpotFormScreen creation mode', () {
    testWidgets('renders Spot baru title and initial coordinates', (
      tester,
    ) async {
      await tester.pumpWidget(buildFormScreen());

      expect(find.text('Spot baru'), findsOneWidget);
      expect(find.text('-6.208800, 106.845600'), findsOneWidget);
      expect(find.text('ShopeeFood'), findsOneWidget);
      expect(find.text('SPX'), findsOneWidget);
    });

    testWidgets('validates required name field', (tester) async {
      await tester.pumpWidget(buildFormScreen());

      // Attempt to save with empty name
      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pump();

      expect(find.text('Nama spot wajib diisi'), findsOneWidget);
      final spots = await repo.getActiveSpots();
      expect(spots, isEmpty);
    });

    testWidgets('creates spot with valid inputs', (tester) async {
      await tester.pumpWidget(buildFormScreen());

      // Fill in name
      await tester.enterText(
        find.widgetWithText(TextFormField, '').first,
        'Warung Makan Barokah',
      );

      // Select SPX
      await tester.tap(find.text('SPX'));
      await tester.pump();

      // Enter notes
      await tester.enterText(
        find.widgetWithText(TextFormField, '').last,
        'Parkir gratis di depan',
      );

      // Save
      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pumpAndSettle();

      final spots = await repo.getActiveSpots();
      expect(spots.length, 1);
      final created = spots.first;
      expect(created.name, 'Warung Makan Barokah');
      expect(created.category, Category.spx);
      expect(created.notes, 'Parkir gratis di depan');
      expect(created.latitude, -6.2088);
      expect(created.longitude, 106.8456);
      expect(created.dirty, true);
    });
  });

  group('SpotFormScreen edit mode', () {
    testWidgets('loads existing spot and updates it', (tester) async {
      final existingSpot = await repo.createSpot(
        name: 'Resto Asli',
        category: Category.shopeefood,
        latitude: -6.1234,
        longitude: 106.5678,
        notes: 'Catatan lama',
      );

      await tester.pumpWidget(
        buildFormScreen(
          spot: existingSpot,
          initialLatitude: existingSpot.latitude,
          initialLongitude: existingSpot.longitude,
        ),
      );

      expect(find.text('Edit spot'), findsOneWidget);
      expect(find.text('Resto Asli'), findsOneWidget);
      expect(find.text('Catatan lama'), findsOneWidget);

      // Update name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Resto Asli'),
        'Resto Baru Super',
      );

      // Save
      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pumpAndSettle();

      final updated = await repo.getSpotById(existingSpot.id);
      expect(updated, isNotNull);
      expect(updated!.name, 'Resto Baru Super');
      expect(updated.category, Category.shopeefood);
    });
  });
}
