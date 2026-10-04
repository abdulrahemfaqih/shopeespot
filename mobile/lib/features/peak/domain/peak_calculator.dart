import 'dart:math' as math;
import '../../../core/time/day_type.dart';
import '../../orders/data/order_dao.dart';
import '../../orders/data/order_repository.dart';
import 'peak_index.dart';

class PeakCalculator {
  const PeakCalculator({
    this.windowDays = peakWindowDays,
    this.minOrders = peakMinOrders,
    this.thresholdRatio = peakThresholdRatio,
  });

  final int windowDays;
  final int minOrders;
  final double thresholdRatio;

  /// Pure function that calculates a [PeakIndex] from raw aggregation results.
  PeakIndex buildIndex({
    required List<PeakHourAggregation> weekdayAggregations,
    required List<PeakHourAggregation> weekendAggregations,
  }) {
    final peakHoursByDayType = <DayType, Map<String, Set<int>>>{
      DayType.weekday: _computeQualifyingHours(weekdayAggregations),
      DayType.weekend: _computeQualifyingHours(weekendAggregations),
    };

    final hourlyCounts = <String, Map<int, int>>{};
    final hourlyCountsByDayType = <DayType, Map<String, Map<int, int>>>{
      DayType.weekday: {},
      DayType.weekend: {},
    };

    for (final agg in weekdayAggregations) {
      final spotCounts = hourlyCounts.putIfAbsent(agg.spotId, () => {});
      spotCounts[agg.localHour] = (spotCounts[agg.localHour] ?? 0) + agg.count;

      final dayCounts = hourlyCountsByDayType[DayType.weekday]!.putIfAbsent(
        agg.spotId,
        () => {},
      );
      dayCounts[agg.localHour] = (dayCounts[agg.localHour] ?? 0) + agg.count;
    }

    for (final agg in weekendAggregations) {
      final spotCounts = hourlyCounts.putIfAbsent(agg.spotId, () => {});
      spotCounts[agg.localHour] = (spotCounts[agg.localHour] ?? 0) + agg.count;

      final dayCounts = hourlyCountsByDayType[DayType.weekend]!.putIfAbsent(
        agg.spotId,
        () => {},
      );
      dayCounts[agg.localHour] = (dayCounts[agg.localHour] ?? 0) + agg.count;
    }

    return PeakIndex(
      peakHoursByDayType: peakHoursByDayType,
      hourlyCounts: hourlyCounts,
      hourlyCountsByDayType: hourlyCountsByDayType,
    );
  }

  Map<String, Set<int>> _computeQualifyingHours(
    List<PeakHourAggregation> aggregations,
  ) {
    // 1. Group by spotId
    final bySpot = <String, Map<int, int>>{};
    for (final agg in aggregations) {
      final hours = bySpot.putIfAbsent(agg.spotId, () => {});
      hours[agg.localHour] = (hours[agg.localHour] ?? 0) + agg.count;
    }

    // 2. For each spot, calculate maxCount and qualify hours
    final result = <String, Set<int>>{};
    bySpot.forEach((spotId, hours) {
      if (hours.isEmpty) return;

      int maxCount = 0;
      for (final cnt in hours.values) {
        maxCount = math.max(maxCount, cnt);
      }

      final qualifying = <int>{};
      final threshold = maxCount * thresholdRatio;

      hours.forEach((hour, count) {
        if (count >= minOrders && count >= threshold) {
          qualifying.add(hour);
        }
      });

      if (qualifying.isNotEmpty) {
        result[spotId] = qualifying;
      }
    });

    return result;
  }

  /// Calculates a [PeakIndex] from the database via [orderRepo].
  Future<PeakIndex> calculateFromRepository(
    OrderRepository orderRepo, {
    DateTime? currentDateTime,
  }) async {
    final now = currentDateTime ?? DateTime.now();
    final since = now.subtract(Duration(days: windowDays)).toUtc();

    final weekdayAggs = await orderRepo.getPeakOrderAggregation(
      since: since,
      dowMin: 1,
      dowMax: 5,
    );

    final weekendAggs = await orderRepo.getPeakOrderAggregation(
      since: since,
      dowMin: 6,
      dowMax: 7,
    );

    return buildIndex(
      weekdayAggregations: weekdayAggs,
      weekendAggregations: weekendAggs,
    );
  }
}
