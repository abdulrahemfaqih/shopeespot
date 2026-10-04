import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/map_filter.dart';

class MapFilterNotifier extends Notifier<MapFilter> {
  @override
  MapFilter build() => const MapFilter();

  void setCategory(CategoryFilter category) {
    state = state.copyWith(category: category);
  }

  void setBusy(BusyFilter busy) {
    if (state.busy == busy) {
      state = state.copyWith(busy: BusyFilter.none);
    } else {
      state = state.copyWith(busy: busy);
    }
  }
}

final mapFilterProvider = NotifierProvider<MapFilterNotifier, MapFilter>(
  MapFilterNotifier.new,
);
