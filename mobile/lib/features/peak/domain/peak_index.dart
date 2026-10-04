import '../../../core/time/day_type.dart';
import '../../spots/domain/spot.dart';

const int peakWindowDays = 90;
const int peakMinOrders = 3;
const double peakThresholdRatio = 0.6;

class PeakIndex {
  const PeakIndex({
    this.peakHoursByDayType = const {},
    this.hourlyCounts = const {},
    this.hourlyCountsByDayType = const {},
  });

  /// `Map<DayType, Map<String spotId, Set<int localHour>>>`
  final Map<DayType, Map<String, Set<int>>> peakHoursByDayType;

  /// `Map<String spotId, Map<int localHour, int count>>`
  final Map<String, Map<int, int>> hourlyCounts;

  /// `Map<DayType, Map<String spotId, Map<int localHour, int count>>>`
  final Map<DayType, Map<String, Map<int, int>>> hourlyCountsByDayType;

  /// Returns whether [spot] is in peak hours at [time].
  ///
  /// Uses automatic history if data is sufficient (qualifying hours exist);
  /// otherwise falls back to manual peak hours defined in [spot.peakHours].
  bool isPeakAt(Spot spot, DateTime time) {
    final local = time.toLocal();
    final dayType = DayType.fromDateTime(local);
    final qualifying = peakHoursByDayType[dayType]?[spot.id];

    if (qualifying != null && qualifying.isNotEmpty) {
      return qualifying.contains(local.hour);
    }

    // Fallback to manual peakHours
    final dow = local.weekday;
    final minuteOfDay = local.hour * 60 + local.minute;
    final prevDow = dow == 1 ? 7 : dow - 1;

    for (final range in spot.peakHours) {
      if (!range.crossesMidnight) {
        if (range.days.contains(dow) &&
            minuteOfDay >= range.start &&
            minuteOfDay < range.end) {
          return true;
        }
      } else {
        // Crosses midnight (e.g. 22:00 - 02:00)
        if (range.days.contains(dow) && minuteOfDay >= range.start) {
          return true;
        }
        if (range.days.contains(prevDow) && minuteOfDay < range.end) {
          return true;
        }
      }
    }

    return false;
  }

  /// Returns effective peak hour ranges formatted as strings (e.g. ["11:00-13:00"]).
  List<String> effectiveRanges(Spot spot, DayType dayType) {
    final qualifying = peakHoursByDayType[dayType]?[spot.id];

    if (qualifying != null && qualifying.isNotEmpty) {
      return mergeConsecutiveHours(qualifying);
    }

    // Fallback to manual peakHours overlapping with dayType
    final manualRanges = <String>[];
    for (final range in spot.peakHours) {
      final overlaps = dayType == DayType.weekday
          ? range.days.any((d) => d >= 1 && d <= 5)
          : range.days.any((d) => d >= 6 && d <= 7);

      if (overlaps) {
        manualRanges.add(
          '${_formatMinutes(range.start)}-${_formatMinutes(range.end)}',
        );
      }
    }

    return manualRanges;
  }

  /// Returns a human-readable summary string for effective peak hours.
  /// (e.g. "Ramai 11:00-13:00" or "Belum ada jam ramai").
  String effectiveRangesSummary(Spot spot, DayType dayType) {
    final ranges = effectiveRanges(spot, dayType);
    if (ranges.isEmpty) {
      return 'Belum ada jam ramai';
    }
    return 'Ramai ${ranges.join(', ')}';
  }

  /// Returns the order count for [spotId] on [dayType] at [hour].
  ///
  /// Falls back to [hourlyCounts] if [hourlyCountsByDayType] is not provided.
  int orderCountAt({
    required String spotId,
    required DayType dayType,
    required int hour,
  }) {
    final count = hourlyCountsByDayType[dayType]?[spotId]?[hour];
    if (count != null) return count;
    return hourlyCounts[spotId]?[hour] ?? 0;
  }

  /// Returns the order count for [spotId] at [hour] for order-based sorting.
  int orderCountAtHour(String spotId, int hour) {
    return hourlyCounts[spotId]?[hour] ?? 0;
  }

  /// Merges consecutive hours (including midnight crossing 23 -> 0) into range strings.
  static List<String> mergeConsecutiveHours(Set<int> hours) {
    if (hours.isEmpty) return const [];
    if (hours.length == 24) return const ['00:00-24:00'];

    final ranges = <String>[];

    // Find all interval start points on the 24-hour cycle.
    // An hour is a start point if it is in [hours] and its previous hour is NOT.
    final startPoints = <int>[];
    for (final h in hours) {
      final prev = (h - 1 + 24) % 24;
      if (!hours.contains(prev)) {
        startPoints.add(h);
      }
    }

    // Sort starts chronologically from midnight (0..23)
    startPoints.sort();

    for (final start in startPoints) {
      var current = (start + 1) % 24;
      while (hours.contains(current)) {
        current = (current + 1) % 24;
      }
      final startStr = '${start.toString().padLeft(2, '0')}:00';
      final endStr = '${current.toString().padLeft(2, '0')}:00';
      ranges.add('$startStr-$endStr');
    }

    return ranges;
  }

  static String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
