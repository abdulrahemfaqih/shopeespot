import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_chip.dart';

class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.selectedDays,
    required this.onToggleDay,
    required this.onApplyPreset,
    this.errorMessage,
  });

  final Set<int> selectedDays;
  final ValueChanged<int> onToggleDay;
  final ValueChanged<Set<int>> onApplyPreset;
  final String? errorMessage;

  bool _isPresetActive(Set<int> preset) {
    if (selectedDays.length != preset.length) return false;
    return selectedDays.containsAll(preset);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    const weekdaysPreset = {1, 2, 3, 4, 5};
    const weekendPreset = {6, 7};
    const everydayPreset = {1, 2, 3, 4, 5, 6, 7};

    const dayMap = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pilihan hari',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        SizedBox(height: tokens.space8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(
                label: 'Hari kerja',
                isSelected: _isPresetActive(weekdaysPreset),
                onTap: () => onApplyPreset(weekdaysPreset),
              ),
              SizedBox(width: tokens.space8),
              AppChip(
                label: 'Akhir pekan',
                isSelected: _isPresetActive(weekendPreset),
                onTap: () => onApplyPreset(weekendPreset),
              ),
              SizedBox(width: tokens.space8),
              AppChip(
                label: 'Setiap hari',
                isSelected: _isPresetActive(everydayPreset),
                onTap: () => onApplyPreset(everydayPreset),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.space12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayMap.entries.map((entry) {
            final day = entry.key;
            final label = entry.value;
            final isSelected = selectedDays.contains(day);

            return InkWell(
              onTap: () => onToggleDay(day),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: isSelected ? tokens.actionFill : tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: isSelected ? tokens.actionFill : tokens.border,
                    width: tokens.borderWidth,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? tokens.actionOnFill
                          : tokens.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (errorMessage != null) ...[
          SizedBox(height: tokens.space8),
          Text(
            errorMessage!,
            style: TextStyle(fontSize: 12.0, color: tokens.danger),
          ),
        ],
      ],
    );
  }
}

class PeakTimeBox extends StatelessWidget {
  const PeakTimeBox({
    super.key,
    required this.label,
    required this.timeString,
    required this.onTap,
  });

  final String label;
  final String timeString;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space12,
          vertical: tokens.space12,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: tokens.border, width: tokens.borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
            ),
            SizedBox(height: tokens.space4),
            Text(
              timeString,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
