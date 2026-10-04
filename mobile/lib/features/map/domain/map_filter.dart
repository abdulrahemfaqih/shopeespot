import '../../peak/domain/peak_index.dart';
import '../../spots/domain/category.dart';
import '../../spots/domain/spot.dart';

enum CategoryFilter { all, shopeefood, spx }

enum BusyFilter { none, busyNow, busy30Min }

class MapFilter {
  const MapFilter({
    this.category = CategoryFilter.all,
    this.busy = BusyFilter.none,
  });

  final CategoryFilter category;
  final BusyFilter busy;

  MapFilter copyWith({CategoryFilter? category, BusyFilter? busy}) {
    return MapFilter(
      category: category ?? this.category,
      busy: busy ?? this.busy,
    );
  }

  /// Pure function to filter spots based on category and status.
  List<Spot> apply(List<Spot> spots, {PeakIndex? peakIndex, DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();

    return spots.where((spot) {
      if (spot.isDeleted) return false;

      switch (category) {
        case CategoryFilter.all:
          break;
        case CategoryFilter.shopeefood:
          if (spot.category != Category.shopeefood) return false;
          break;
        case CategoryFilter.spx:
          if (spot.category != Category.spx) return false;
          break;
      }

      if (busy != BusyFilter.none) {
        if (peakIndex == null) return false;

        final checkTime = busy == BusyFilter.busyNow
            ? effectiveNow
            : effectiveNow.add(const Duration(minutes: 30));

        if (!peakIndex.isPeakAt(spot, checkTime)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapFilter &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          busy == other.busy;

  @override
  int get hashCode => category.hashCode ^ busy.hashCode;
}
