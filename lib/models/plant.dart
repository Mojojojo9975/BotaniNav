// lib/models/plant.dart
//
// Data class mapped from the live API response.
// API wraps plants in {"count": N, "plants": [...]} — see ApiService.getPlants().

import 'package:equatable/equatable.dart';
import '../config/section_config.dart';

class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.name,
    required this.scientificName,
    this.finnishName,
    this.synonym,
    this.family,
    this.description,
    required this.section,
    required this.isIndoor,
    this.latitude,
    this.longitude,
    this.greenhouseId,
    this.placementStatus,
    this.imageUrl,
    this.thumbnailUrl,
    this.gpsLat,
    this.gpsLng,
  });

  /// taxonNumber from API — used as primary key.
  final String id;

  /// Scientific name (API "name" field).
  final String name;

  /// Same as name for now — API has no separate common name.
  final String scientificName;

  /// Finnish common name ("finnishName").
  final String? finnishName;

  /// Taxonomic synonym.
  final String? synonym;

  /// Family name (e.g. "Araceae").
  final String? family;

  /// Curator description / placement comments.
  final String? description;

  /// Square ID from placement (e.g. "A-12").
  final String section;

  /// Derived from section via SectionConfig.
  final bool isIndoor;

  /// enriched.square_x — longitude in GeoJSON coordinate space.
  final double? latitude;

  /// enriched.square_y — latitude in GeoJSON coordinate space.
  final double? longitude;

  /// enriched.greenhouse_id as string.
  final String? greenhouseId;

  /// placement.plantStatus (e.g. "Healthy", "Needs attention").
  final String? placementStatus;

  final String? imageUrl;
  final String? thumbnailUrl;

  /// Real-world GPS coordinates for outdoor plants.
  /// Set by the backend after importing from the coordinate picker tool.
  /// Null until coordinates have been assigned.
  final double? gpsLat;
  final double? gpsLng;

  /// True if this outdoor plant has real GPS coordinates assigned.
  bool get hasGpsCoords => gpsLat != null && gpsLng != null;

  String? get displayImageUrl => thumbnailUrl ?? imageUrl;
  bool get hasImage => imageUrl != null || thumbnailUrl != null;

  /// Display name — Finnish name if available, otherwise scientific name.
  String get displayName => finnishName ?? name;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory Plant.fromJson(Map<String, dynamic> json) {
    final placement = json['placement'] as Map<String, dynamic>? ?? {};
    final enriched  = json['enriched']  as Map<String, dynamic>? ?? {};
    final familyMap = json['family']    as Map<String, dynamic>? ?? {};

    // Square format from API is "A-12" — normalise to "A12" for SectionConfig.
    final rawSquare = placement['square'] as String? ??
        enriched['square_id'] as String? ?? '';
    final section = rawSquare.replaceAll('-', '');

    // Parse GPS coords before deciding indoor/outdoor — a plant with real
    // GPS coordinates was tagged via the coordinate picker and is outdoor,
    // even if its section label (e.g. "A-12") matches an indoor section.
    final gpsLat = (json['gps_lat'] as num?)?.toDouble();
    final gpsLng = (json['gps_lng'] as num?)?.toDouble();
    final hasGps = gpsLat != null && gpsLng != null;
    final isIndoor = hasGps ? false : SectionConfig.isIndoor(section);

    // enriched.square_x is longitude, square_y is latitude in GeoJSON space.
    final lng = (enriched['square_x'] as num?)?.toDouble();
    final lat = (enriched['square_y'] as num?)?.toDouble();

    final greenhouseId = enriched['greenhouse_id'];

    return Plant(
      id:              (json['taxonNumber'] ?? json['id']).toString(),
      name:            json['name'] as String? ?? '',
      scientificName:  json['name'] as String? ?? '',
      finnishName:     json['finnishName'] as String?,
      synonym:         json['synonym'] as String?,
      family:          familyMap['name'] as String?,
      description:     placement['plantComments'] as String?,
      section:         rawSquare,   // keep original format for display
      isIndoor:        isIndoor,
      latitude:        lat,
      longitude:       lng,
      greenhouseId:    greenhouseId?.toString(),
      placementStatus: placement['plantStatus'] as String?,
      imageUrl:        json['image_url'] as String? ?? json['image'] as String?,
      thumbnailUrl:    json['thumbnail_url'] as String?,
      gpsLat:          gpsLat,
      gpsLng:          gpsLng,
    );
  }

  Map<String, dynamic> toJson() => {
        'taxonNumber': id,
        'name': name,
        if (finnishName != null) 'finnishName': finnishName,
        if (synonym != null) 'synonym': synonym,
        if (family != null) 'family': {'name': family},
        'placement': {
          'square': section,
          if (description != null) 'plantComments': description,
          if (placementStatus != null) 'plantStatus': placementStatus,
        },
        'enriched': {
          if (longitude != null) 'square_x': longitude,
          if (latitude != null)  'square_y': latitude,
          if (greenhouseId != null) 'greenhouse_id': greenhouseId,
        },
        if (imageUrl != null) 'image_url': imageUrl,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (gpsLat != null) 'gps_lat': gpsLat,
        if (gpsLng != null) 'gps_lng': gpsLng,
      };

  Plant copyWith({
    String? id, String? name, String? scientificName,
    String? finnishName, String? synonym, String? family,
    String? description, String? section, bool? isIndoor,
    double? latitude, double? longitude, String? greenhouseId,
    String? placementStatus, String? imageUrl, String? thumbnailUrl,
    double? gpsLat, double? gpsLng,
  }) => Plant(
    id: id ?? this.id,
    name: name ?? this.name,
    scientificName: scientificName ?? this.scientificName,
    finnishName: finnishName ?? this.finnishName,
    synonym: synonym ?? this.synonym,
    family: family ?? this.family,
    description: description ?? this.description,
    section: section ?? this.section,
    isIndoor: isIndoor ?? this.isIndoor,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    greenhouseId: greenhouseId ?? this.greenhouseId,
    placementStatus: placementStatus ?? this.placementStatus,
    imageUrl: imageUrl ?? this.imageUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    gpsLat: gpsLat ?? this.gpsLat,
    gpsLng: gpsLng ?? this.gpsLng,
  );

  @override
  List<Object?> get props => [
    id, name, scientificName, finnishName, synonym, family,
    description, section, isIndoor, latitude, longitude,
    greenhouseId, placementStatus, imageUrl, thumbnailUrl,
    gpsLat, gpsLng,
  ];

  @override
  String toString() => 'Plant($id, $name, section=$section, indoor=$isIndoor)';
}