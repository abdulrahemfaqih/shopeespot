import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/time/day_type.dart';
import 'package:shopeespot/features/map/domain/map_filter.dart';
import 'package:shopeespot/features/map/presentation/map_filter_provider.dart';
import 'package:shopeespot/features/map/presentation/widgets/filter_bar.dart';
import 'package:shopeespot/features/peak/domain/peak_index.dart';
import 'package:shopeespot/features/peak/presentation/peak_provider.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 12, 0); // Monday 12:00 UTC

  final testSpots = [
    Spot(
      id: 'food-1',
      name: 'Ayam Geprek',
      category: Category.shopeefood,
      latitude: -6.2,
      longitude: 106.8,
      peakHours: const [
        PeakRange(days: [1, 2, 3, 4, 5], start: 12 * 60, end: 14 * 60),
      ],
      createdAt: now,
      updatedAt: now,
    ),
    Spot(
      id: 'food-2',
      name: 'Bebek Goreng',
      category: Category.shopeefood,
      latitude: -6.21,
      longitude: 106.81,
      peakHours: const [
        PeakRange(days: [1, 2, 3, 4, 5], start: 13 * 60, end: 15 * 60),
      ],
      createdAt: now,
      updatedAt: now,
    ),
    Spot(
      id: 'spx-1',
      name: 'SPX Hub Tebet',
      category: Category.spx,
      latitude: -6.22,
      longitude: 106.82,
      peakHours: const [],
      createdAt: now,
      updatedAt: now,
    ),
    Spot(
      id: 'food-deleted',
      name: 'Resto Tutup',
      category: Category.shopeefood,
      latitude: -6.23,
      longitude: 106.83,
      deletedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('MapFilter domain pure logic', () {
    test('filters all active spots when CategoryFilter.all', () {
      const filter = MapFilter(category: CategoryFilter.all);
      final result = filter.apply(testSpots);

      expect(result.length, 3);
      expect(
        result.map((s) => s.id),
        containsAll(['food-1', 'food-2', 'spx-1']),
      );
      expect(result.any((s) => s.id == 'food-deleted'), false);
    });

    test('filters only ShopeeFood spots when CategoryFilter.shopeefood', () {
      const filter = MapFilter(category: CategoryFilter.shopeefood);
      final result = filter.apply(testSpots);

      expect(result.length, 2);
      expect(result.every((s) => s.category == Category.shopeefood), true);
      expect(result.map((s) => s.id), containsAll(['food-1', 'food-2']));
    });

    test('filters only SPX spots when CategoryFilter.spx', () {
      const filter = MapFilter(category: CategoryFilter.spx);
      final result = filter.apply(testSpots);

      expect(result.length, 1);
      expect(result.first.id, 'spx-1');
      expect(result.first.category, Category.spx);
    });

    test('copyWith and value equality', () {
      const filter1 = MapFilter();
      final filter2 = filter1.copyWith(category: CategoryFilter.shopeefood);
      final filter3 = const MapFilter().copyWith(
        category: CategoryFilter.shopeefood,
      );

      expect(filter1.category, CategoryFilter.all);
      expect(filter2.category, CategoryFilter.shopeefood);
      expect(filter2, filter3);
      expect(filter1 == filter2, false);
      expect(filter2.hashCode, filter3.hashCode);
    });

    test('filters busyNow using PeakIndex', () {
      // Mock PeakIndex where food-1 is peak at hour 12, food-2 is peak at hour 13
      const peakIndex = PeakIndex(
        peakHoursByDayType: {
          DayType.weekday: {
            'food-1': {12},
            'food-2': {13},
          },
        },
      );

      final checkTime = DateTime(2026, 10, 5, 12, 15); // Monday 12:15
      const filter = MapFilter(busy: BusyFilter.busyNow);
      final result = filter.apply(
        testSpots,
        peakIndex: peakIndex,
        now: checkTime,
      );

      expect(result.length, 1);
      expect(result.first.id, 'food-1');
    });

    test('filters busy30Min using PeakIndex', () {
      // At 12:35 Monday: 12:35 + 30m = 13:05 (hour 13)
      // food-2 is peak at hour 13!
      const peakIndex = PeakIndex(
        peakHoursByDayType: {
          DayType.weekday: {
            'food-1': {12},
            'food-2': {13},
          },
        },
      );

      final checkTime = DateTime(2026, 10, 5, 12, 35);
      const filter = MapFilter(busy: BusyFilter.busy30Min);
      final result = filter.apply(
        testSpots,
        peakIndex: peakIndex,
        now: checkTime,
      );

      expect(result.length, 1);
      expect(result.first.id, 'food-2');
    });

    test('combines category and busy filter', () {
      const peakIndex = PeakIndex(
        peakHoursByDayType: {
          DayType.weekday: {
            'food-1': {12},
            'spx-1': {12},
          },
        },
      );

      final checkTime = DateTime(2026, 10, 5, 12, 10);
      const filter = MapFilter(
        category: CategoryFilter.spx,
        busy: BusyFilter.busyNow,
      );
      final result = filter.apply(
        testSpots,
        peakIndex: peakIndex,
        now: checkTime,
      );

      expect(result.length, 1);
      expect(result.first.id, 'spx-1');
    });
  });

  group('MapFilterNotifier', () {
    test('initial state is default all and none', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mapFilterProvider);
      expect(state.category, CategoryFilter.all);
      expect(state.busy, BusyFilter.none);
    });

    test('setCategory updates category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(mapFilterProvider.notifier)
          .setCategory(CategoryFilter.spx);
      expect(container.read(mapFilterProvider).category, CategoryFilter.spx);
    });

    test('setBusy toggles and is mutually exclusive', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapFilterProvider.notifier).setBusy(BusyFilter.busyNow);
      expect(container.read(mapFilterProvider).busy, BusyFilter.busyNow);

      // Switching to busy30Min clears busyNow
      container.read(mapFilterProvider.notifier).setBusy(BusyFilter.busy30Min);
      expect(container.read(mapFilterProvider).busy, BusyFilter.busy30Min);

      // Tapping same again turns it off
      container.read(mapFilterProvider.notifier).setBusy(BusyFilter.busy30Min);
      expect(container.read(mapFilterProvider).busy, BusyFilter.none);
    });
  });

  group('FilterBar widget and filteredSpotsProvider with Clock', () {
    testWidgets(
      'renders all chips, changes selection, and filters spots with fake Clock',
      (tester) async {
        final clock = FixedClock(DateTime(2026, 10, 5, 12, 15)); // Monday 12:15
        const peakIndex = PeakIndex(
          peakHoursByDayType: {
            DayType.weekday: {
              'food-1': {12},
              'food-2': {13},
            },
          },
        );

        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            activeSpotsStreamProvider.overrideWith(
              (ref) => Stream.value(testSpots),
            ),
            peakIndexProvider.overrideWith((ref) => peakIndex),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: FilterBar()),
            ),
          ),
        );

        await container.read(activeSpotsStreamProvider.future);
        await tester.pump();

        // Verify all 5 chips exist
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('ShopeeFood'), findsOneWidget);
        expect(find.text('SPX'), findsOneWidget);
        expect(find.text('Ramai sekarang'), findsOneWidget);
        expect(find.text('Ramai 30 mnt lagi'), findsOneWidget);

        // Initially 'Semua' is active, all 3 spots
        expect(container.read(filteredSpotsProvider).length, 3);

        // Tap 'Ramai sekarang' (at 12:15, only food-1 is peak)
        await tester.tap(find.text('Ramai sekarang'));
        await tester.pump();

        expect(container.read(mapFilterProvider).busy, BusyFilter.busyNow);
        var filtered = container.read(filteredSpotsProvider);
        expect(filtered.length, 1);
        expect(filtered.first.id, 'food-1');

        // Tap 'Ramai 30 mnt lagi' (at 12:15 + 30m = 12:45, hour 12 -> food-1 is still peak)
        // Advance clock to 12:35 -> 12:35 + 30m = 13:05 (hour 13 -> food-2 is peak)
        clock.setTime(DateTime(2026, 10, 5, 12, 35));
        await tester.tap(find.text('Ramai 30 mnt lagi'));
        await tester.pump();

        expect(container.read(mapFilterProvider).busy, BusyFilter.busy30Min);
        filtered = container.read(filteredSpotsProvider);
        expect(filtered.length, 1);
        expect(filtered.first.id, 'food-2');

        // Tap 'Ramai 30 mnt lagi' again to turn off busy filter
        await tester.tap(find.text('Ramai 30 mnt lagi'));
        await tester.pump();

        expect(container.read(mapFilterProvider).busy, BusyFilter.none);
        expect(container.read(filteredSpotsProvider).length, 3);
      },
    );
  });
}
