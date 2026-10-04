class OrderLog {
  const OrderLog({
    required this.id,
    required this.spotId,
    required this.orderedAt,
    required this.localDow,
    required this.localHour,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.dirty = false,
  });

  final String id;
  final String spotId;
  final DateTime orderedAt;

  /// ISO day of week (1 = Monday ... 7 = Sunday)
  final int localDow;

  /// Local hour when recorded (0..23)
  final int localHour;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;

  bool get isDeleted => deletedAt != null;

  OrderLog copyWith({
    String? id,
    String? spotId,
    DateTime? orderedAt,
    int? localDow,
    int? localHour,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? dirty,
  }) {
    return OrderLog(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      orderedAt: orderedAt ?? this.orderedAt,
      localDow: localDow ?? this.localDow,
      localHour: localHour ?? this.localHour,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'spot_id': spotId,
      'ordered_at': orderedAt.toUtc().toIso8601String(),
      'local_dow': localDow,
      'local_hour': localHour,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  factory OrderLog.fromJson(Map<String, dynamic> json, {bool dirty = false}) {
    return OrderLog(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      orderedAt: DateTime.parse(json['ordered_at'] as String).toUtc(),
      localDow: (json['local_dow'] as num).toInt(),
      localHour: (json['local_hour'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toUtc()
          : null,
      dirty: dirty,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OrderLog) return false;
    return other.id == id &&
        other.spotId == spotId &&
        other.orderedAt == orderedAt &&
        other.localDow == localDow &&
        other.localHour == localHour &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.dirty == dirty;
  }

  @override
  int get hashCode => Object.hash(
    id,
    spotId,
    orderedAt,
    localDow,
    localHour,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  );
}
