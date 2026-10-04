import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/core/widgets/app_chip.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/presentation/spot_form_screen.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/spots/presentation/widgets/peak_range_editor.dart';

void main() {
  group('PeakRangeEditor widget', () {
    testWidgets('defaults to Hari kerja and 11:00 - 14:00', (tester) async {
      PeakRange? savedRange;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    savedRange = await showModalBottomSheet<PeakRange>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const PeakRangeEditor(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah jam ramai'), findsOneWidget);
      expect(find.text('Hari kerja'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);

      // Save directly
      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(savedRange, isNotNull);
      expect(savedRange!.days, [1, 2, 3, 4, 5]);
      expect(savedRange!.start, 11 * 60);
      expect(savedRange!.end, 14 * 60);
    });

    testWidgets('preset chips and midnight crossing caption', (tester) async {
      PeakRange? savedRange;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    savedRange = await showModalBottomSheet<PeakRange>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const PeakRangeEditor(
                        initialRange: PeakRange(
                          days: [6, 7],
                          start: 22 * 60,
                          end: 2 * 60,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit jam ramai'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('Rentang melewati tengah malam'), findsOneWidget);

      // Switch preset to 'Setiap hari'
      await tester.tap(find.widgetWithText(AppChip, 'Setiap hari'));
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(savedRange, isNotNull);
      expect(savedRange!.days, [1, 2, 3, 4, 5, 6, 7]);
      expect(savedRange!.start, 22 * 60);
      expect(savedRange!.end, 2 * 60);
      expect(savedRange!.crossesMidnight, true);
    });
  });

  group('SpotFormScreen integration with PeakRangeEditor', () {
    late AppDatabase db;
    late SpotRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = SpotRepository(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('adds, modifies, removes peak hours, and saves to repository', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            spotRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SpotFormScreen(
              initialLatitude: -6.2088,
              initialLongitude: 106.8456,
            ),
          ),
        ),
      );

      // Initially no peak hours
      expect(find.text('Belum ada jam ramai manual'), findsOneWidget);

      // Tap '+ Tambah jam'
      await tester.tap(find.text('+ Tambah jam'));
      await tester.pumpAndSettle();

      // In PeakRangeEditor: save default (Hari kerja 11:00-14:00)
      await tester.tap(find.widgetWithText(AppButton, 'Simpan').last);
      await tester.pumpAndSettle();

      // Range now appears in SpotFormScreen
      expect(find.text('Hari kerja: 11:00 - 14:00'), findsOneWidget);

      // Fill in spot name
      await tester.enterText(
        find.widgetWithText(TextFormField, '').first,
        'Mie Ayam Jamur',
      );

      // Save form
      await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
      await tester.pumpAndSettle();

      final spots = await repo.getActiveSpots();
      expect(spots.length, 1);
      final savedSpot = spots.first;
      expect(savedSpot.name, 'Mie Ayam Jamur');
      expect(savedSpot.peakHours.length, 1);
      expect(savedSpot.peakHours.first.days, [1, 2, 3, 4, 5]);
      expect(savedSpot.peakHours.first.start, 11 * 60);
      expect(savedSpot.peakHours.first.end, 14 * 60);
    });
  });
}
