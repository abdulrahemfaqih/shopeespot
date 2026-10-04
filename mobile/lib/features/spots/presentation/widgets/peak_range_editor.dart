import 'package:flutter/material.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_sheet_scaffold.dart';
import '../../domain/peak_range.dart';

class PeakRangeEditor extends StatefulWidget {
  const PeakRangeEditor({super.key, this.initialRange});

  final PeakRange? initialRange;

  @override
  State<PeakRangeEditor> createState() => _PeakRangeEditorState();
}

class _PeakRangeEditorState extends State<PeakRangeEditor> {
  late Set<int> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final init = widget.initialRange;
    if (init != null) {
      _selectedDays = Set<int>.from(init.days);
      _startTime = TimeOfDay(hour: init.start ~/ 60, minute: init.start % 60);
      _endTime = TimeOfDay(hour: init.end ~/ 60, minute: init.end % 60);
    } else {
      // Default: Hari kerja (Sen-Jum), 11:00 - 14:00
      _selectedDays = {1, 2, 3, 4, 5};
      _startTime = const TimeOfDay(hour: 11, minute: 0);
      _endTime = const TimeOfDay(hour: 14, minute: 0);
    }
  }

  bool _isPresetActive(Set<int> preset) {
    if (_selectedDays.length != preset.length) return false;
    return _selectedDays.containsAll(preset);
  }

  void _applyPreset(Set<int> preset) {
    setState(() {
      _selectedDays = Set<int>.from(preset);
      _errorMessage = null;
    });
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _errorMessage = null;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _onSave() {
    if (_selectedDays.isEmpty) {
      setState(() {
        _errorMessage = 'Pilih minimal satu hari';
      });
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final sortedDays = _selectedDays.toList()..sort();

    final result = PeakRange(
      days: sortedDays,
      start: startMinutes,
      end: endMinutes,
    );

    Navigator.of(context).pop(result);
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isCrossMidnight =
        (_endTime.hour * 60 + _endTime.minute) <=
        (_startTime.hour * 60 + _startTime.minute);

    const weekdaysPreset = {1, 2, 3, 4, 5};
    const weekendPreset = {6, 7};
    const everydayPreset = {1, 2, 3, 4, 5, 6, 7};

    final dayMap = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };

    return AppSheetScaffold(
      title: widget.initialRange == null
          ? 'Tambah jam ramai'
          : 'Edit jam ramai',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preset chips
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
                          onTap: () => _applyPreset(weekdaysPreset),
                        ),
                        SizedBox(width: tokens.space8),
                        AppChip(
                          label: 'Akhir pekan',
                          isSelected: _isPresetActive(weekendPreset),
                          onTap: () => _applyPreset(weekendPreset),
                        ),
                        SizedBox(width: tokens.space8),
                        AppChip(
                          label: 'Setiap hari',
                          isSelected: _isPresetActive(everydayPreset),
                          onTap: () => _applyPreset(everydayPreset),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.space12),

                  // 7 Individual day chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: dayMap.entries.map((entry) {
                      final day = entry.key;
                      final label = entry.value;
                      final isSelected = _selectedDays.contains(day);

                      return InkWell(
                        onTap: () => _toggleDay(day),
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tokens.actionFill
                                : tokens.surface,
                            borderRadius: BorderRadius.circular(
                              tokens.radiusSm,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? tokens.actionFill
                                  : tokens.border,
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
                  if (_errorMessage != null) ...[
                    SizedBox(height: tokens.space8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 12.0, color: tokens.danger),
                    ),
                  ],
                  SizedBox(height: tokens.space24),

                  // Time selection
                  Text(
                    'Rentang jam',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.space8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeBox(
                          label: 'Jam mulai',
                          timeString: _formatTime(_startTime),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: _TimeBox(
                          label: 'Jam selesai',
                          timeString: _formatTime(_endTime),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  if (isCrossMidnight) ...[
                    SizedBox(height: tokens.space8),
                    Text(
                      'Rentang melewati tengah malam',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tokens.space16),
            child: AppButton.primary(
              label: 'Simpan',
              isFullWidth: true,
              onPressed: _onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
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
