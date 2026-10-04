import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../domain/map_filter.dart';
import '../map_filter_provider.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final filter = ref.watch(mapFilterProvider);
    final notifier = ref.read(mapFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: tokens.space16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppChip(
            label: 'Semua',
            isSelected: filter.category == CategoryFilter.all,
            onTap: () => notifier.setCategory(CategoryFilter.all),
          ),
          SizedBox(width: tokens.space8),
          AppChip(
            label: 'ShopeeFood',
            isSelected: filter.category == CategoryFilter.shopeefood,
            onTap: () => notifier.setCategory(CategoryFilter.shopeefood),
          ),
          SizedBox(width: tokens.space8),
          AppChip(
            label: 'SPX',
            isSelected: filter.category == CategoryFilter.spx,
            onTap: () => notifier.setCategory(CategoryFilter.spx),
          ),
          Container(
            height: 24.0,
            width: tokens.borderWidth,
            color: tokens.border,
            margin: EdgeInsets.symmetric(horizontal: tokens.space8),
          ),
          AppChip(
            label: 'Ramai sekarang',
            isSelected: filter.busy == BusyFilter.busyNow,
            onTap: () => notifier.setBusy(BusyFilter.busyNow),
          ),
          SizedBox(width: tokens.space8),
          AppChip(
            label: 'Ramai 30 mnt lagi',
            isSelected: filter.busy == BusyFilter.busy30Min,
            onTap: () => notifier.setBusy(BusyFilter.busy30Min),
          ),
          Container(
            height: 24.0,
            width: tokens.borderWidth,
            color: tokens.border,
            margin: EdgeInsets.symmetric(horizontal: tokens.space8),
          ),
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: tokens.border,
                width: tokens.borderWidth,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: Center(
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20.0,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
