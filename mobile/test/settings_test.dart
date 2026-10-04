import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/app.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/app/theme/theme_provider.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/navigation/navigation_launcher.dart';
import 'package:shopeespot/features/backup/data/backup_service.dart';
import 'package:shopeespot/features/backup/presentation/backup_providers.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/orders/presentation/orders_providers.dart';
import 'package:shopeespot/features/settings/presentation/settings_screen.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier state and persistence', () {
    test('defaults to ThemeMode.system and persists updates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(prefThemeModeKey), 'dark');
    });

    test('restores saved theme mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({prefThemeModeKey: 'light'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger lazy load
      final initial = container.read(themeModeProvider);
      // Wait for async load from prefs
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(initial, isA<ThemeMode>());
    });
  });

  group('SettingsScreen widget UI and interactions', () {
    testWidgets(
      'renders all 6 rows and allows changing theme and navigation app',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            themeModeProvider.overrideWith(ThemeModeNotifier.new),
            navigationAppProvider.overrideWith(NavigationAppNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 6 rows rendered
        expect(find.text('Tema'), findsOneWidget);
        expect(find.text('Aplikasi navigasi'), findsOneWidget);
        expect(find.text('Cadangan'), findsOneWidget);
        expect(find.text('Sinkronisasi'), findsOneWidget);
        expect(find.text('Akun'), findsOneWidget);
        expect(find.text('Versi aplikasi'), findsOneWidget);
        expect(find.text('1.0.0'), findsOneWidget);

        // Tap Tema row
        await tester.tap(find.text('Tema'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih tema'), findsOneWidget);
        expect(find.text('Sistem'), findsWidgets);
        expect(find.text('Terang'), findsOneWidget);
        expect(find.text('Gelap'), findsOneWidget);

        // Select Gelap
        await tester.tap(find.text('Gelap'));
        await tester.pumpAndSettle();

        // Sheet closed and theme updated
        expect(find.text('Pilih tema'), findsNothing);
        expect(container.read(themeModeProvider), ThemeMode.dark);
        expect(find.text('Gelap'), findsOneWidget);

        // Tap Aplikasi navigasi row
        await tester.tap(find.text('Aplikasi navigasi'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih aplikasi navigasi'), findsOneWidget);
        expect(find.text('Google Maps'), findsWidgets);
        expect(find.text('Waze'), findsOneWidget);

        // Select Waze
        await tester.tap(find.text('Waze'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih aplikasi navigasi'), findsNothing);
        expect(container.read(navigationAppProvider), NavigationApp.waze);
        expect(find.text('Waze'), findsOneWidget);
      },
    );

    testWidgets('shows backup options and handles export and import', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final spotRepo = SpotRepository(db: db);
      final orderRepo = OrderRepository(db: db, spotRepository: spotRepo);

      var shareCalled = false;
      final tempDir = Directory.systemTemp.createTempSync(
        'settings_backup_test_',
      );

      final backupService = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        tempDirFn: () async => tempDir,
        shareFn: (filePath, fileName) async {
          shareCalled = true;
        },
        pickFileFn: () async => jsonEncode({
          'app': 'spotshopee',
          'version': 1,
          'exported_at': '2026-10-04T12:00:00Z',
          'spots': [
            {
              'id': 'sp-imported',
              'name': 'Spot Imported UI',
              'category': 'shopeefood',
              'latitude': -6.2,
              'longitude': 106.8,
              'created_at': '2026-10-04T12:00:00Z',
              'updated_at': '2026-10-04T12:00:00Z',
            },
          ],
          'orders': [],
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith(ThemeModeNotifier.new),
            navigationAppProvider.overrideWith(NavigationAppNotifier.new),
            appDatabaseProvider.overrideWithValue(db),
            spotRepositoryProvider.overrideWithValue(spotRepo),
            orderRepositoryProvider.overrideWithValue(orderRepo),
            backupServiceProvider.overrideWithValue(backupService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Cadangan row
      await tester.tap(find.text('Cadangan'));
      await tester.pumpAndSettle();

      // Check bottom sheet options
      expect(find.text('Ekspor semua data'), findsOneWidget);
      expect(find.text('Ekspor hanya spot'), findsOneWidget);
      expect(find.text('Impor data (JSON)'), findsOneWidget);

      // Tap Ekspor semua data
      await tester.tap(find.text('Ekspor semua data'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(shareCalled, isTrue);

      // Tap Cadangan row again for import
      await tester.tap(find.text('Cadangan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Impor data (JSON)'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Summary dialog shown
      expect(find.text('Ringkasan Impor'), findsOneWidget);
      expect(find.textContaining('Spot: 1 ditambah'), findsOneWidget);

      // Tap Tutup
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Impor'), findsNothing);

      // Verify spot was imported into repository
      final spot = await spotRepo.getSpotById('sp-imported');
      expect(spot, isNotNull);
      expect(spot?.name, 'Spot Imported UI');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });
  });

  group('SpotShopeeApp and dark theme tile integration', () {
    testWidgets(
      'SpotShopeeApp updates themeMode and navigates to SettingsScreen from map',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              filteredSpotsProvider.overrideWithValue(<Spot>[]),
              activeSpotsStreamProvider.overrideWith(
                (ref) => Stream.value(<Spot>[]),
              ),
            ],
            child: const SpotShopeeApp(),
          ),
        );

        await tester.pumpAndSettle();

        // MapScreen is rendered
        expect(find.byType(MapScreen), findsOneWidget);

        // Ensure settings button is visible in scrollable filter bar and tap it
        await tester.ensureVisible(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        // SettingsScreen is pushed
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Back navigation
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MapScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
