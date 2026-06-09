// lib/models/navigation_state.dart
//
// Two model classes:
//   NavigationState  — real-time state pushed over WebSocket.
//   OutdoorRoute     — response from POST /api/v1/navigation/route.

import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NavigationState — WebSocket payload (/api/v1/navigation/ws/{session_id})
// ─────────────────────────────────────────────────────────────────────────────

class NavigationState extends Equatable {
  const NavigationState({
    required this.bearing,
    required this.distanceMetres,
    required this.hotColdScore,
    required this.hint,
    required this.waypointIndex,
    required this.arrived,
  });

  /// Degrees clockwise from north — used to compute arrow angle on device.
  /// Arrow angle = bearing - deviceCompassHeading (see compass_service.dart).
  final double bearing;

  /// Straight-line distance to the current target waypoint in metres.
  final double distanceMetres;

  /// 0.0 = freezing cold (far away) → 1.0 = burning hot (right on it).
  /// Consumed by HotColdGauge widget.
  final double hotColdScore;

  /// Human-readable hint, e.g. "Getting warmer" or "Getting colder".
  final String hint;

  /// Index of the current waypoint within the route steps list.
  final int waypointIndex;

  /// True when the user has arrived at the destination plant.
  final bool arrived;

  // ── Serialisation ──────────────────────────────────────────────────────────
  factory NavigationState.fromJson(Map<String, dynamic> json) =>
      NavigationState(
        bearing: (json['bearing'] as num).toDouble(),
        distanceMetres: (json['distance_metres'] as num).toDouble(),
        hotColdScore: (json['hot_cold_score'] as num).toDouble(),
        hint: json['hint'] as String,
        waypointIndex: json['waypoint_index'] as int,
        arrived: json['arrived'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'bearing': bearing,
        'distance_metres': distanceMetres,
        'hot_cold_score': hotColdScore,
        'hint': hint,
        'waypoint_index': waypointIndex,
        'arrived': arrived,
      };

  /// Convenience — initial waiting state before WS first message.
  static const loading = NavigationState(
    bearing: 0,
    distanceMetres: 0,
    hotColdScore: 0.5,
    hint: 'Calculating route…',
    waypointIndex: 0,
    arrived: false,
  );

  @override
  List<Object?> get props => [
        bearing,
        distanceMetres,
        hotColdScore,
        hint,
        waypointIndex,
        arrived,
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// RouteStep — one instruction inside OutdoorRoute
// ─────────────────────────────────────────────────────────────────────────────

class RouteStep extends Equatable {
  const RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.durationSeconds,
  });

  final String instruction;
  final double distanceMetres;
  final int durationSeconds;

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        instruction: json['instruction'] as String? ?? '',
        distanceMetres: (json['distance_metres'] as num?)?.toDouble() ?? 0,
        durationSeconds: json['duration_seconds'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [instruction, distanceMetres, durationSeconds];
}

// ─────────────────────────────────────────────────────────────────────────────
// OutdoorRoute — response from POST /api/v1/navigation/route
// ─────────────────────────────────────────────────────────────────────────────

class OutdoorRoute extends Equatable {
  const OutdoorRoute({
    required this.mode,
    required this.plantName,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.polyline,
    required this.destinationLat,
    required this.destinationLng,
    required this.steps,
  });

  /// "outdoor" or "indoor" — always "outdoor" for this route response.
  final String mode;
  final String plantName;
  final double distanceMetres;
  final int durationSeconds;

  /// Encoded Google Maps polyline string — decode with google_maps_flutter.
  final String polyline;

  final double destinationLat;
  final double destinationLng;

  final List<RouteStep> steps;

  factory OutdoorRoute.fromJson(Map<String, dynamic> json) => OutdoorRoute(
        mode: json['mode'] as String,
        plantName: json['plant_name'] as String,
        distanceMetres: (json['distance_metres'] as num).toDouble(),
        durationSeconds: json['duration_seconds'] as int,
        polyline: json['polyline'] as String,
        destinationLat: (json['destination_lat'] as num).toDouble(),
        destinationLng: (json['destination_lng'] as num).toDouble(),
        steps: (json['steps'] as List<dynamic>)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        mode,
        plantName,
        distanceMetres,
        durationSeconds,
        polyline,
        destinationLat,
        destinationLng,
        steps,
      ];
}
