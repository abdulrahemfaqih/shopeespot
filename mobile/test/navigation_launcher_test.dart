import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/navigation/navigation_launcher.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/features/orders/presentation/orders_providers.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/widgets/spot_detail_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NavigationLauncher URI construction', () {
    final launcher = NavigationLauncher();

    test('Google Maps primary and fallback URI', () {
      final primary = launcher.buildPrimaryUri(
        NavigationApp.googleMaps,
        -6.2088,
        106.8456,
      );
      expect(primary.toString(), 'google.navigation:q=-6.2088,106.8456&mode=l');

      final fallback = launcher.buildFallbackUri(
        NavigationApp.googleMaps,
        -6.2088,
        106.8456,
      );
      expect(
        fallback.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=-6.2088,106.8456&travelmode=two-wheeler',
      );
    });

    test('Waze primary and fallback URI', () {
      final primary = launcher.buildPrimaryUri(
        NavigationApp.waze,
        -6.2088,
        106.8456,
      );
      expect(primary.toString(), 'waze://?ll=-6.2088,106.8456&navigate=yes');

      final fallback = launcher.buildFallbackUri(
        NavigationApp.waze,
        -6.2088,
        106.8456,
      );
      expect(
        fallback.toString(),
        'https://waze.com/ul?ll=-6.2088,106.8456&navigate=yes',
      );
    });
  });

  group('NavigationLauncher launch logic', () {
    test('returns true when primary URI succeeds', () async {
      final attemptedUrls = <Uri>[];
      final launcher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          attemptedUrls.add(url);
          return true;
        },
      );

      final result = await launcher.launch(
        latitude: -6.2,
        longitude: 106.8,
        app: NavigationApp.googleMaps,
      );

      expect(result, true);
      expect(attemptedUrls.length, 1);
      expect(attemptedUrls.first.scheme, 'google.navigation');
    });

    test('falls back to web URL when primary returns false', () async {
      final attemptedUrls = <Uri>[];
      final launcher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          attemptedUrls.add(url);
          // primary fails, fallback succeeds
          return url.scheme == 'https';
        },
      );

      final result = await launcher.launch(
        latitude: -6.2,
        longitude: 106.8,
        app: NavigationApp.googleMaps,
      );

      expect(result, true);
      expect(attemptedUrls.length, 2);
      expect(attemptedUrls[0].scheme, 'google.navigation');
      expect(attemptedUrls[1].scheme, 'https');
      expect(attemptedUrls[1].host, 'www.google.com');
    });

    test('falls back to web URL when primary throws exception', () async {
      final attemptedUrls = <Uri>[];
      final launcher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          attemptedUrls.add(url);
          if (url.scheme == 'google.navigation') {
            throw Exception('App not installed');
          }
          return true;
        },
      );

      final result = await launcher.launch(
        latitude: -6.2,
        longitude: 106.8,
        app: NavigationApp.googleMaps,
      );

      expect(result, true);
      expect(attemptedUrls.length, 2);
      expect(attemptedUrls[1].scheme, 'https');
    });

    test('returns false when both primary and fallback fail', () async {
      final launcher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          return false;
        },
      );

      final result = await launcher.launch(
        latitude: -6.2,
        longitude: 106.8,
        app: NavigationApp.waze,
      );

      expect(result, false);
    });
  });

  group('NavigationAppNotifier state and persistence', () {
    test('persists app selection to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationAppProvider), NavigationApp.googleMaps);

      await container
          .read(navigationAppProvider.notifier)
          .setApp(NavigationApp.waze);

      expect(container.read(navigationAppProvider), NavigationApp.waze);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(prefNavigationAppKey), NavigationApp.waze.name);
    });
  });

  group('SpotDetailSheet Arahkan button integration', () {
    final now = DateTime.utc(2026, 10, 4, 10, 0);
    final spot = Spot(
      id: 'spot-nav-1',
      name: 'Warung Nasi Uduk',
      category: Category.shopeefood,
      latitude: -6.2,
      longitude: 106.8,
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('tapping Arahkan triggers navigation launcher', (tester) async {
      final launchedUris = <Uri>[];
      final fakeLauncher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          launchedUris.add(url);
          return true;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navigationLauncherProvider.overrideWithValue(fakeLauncher),
            spotOrdersCountTodayProvider(spot.id).overrideWith((ref) => 0),
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

      await tester.tap(find.widgetWithText(AppButton, 'Arahkan'));
      await tester.pumpAndSettle();

      expect(launchedUris.length, 1);
      expect(launchedUris.first.scheme, 'google.navigation');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('shows snackbar when navigation fails', (tester) async {
      final failingLauncher = NavigationLauncher(
        launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
          return false;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navigationLauncherProvider.overrideWithValue(failingLauncher),
            spotOrdersCountTodayProvider(spot.id).overrideWith((ref) => 0),
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

      await tester.tap(find.widgetWithText(AppButton, 'Arahkan'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal membuka aplikasi navigasi.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
