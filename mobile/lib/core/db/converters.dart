import 'dart:convert';
import 'package:drift/drift.dart';
import '../../features/spots/domain/peak_range.dart';

class PeakHoursConverter extends TypeConverter<List<PeakRange>, String> {
  const PeakHoursConverter();

  @override
  List<PeakRange> fromSql(String fromDb) {
    if (fromDb.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(fromDb) as List<dynamic>;
      return decoded
          .map((item) => PeakRange.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String toSql(List<PeakRange> value) {
    return jsonEncode(value.map((e) => e.toJson()).toList());
  }
}
