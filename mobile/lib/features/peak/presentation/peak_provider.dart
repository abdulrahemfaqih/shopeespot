import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/presentation/orders_providers.dart';
import '../domain/peak_calculator.dart';
import '../domain/peak_index.dart';

final peakCalculatorProvider = Provider<PeakCalculator>((ref) {
  return const PeakCalculator();
});

final peakIndexProvider = FutureProvider<PeakIndex>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final calculator = ref.watch(peakCalculatorProvider);
  return calculator.calculateFromRepository(orderRepo);
});
