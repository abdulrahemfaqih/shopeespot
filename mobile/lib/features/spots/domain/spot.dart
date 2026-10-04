import 'category.dart';
import 'peak_range.dart';

class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.notes = '',
    this.peakHours = const [],
    this.lastVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.dirty = false,
  });

  final String id;
  final String name;
  final Category category;
  final double latitude;
  final double longitude;
  final String notes;
  final List<PeakRange> peakHours;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;

  bool get isDeleted => deletedAt != null;

  Spot copyWith({
    String? id,
    String? name,
    Category? category,
    double? latitude,
    double? longitude,
    String? notes,
    List<PeakRange>? peakHours,
    DateTime? lastVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? dirty,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      peakHours: peakHours ?? this.peakHours,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category.value,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'peak_hours': peakHours.map((p) => p.toJson()).toList(),
      'last_verified_at': lastVerifiedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  factory Spot.fromJson(Map<String, dynamic> json, {bool dirty = false}) {
    final rawPeakHours = json['peak_hours'] as List<dynamic>? ?? const [];
    return Spot(
      id: json['id'] as String,
      name: json['name'] as String,
      category: Category.fromString(json['category'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      peakHours: rawPeakHours
          .map((item) => PeakRange.fromJson(item as Map<String, dynamic>))
          .toList(),
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.parse(json['last_verified_at'] as String).toUtc()
          : null,
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
    if (other is! Spot) return false;
    return other.id == id &&
        other.name == name &&
        other.category == category &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.notes == notes &&
        other.lastVerifiedAt == lastVerifiedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.dirty == dirty;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    latitude,
    longitude,
    notes,
    lastVerifiedAt,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  );
}
