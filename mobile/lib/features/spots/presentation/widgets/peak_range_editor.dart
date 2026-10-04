import 'package:flutter/material.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_sheet_scaffold.dart';
import '../../domain/peak_range.dart';
import 'peak_range_editor_widgets.dart';

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
      _selectedDays = {1, 2, 3, 4, 5};
      _startTime = const TimeOfDay(hour: 11, minute: 0);
      _endTime = const TimeOfDay(hour: 14, minute: 0);
    }
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
                  DaySelector(
                    selectedDays: _selectedDays,
                    onToggleDay: _toggleDay,
                    onApplyPreset: _applyPreset,
                    errorMessage: _errorMessage,
                  ),
                  SizedBox(height: tokens.space24),
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
                        child: PeakTimeBox(
                          label: 'Jam mulai',
                          timeString: _formatTime(_startTime),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: PeakTimeBox(
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
