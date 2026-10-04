class PeakRange {
  const PeakRange({required this.days, required this.start, required this.end});

  /// ISO day of week: 1 = Monday ... 7 = Sunday
  final List<int> days;

  /// Minutes from midnight (0..1439)
  final int start;

  /// Minutes from midnight (0..1439). If end <= start, it spans past midnight.
  final int end;

  bool get crossesMidnight => end <= start;

  PeakRange copyWith({List<int>? days, int? start, int? end}) {
    return PeakRange(
      days: days ?? this.days,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'days': days, 'start': start, 'end': end};
  }

  factory PeakRange.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    return PeakRange(
      days: rawDays.map((d) => (d as num).toInt()).toList(),
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PeakRange) return false;
    if (other.start != start ||
        other.end != end ||
        other.days.length != days.length) {
      return false;
    }
    for (var i = 0; i < days.length; i++) {
      if (other.days[i] != days[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(days), start, end);
}
