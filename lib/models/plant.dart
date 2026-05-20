// lib/models/plant.dart
//
// Data class for a plant returned by GET /api/v1/plants.
// Matches the API contract exactly; never mutate instances — create new ones.

import 'package:equatable/equatable.dart';

class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.name,
    required this.scientificName,
    this.description,
    required this.section,
    required this.isIndoor,
    this.latitude,
    this.longitude,
    this.greenhouseId,
  });

  /// UUID string — primary key used in all navigation requests.
  final String id;

  final String name;
  final String scientificName;

  /// Optional curator description; may be null.
  final String? description;

  /// Garden section label (e.g. "B4", "Greenhouse A – East Wing").
  final String section;

  /// True  → indoor greenhouse plant (use BLE + QR navigation).
  /// False → outdoor plant (use Google Maps navigation).
  final bool isIndoor;

  // ── Outdoor-only fields ────────────────────────────────────────────────────
  /// Non-null when [isIndoor] == false.
  final double? latitude;
  final double? longitude;

  // ── Indoor-only fields ─────────────────────────────────────────────────────
  // TODO [Backend Phase 3 / Hardware]: greenhouseId maps to BLE beacon sets.
  /// Non-null when [isIndoor] == true.
  final String? greenhouseId;

  // ── Serialisation ──────────────────────────────────────────────────────────
  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
        id: json['id'] as String,
        name: json['name'] as String,
        scientificName: json['scientific_name'] as String,
        description: json['description'] as String?,
        section: json['section'] as String,
        isIndoor: json['is_indoor'] as bool,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        greenhouseId: json['greenhouse_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scientific_name': scientificName,
        if (description != null) 'description': description,
        'section': section,
        'is_indoor': isIndoor,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (greenhouseId != null) 'greenhouse_id': greenhouseId,
      };

  Plant copyWith({
    String? id,
    String? name,
    String? scientificName,
    String? description,
    String? section,
    bool? isIndoor,
    double? latitude,
    double? longitude,
    String? greenhouseId,
  }) =>
      Plant(
        id: id ?? this.id,
        name: name ?? this.name,
        scientificName: scientificName ?? this.scientificName,
        description: description ?? this.description,
        section: section ?? this.section,
        isIndoor: isIndoor ?? this.isIndoor,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        greenhouseId: greenhouseId ?? this.greenhouseId,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        scientificName,
        description,
        section,
        isIndoor,
        latitude,
        longitude,
        greenhouseId,
      ];

  @override
  String toString() => 'Plant($id, $name, indoor=$isIndoor)';
}
