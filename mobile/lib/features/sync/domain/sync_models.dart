import 'dart:convert';

class SyncCursors {
  final int spots;
  final int orders;

  const SyncCursors({this.spots = 0, this.orders = 0});

  factory SyncCursors.fromJson(Map<String, dynamic> json) {
    return SyncCursors(
      spots: (json['spots'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'spots': spots, 'orders': orders};
}

class SyncSpotDto {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String notes;
  final List<dynamic> peakHours;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int? seq;

  const SyncSpotDto({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.notes,
    required this.peakHours,
    this.lastVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.seq,
  });

  factory SyncSpotDto.fromJson(Map<String, dynamic> json) {
    return SyncSpotDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'shopeefood',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      peakHours: json['peak_hours'] is List
          ? json['peak_hours'] as List<dynamic>
          : (json['peak_hours'] is String
                ? (jsonDecode(json['peak_hours'] as String) as List<dynamic>)
                : <dynamic>[]),
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.parse(json['last_verified_at'] as String).toUtc()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toUtc()
          : null,
      seq: (json['seq'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    'notes': notes,
    'peak_hours': peakHours,
    'last_verified_at': lastVerifiedAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    if (seq != null) 'seq': seq,
  };
}

class SyncOrderDto {
  final String id;
  final String spotId;
  final DateTime orderedAt;
  final int localDow;
  final int localHour;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int? seq;

  const SyncOrderDto({
    required this.id,
    required this.spotId,
    required this.orderedAt,
    required this.localDow,
    required this.localHour,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.seq,
  });

  factory SyncOrderDto.fromJson(Map<String, dynamic> json) {
    return SyncOrderDto(
      id: json['id'] as String? ?? '',
      spotId: json['spot_id'] as String? ?? '',
      orderedAt: DateTime.parse(json['ordered_at'] as String).toUtc(),
      localDow: (json['local_dow'] as num?)?.toInt() ?? 1,
      localHour: (json['local_hour'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toUtc()
          : null,
      seq: (json['seq'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'spot_id': spotId,
    'ordered_at': orderedAt.toUtc().toIso8601String(),
    'local_dow': localDow,
    'local_hour': localHour,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    if (seq != null) 'seq': seq,
  };
}

class SyncRequestDto {
  final SyncCursors cursors;
  final List<SyncSpotDto> spots;
  final List<SyncOrderDto> orders;

  const SyncRequestDto({
    required this.cursors,
    required this.spots,
    required this.orders,
  });

  Map<String, dynamic> toJson() => {
    'cursors': cursors.toJson(),
    'spots': spots.map((s) => s.toJson()).toList(),
    'orders': orders.map((o) => o.toJson()).toList(),
  };
}

class SyncResponseDto {
  final SyncCursors cursors;
  final List<SyncSpotDto> spots;
  final List<SyncOrderDto> orders;
  final bool hasMore;
  final DateTime serverTime;

  const SyncResponseDto({
    required this.cursors,
    required this.spots,
    required this.orders,
    required this.hasMore,
    required this.serverTime,
  });

  factory SyncResponseDto.fromJson(Map<String, dynamic> json) {
    return SyncResponseDto(
      cursors: json['cursors'] is Map<String, dynamic>
          ? SyncCursors.fromJson(json['cursors'] as Map<String, dynamic>)
          : const SyncCursors(),
      spots:
          (json['spots'] as List<dynamic>?)
              ?.map((e) => SyncSpotDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <SyncSpotDto>[],
      orders:
          (json['orders'] as List<dynamic>?)
              ?.map((e) => SyncOrderDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <SyncOrderDto>[],
      hasMore: json['has_more'] as bool? ?? false,
      serverTime: json['server_time'] != null
          ? DateTime.parse(json['server_time'] as String).toUtc()
          : DateTime.now().toUtc(),
    );
  }
}
