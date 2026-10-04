import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/time/day_type.dart';
import 'package:shopeespot/features/orders/data/order_dao.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/peak/domain/peak_calculator.dart';
import 'package:shopeespot/features/peak/domain/peak_index.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';

void main() {
  const calculator = PeakCalculator();

  group('T-17 PeakIndex and PeakCalculator threshold logic', () {
    test(
      'threshold: min 3 orders and 60% of max in same spot and day type',
      () {
        // Spot 1 has:
        // hour 11: 10 orders (max)
        // hour 12: 6 orders (60% of max, and >= 3) -> qualifies
        // hour 13: 5 orders (50% of max < 60%) -> does NOT qualify
        // hour 14: 2 orders (< 3 min orders) -> does NOT qualify
        final weekdayAggs = [
          const PeakHourAggregation(spotId: 'spot-1', localHour: 11, count: 10),
          const PeakHourAggregation(spotId: 'spot-1', localHour: 12, count: 6),
          const PeakHourAggregation(spotId: 'spot-1', localHour: 13, count: 5),
          const PeakHourAggregation(spotId: 'spot-1', localHour: 14, count: 2),
        ];

        final index = calculator.buildIndex(
          weekdayAggregations: weekdayAggs,
          weekendAggregations: const [],
        );

        final weekdayPeaks =
            index.peakHoursByDayType[DayType.weekday]?['spot-1'];
        expect(weekdayPeaks, isNotNull);
        expect(weekdayPeaks, contains(11));
        expect(weekdayPeaks, contains(12));
        expect(weekdayPeaks, isNot(contains(13)));
        expect(weekdayPeaks, isNot(contains(14)));
      },
    );

    test('threshold: exactly minOrders (3) qualifies if >= 60% of max', () {
      // Max is 3. 3 >= 3, and 3/3 = 100% >= 60% -> hour 11 qualifies.
      // Hour 12 has 2 orders: 2/3 = 66.7% >= 60%, BUT 2 < 3 -> does NOT qualify!
      final weekdayAggs = [
        const PeakHourAggregation(
          spotId: 'spot-small',
          localHour: 11,
          count: 3,
        ),
        const PeakHourAggregation(
          spotId: 'spot-small',
          localHour: 12,
          count: 2,
        ),
      ];

      final index = calculator.buildIndex(
        weekdayAggregations: weekdayAggs,
        weekendAggregations: const [],
      );

      final peaks = index.peakHoursByDayType[DayType.weekday]?['spot-small'];
      expect(peaks, {11});
    });

    test(
      'data kurang: max < 3 orders yields no qualifying automatic hours',
      () {
        final weekdayAggs = [
          const PeakHourAggregation(
            spotId: 'spot-low',
            localHour: 12,
            count: 2,
          ),
          const PeakHourAggregation(
            spotId: 'spot-low',
            localHour: 13,
            count: 1,
          ),
        ];

        final index = calculator.buildIndex(
          weekdayAggregations: weekdayAggs,
          weekendAggregations: const [],
        );

        final peaks = index.peakHoursByDayType[DayType.weekday]?['spot-low'];
        expect(peaks, isNull);
      },
    );
  });

  group('T-17 Automatic history vs Manual fallback', () {
    final now = DateTime.utc(2026, 10, 5, 12, 0); // Monday (weekday)
    final spotWithManual = Spot(
      id: 'spot-fallback',
      name: 'Kedai Kopi',
      category: Category.shopeefood,
      latitude: -6.2,
      longitude: 106.8,
      peakHours: const [
        PeakRange(days: [1, 2, 3, 4, 5], start: 9 * 60, end: 11 * 60),
      ],
      lastVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    test('uses automatic history when data is sufficient', () {
      final index = calculator.buildIndex(
        weekdayAggregations: [
          const PeakHourAggregation(
            spotId: 'spot-fallback',
            localHour: 13,
            count: 5,
          ),
          const PeakHourAggregation(
            spotId: 'spot-fallback',
            localHour: 14,
            count: 4,
          ),
        ],
        weekendAggregations: const [],
      );

      // At 13:30 Monday: automatic has 13 -> is peak!
      final monday1330 = DateTime(2026, 10, 5, 13, 30);
      expect(index.isPeakAt(spotWithManual, monday1330), true);

      // At 10:00 Monday: manual has 9-11, BUT automatic takes precedence (manual ignored when data sufficient)
      final monday1000 = DateTime(2026, 10, 5, 10, 0);
      expect(index.isPeakAt(spotWithManual, monday1000), false);

      // Effective ranges reflect automatic merged range
      final ranges = index.effectiveRanges(spotWithManual, DayType.weekday);
      expect(ranges, ['13:00-15:00']);
      expect(
        index.effectiveRangesSummary(spotWithManual, DayType.weekday),
        'Ramai 13:00-15:00',
      );
    });

    test('falls back to manual when data is insufficient', () {
      // Empty data
      final index = calculator.buildIndex(
        weekdayAggregations: const [],
        weekendAggregations: const [],
      );

      // At 10:00 Monday: falls back to manual range 9:00 - 11:00 -> is peak!
      final monday1000 = DateTime(2026, 10, 5, 10, 0);
      expect(index.isPeakAt(spotWithManual, monday1000), true);

      // At 12:00 Monday: outside manual range -> false
      final monday1200 = DateTime(2026, 10, 5, 12, 0);
      expect(index.isPeakAt(spotWithManual, monday1200), false);

      // Effective ranges reflect manual fallback
      final ranges = index.effectiveRanges(spotWithManual, DayType.weekday);
      expect(ranges, ['09:00-11:00']);
      expect(
        index.effectiveRangesSummary(spotWithManual, DayType.weekday),
        'Ramai 09:00-11:00',
      );
    });

    test(
      'returns Belum ada jam ramai when both automatic and manual are empty',
      () {
        final spotEmpty = Spot(
          id: 'spot-empty',
          name: 'Spot Polos',
          category: Category.spx,
          latitude: -6.2,
          longitude: 106.8,
          peakHours: const [],
          lastVerifiedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final index = const PeakIndex();
        expect(index.isPeakAt(spotEmpty, DateTime(2026, 10, 5, 12, 0)), false);
        expect(index.effectiveRanges(spotEmpty, DayType.weekday), isEmpty);
        expect(
          index.effectiveRangesSummary(spotEmpty, DayType.weekday),
          'Belum ada jam ramai',
        );
      },
    );
  });

  group('T-17 Weekday vs Weekend separation', () {
    test('weekday data does not spill into weekend and vice versa', () {
      final index = calculator.buildIndex(
        weekdayAggregations: [
          const PeakHourAggregation(
            spotId: 'spot-sep',
            localHour: 12,
            count: 5,
          ),
        ],
        weekendAggregations: [
          const PeakHourAggregation(
            spotId: 'spot-sep',
            localHour: 19,
            count: 6,
          ),
        ],
      );

      final spot = Spot(
        id: 'spot-sep',
        name: 'Resto Separated',
        category: Category.shopeefood,
        latitude: -6.2,
        longitude: 106.8,
        lastVerifiedAt: DateTime.utc(2026, 10, 4),
        createdAt: DateTime.utc(2026, 10, 4),
        updatedAt: DateTime.utc(2026, 10, 4),
      );

      // Monday 12:00 -> Weekday peak (hour 12)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 5, 12, 0)), true);
      // Monday 19:00 -> Not weekday peak
      expect(index.isPeakAt(spot, DateTime(2026, 10, 5, 19, 0)), false);

      // Saturday 12:00 -> Not weekend peak
      expect(index.isPeakAt(spot, DateTime(2026, 10, 10, 12, 0)), false);
      // Saturday 19:00 -> Weekend peak (hour 19)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 10, 19, 0)), true);

      // Effective ranges per DayType
      expect(index.effectiveRanges(spot, DayType.weekday), ['12:00-13:00']);
      expect(index.effectiveRanges(spot, DayType.weekend), ['19:00-20:00']);
    });
  });

  group('T-17 Midnight crossing (22:00 - 02:00)', () {
    test('mergeConsecutiveHours wraps around midnight correctly', () {
      // 22:00 to 02:00 spans hours: 22, 23, 0, 1
      final merged = PeakIndex.mergeConsecutiveHours({22, 23, 0, 1});
      expect(merged, ['22:00-02:00']);

      // Multiple intervals with one wrapping midnight
      // 11:00-13:00 (11, 12) and 22:00-01:00 (22, 23, 0)
      final multiple = PeakIndex.mergeConsecutiveHours({11, 12, 22, 23, 0});
      expect(multiple, contains('11:00-13:00'));
      expect(multiple, contains('22:00-01:00'));
    });

    test('manual range crossing midnight evaluates correctly across dates', () {
      // Spot open Monday night 22:00 to 02:00
      final spot = Spot(
        id: 'spot-night',
        name: 'Warkop Malam',
        category: Category.shopeefood,
        latitude: -6.2,
        longitude: 106.8,
        peakHours: const [
          PeakRange(
            days: [1],
            start: 22 * 60,
            end: 2 * 60,
          ), // Monday 22:00 - 02:00
        ],
        lastVerifiedAt: DateTime.utc(2026, 10, 5),
        createdAt: DateTime.utc(2026, 10, 5),
        updatedAt: DateTime.utc(2026, 10, 5),
      );

      final index = const PeakIndex(); // empty automatic -> fallback to manual

      // Monday 2026-10-05 at 21:59 -> false (not yet)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 5, 21, 59)), false);

      // Monday 2026-10-05 at 22:00 -> true
      expect(index.isPeakAt(spot, DateTime(2026, 10, 5, 22, 0)), true);

      // Monday 2026-10-05 at 23:30 -> true
      expect(index.isPeakAt(spot, DateTime(2026, 10, 5, 23, 30)), true);

      // Tuesday 2026-10-06 at 00:30 -> true (Monday night shift crossing midnight)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 6, 0, 30)), true);

      // Tuesday 2026-10-06 at 01:59 -> true
      expect(index.isPeakAt(spot, DateTime(2026, 10, 6, 1, 59)), true);

      // Tuesday 2026-10-06 at 02:00 -> false (shift closed)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 6, 2, 0)), false);

      // Tuesday 2026-10-06 at 22:30 -> false (only Monday was configured)
      expect(index.isPeakAt(spot, DateTime(2026, 10, 6, 22, 30)), false);
    });
  });

  group('T-17 Database calculation via OrderRepository', () {
    late AppDatabase db;
    late FixedClock clock;
    late SpotRepository spotRepo;
    late OrderRepository orderRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      clock = FixedClock(DateTime.utc(2026, 10, 5, 12, 0));
      spotRepo = SpotRepository(db: db, clock: clock);
      orderRepo = OrderRepository(
        db: db,
        spotRepository: spotRepo,
        clock: clock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'calculateFromRepository queries SQLite and respects 90-day window',
      () async {
        final spot = await spotRepo.createSpot(
          id: 'spot-db-1',
          name: 'Ayam Geprek Bensu',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        // Record 4 orders at 12:00 on weekdays within 90 days
        for (int i = 0; i < 4; i++) {
          await orderRepo.recordOrder(
            spotId: spot.id,
            orderedAt: DateTime.utc(2026, 10, 5, 12, 10), // Monday 12:10 UTC
          );
        }

        // Record 1 order at 12:00 older than 90 days (100 days ago)
        await orderRepo.recordOrder(
          spotId: spot.id,
          orderedAt: DateTime.utc(2026, 6, 1, 12, 10),
        );

        // Record 1 order that is soft-deleted
        final delOrder = await orderRepo.recordOrder(
          spotId: spot.id,
          orderedAt: DateTime.utc(2026, 10, 5, 12, 15),
        );
        await orderRepo.softDeleteOrder(delOrder.id);

        final index = await calculator.calculateFromRepository(
          orderRepo,
          currentDateTime: DateTime.utc(2026, 10, 5, 12, 0),
        );

        final localHour = DateTime.utc(2026, 10, 5, 12, 10).toLocal().hour;
        final weekdayPeaks =
            index.peakHoursByDayType[DayType.weekday]?[spot.id];
        expect(weekdayPeaks, contains(localHour));

        // Hourly count should be exactly 4 (excludes >90d and soft-deleted)
        expect(index.orderCountAtHour(spot.id, localHour), 4);
      },
    );
  });
}
