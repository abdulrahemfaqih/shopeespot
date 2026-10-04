import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/geo/distance_format.dart';
import 'package:shopeespot/core/geo/haversine.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/core/time/day_type.dart';

void main() {
  group('Haversine distance calculation', () {
    test('same coordinates return 0 distance', () {
      expect(haversine(-6.2, 106.8, -6.2, 106.8), 0.0);
    });

    test('calculates correct distance between two known points', () {
      // Monas to Bundaran HI is roughly 2.1 - 2.2 km
      final dist = haversine(-6.1754, 106.8272, -6.1950, 106.8230);
      expect(dist, greaterThan(2.0));
      expect(dist, lessThan(2.4));
    });
  });

  group('Distance format', () {
    test(
      'boundary tests specified in TASK.md T-05 (0 m, 999 m, 1 km, 1.25 km)',
      () {
        // 0 m
        expect(formatDistance(0.0), '0 m');
        expect(formatDistanceMeters(0.0), '0 m');

        // 350 m
        expect(formatDistance(0.35), '350 m');
        expect(formatDistanceMeters(348), '350 m');

        // 999 m (rounds to 1000 m -> 1,0 km)
        expect(formatDistance(0.999), '1,0 km');
        expect(formatDistanceMeters(999), '1,0 km');

        // 1 km
        expect(formatDistance(1.0), '1,0 km');
        expect(formatDistanceMeters(1000), '1,0 km');

        // 1.25 km (rounds to 1,3 km)
        expect(formatDistance(1.25), '1,3 km');
        expect(formatDistanceMeters(1250), '1,3 km');

        // 1.2 km
        expect(formatDistance(1.2), '1,2 km');
        expect(formatDistanceMeters(1200), '1,2 km');
      },
    );
  });

  group('DayType', () {
    test('maps ISO day of week correctly (1-5 weekday, 6-7 weekend)', () {
      expect(DayType.fromDow(1), DayType.weekday); // Monday
      expect(DayType.fromDow(2), DayType.weekday);
      expect(DayType.fromDow(3), DayType.weekday);
      expect(DayType.fromDow(4), DayType.weekday);
      expect(DayType.fromDow(5), DayType.weekday); // Friday

      expect(DayType.fromDow(6), DayType.weekend); // Saturday
      expect(DayType.fromDow(7), DayType.weekend); // Sunday
    });

    test('maps DateTime to DayType correctly', () {
      final saturday = DateTime(2026, 10, 3);
      final sunday = DateTime(2026, 10, 4);
      final monday = DateTime(2026, 10, 5);

      expect(DayType.fromDateTime(saturday), DayType.weekend);
      expect(DayType.fromDateTime(sunday), DayType.weekend);
      expect(DayType.fromDateTime(monday), DayType.weekday);
    });
  });

  group('Clock', () {
    test('SystemClock provides current time', () {
      const clock = SystemClock();
      final before = DateTime.now();
      final clockTime = clock.now();
      final after = DateTime.now();

      expect(
        clockTime.isAfter(before) || clockTime.isAtSameMomentAs(before),
        true,
      );
      expect(
        clockTime.isBefore(after) || clockTime.isAtSameMomentAs(after),
        true,
      );
    });

    test('FixedClock provides predictable mock time and can be updated', () {
      final fixedTime = DateTime.utc(2026, 10, 4, 12, 0);
      final clock = FixedClock(fixedTime);

      expect(clock.now(), fixedTime);

      final nextTime = DateTime.utc(2026, 10, 4, 13, 0);
      clock.setTime(nextTime);
      expect(clock.now(), nextTime);
    });
  });
}
