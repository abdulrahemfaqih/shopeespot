import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/spot.dart';

class SpotDetailExtendedSection extends StatelessWidget {
  const SpotDetailExtendedSection({
    super.key,
    required this.spot,
    required this.ordersToday,
    required this.onDelete,
  });

  final Spot spot;
  final int ordersToday;
  final VoidCallback onDelete;

  static String formatVerificationDate(DateTime? dt) {
    if (dt == null) return 'Belum diverifikasi';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = dt.toLocal();
    return 'Terakhir diverifikasi ${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String formatTime(int minutes) {
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          color: tokens.border,
          height: tokens.borderWidth,
          thickness: tokens.borderWidth,
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: Text(
            'Hari ini: $ordersToday order',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
        Divider(
          color: tokens.border,
          height: tokens.borderWidth,
          thickness: tokens.borderWidth,
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catatan lapangan',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              SizedBox(height: tokens.space4),
              Text(
                spot.notes.isNotEmpty ? spot.notes : 'Tidak ada catatan',
                style: TextStyle(
                  fontSize: 14.0,
                  color: spot.notes.isNotEmpty
                      ? tokens.textPrimary
                      : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: tokens.border,
          height: tokens.borderWidth,
          thickness: tokens.borderWidth,
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jam ramai manual',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              SizedBox(height: tokens.space4),
              if (spot.peakHours.isEmpty)
                Text(
                  'Tidak ada jam ramai manual',
                  style: TextStyle(fontSize: 14.0, color: tokens.textSecondary),
                )
              else
                ...spot.peakHours.map(
                  (r) => Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.space4),
                    child: Text(
                      '${formatDays(r.days)}: ${formatTime(r.start)} - ${formatTime(r.end)}',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(
          color: tokens.border,
          height: tokens.borderWidth,
          thickness: tokens.borderWidth,
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: Text(
            formatVerificationDate(spot.lastVerifiedAt),
            style: TextStyle(fontSize: 12.0, color: tokens.textSecondary),
          ),
        ),
        Divider(
          color: tokens.border,
          height: tokens.borderWidth,
          thickness: tokens.borderWidth,
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: AppButton.danger(
            label: 'Hapus spot',
            isFullWidth: true,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}
