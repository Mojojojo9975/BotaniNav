// lib/models/trail_route.dart
//
// Data classes for the multi-plant trail navigation feature.
// Maps to the response from POST /api/v1/navigation/trail.

import 'package:equatable/equatable.dart';
import 'navigation_state.dart'; // reuses RouteStep

// ─────────────────────────────────────────────────────────────────────────────
// TrailLeg — one plant stop in the trail
// ─────────────────────────────────────────────────────────────────────────────

class TrailLeg extends Equatable {
  const TrailLeg({
    required this.plantId,
    required this.plantName,
    required this.destinationLat,
    required this.destinationLng,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.polyline,
    required this.steps,
  });

  final String plantId;
  final String plantName;
  final double destinationLat;
  final double destinationLng;
  final double distanceMetres;
  final int durationSeconds;

  /// Google encoded polyline for this leg only.
  final String polyline;

  final List<RouteStep> steps;

  factory TrailLeg.fromJson(Map<String, dynamic> json) => TrailLeg(
        plantId: json['plant_id'].toString(),
        plantName: json['plant_name'] as String? ?? '',
        destinationLat: (json['destination_lat'] as num).toDouble(),
        destinationLng: (json['destination_lng'] as num).toDouble(),
        distanceMetres: (json['distance_metres'] as num).toDouble(),
        durationSeconds: json['duration_seconds'] as int,
        polyline: json['polyline'] as String,
        steps: (json['steps'] as List<dynamic>)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        plantId, plantName, destinationLat, destinationLng,
        distanceMetres, durationSeconds, polyline, steps,
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// TrailRoute — full multi-plant trail response
// ─────────────────────────────────────────────────────────────────────────────

class TrailRoute extends Equatable {
  const TrailRoute({
    required this.totalDistanceMetres,
    required this.totalDurationSeconds,
    required this.legs,
  });

  final double totalDistanceMetres;
  final int totalDurationSeconds;

  /// Ordered list of legs — one per plant in the trail.
  final List<TrailLeg> legs;

  factory TrailRoute.fromJson(Map<String, dynamic> json) => TrailRoute(
        totalDistanceMetres:
            (json['total_distance_metres'] as num).toDouble(),
        totalDurationSeconds: json['total_duration_seconds'] as int,
        legs: (json['legs'] as List<dynamic>)
            .map((l) => TrailLeg.fromJson(l as Map<String, dynamic>))
            .toList(),
      );

  /// Convenience — distance string formatted for display.
  String get distanceString => totalDistanceMetres >= 1000
      ? '${(totalDistanceMetres / 1000).toStringAsFixed(1)} km'
      : '${totalDistanceMetres.toStringAsFixed(0)} m';

  /// Minutes walking time (rounded up).
  int get walkingMinutes => (totalDurationSeconds / 60).ceil();

  @override
  List<Object?> get props =>
      [totalDistanceMetres, totalDurationSeconds, legs];
}
