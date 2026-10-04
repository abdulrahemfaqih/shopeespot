import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/peak_range.dart';

class SpotPeakHoursSection extends StatelessWidget {
  const SpotPeakHoursSection({
    super.key,
    required this.peakHours,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<PeakRange> peakHours;
  final VoidCallback onAdd;
  final ValueChanged<PeakRange> onEdit;
  final ValueChanged<PeakRange> onRemove;

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatDays(List<int> days) {
    if (days.length == 7) return 'Setiap hari';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Hari kerja';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Akhir pekan';
    }
    const dayNames = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };
    return days.map((d) => dayNames[d] ?? '$d').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jam ramai manual',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            AppButton.text(label: '+ Tambah jam', onPressed: onAdd),
          ],
        ),
        if (peakHours.isEmpty)
          Text(
            'Belum ada jam ramai manual',
            style: TextStyle(fontSize: 13.0, color: tokens.textSecondary),
          )
        else
          ...peakHours.map((range) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: tokens.space4),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.border,
                  width: tokens.borderWidth,
                ),
              ),
              child: InkWell(
                onTap: () => onEdit(range),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space12,
                    vertical: tokens.space8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${formatDays(range.days)}: ${formatMinutes(range.start)} - ${formatMinutes(range.end)}',
                          style: TextStyle(
                            fontSize: 13.0,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18.0),
                        onPressed: () => onRemove(range),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
