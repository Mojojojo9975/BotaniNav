// lib/services/geojson_service.dart
//
// Loads the four indoor map GeoJSON layers from assets and parses them into
// flutter_map-ready data structures.
//
// Layer mapping:
//   Section_Layer_1.geojson  → MultiPolygon    → filled floor areas / walls
//   Section_Layer_2.geojson  → MultiLineString → primary wall outlines
//   Section_Layer_3.geojson  → MultiLineString → secondary line detail
//   Section_Layer.geojson    → Point           → section labels (A1, B2, …)
//
// GeoJSON coordinates are [longitude, latitude, z?].
// We drop z and convert to LatLng(lat, lng) as required by flutter_map.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────────────────────

class IndoorMapData {
  const IndoorMapData({
    required this.polygons,
    required this.polylines,
    required this.secondaryPolylines,
    required this.sectionPoints,
    required this.bounds,
  });

  /// Filled floor / wall areas from Section_Layer_1.
  final List<List<LatLng>> polygons;

  /// Primary wall outlines from Section_Layer_2.
  final List<List<LatLng>> polylines;

  /// Secondary line detail from Section_Layer_3.
  final List<List<LatLng>> secondaryPolylines;

  /// Section label points from Section_Layer.
  final List<SectionPoint> sectionPoints;

  /// Bounding box covering all features — used to fit the map camera.
  final MapBounds bounds;
}

class SectionPoint {
  const SectionPoint({required this.position, required this.label});
  final LatLng position;
  final String label;
}

class MapBounds {
  const MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  LatLng get centre => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  /// Approximate zoom level to fit the bounds in a typical mobile viewport.
  double get fitZoom {
    final span = math.max(maxLat - minLat, maxLng - minLng);
    if (span <= 0) return 18.0;
    // log2(360 / span) gives a rough tile-zoom level
    final z = math.log(360.0 / span) / math.ln2;
    return z.clamp(2.0, 22.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class GeoJsonService {
  /// Load and parse all four indoor map layers from Flutter assets.
  static Future<IndoorMapData> loadIndoorMap() async {
    final results = await Future.wait([
      _loadAsset('assets/maps/Section_Layer_1.geojson'),
      _loadAsset('assets/maps/Section_Layer_2.geojson'),
      _loadAsset('assets/maps/Section_Layer_3.geojson'),
      _loadAsset('assets/maps/Section_Layer.geojson'),
    ]);

    final polygons          = _parseMultiPolygons(results[0]);
    final polylines         = _parseMultiLineStrings(results[1]);
    final secondaryPolylines = _parseMultiLineStrings(results[2]);
    final sectionPoints     = _parsePoints(results[3]);

    final bounds = _computeBounds([
      ...polygons.expand((r) => r),
      ...polylines.expand((r) => r),
      ...sectionPoints.map((p) => p.position),
    ]);

    return IndoorMapData(
      polygons: polygons,
      polylines: polylines,
      secondaryPolylines: secondaryPolylines,
      sectionPoints: sectionPoints,
      bounds: bounds,
    );
  }

  // ── Asset loader ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _loadAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── MultiPolygon parser ────────────────────────────────────────────────────

  static List<List<LatLng>> _parseMultiPolygons(Map<String, dynamic> fc) {
    final result = <List<LatLng>>[];
    for (final feature in fc['features'] as List) {
      final geom = feature['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;

      if (type == 'MultiPolygon') {
        for (final polygon in geom['coordinates'] as List) {
          // First ring is the outer boundary; skip holes for floor plan display.
          final outer = (polygon as List).first as List;
          final ring = _toLatLngs(outer);
          if (ring.length >= 3) result.add(ring);
        }
      } else if (type == 'Polygon') {
        final outer = (geom['coordinates'] as List).first as List;
        final ring = _toLatLngs(outer);
        if (ring.length >= 3) result.add(ring);
      }
    }
    return result;
  }

  // ── MultiLineString parser ─────────────────────────────────────────────────

  static List<List<LatLng>> _parseMultiLineStrings(Map<String, dynamic> fc) {
    final result = <List<LatLng>>[];
    for (final feature in fc['features'] as List) {
      final geom = feature['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;

      if (type == 'MultiLineString') {
        for (final line in geom['coordinates'] as List) {
          final pts = _toLatLngs(line as List);
          if (pts.length >= 2) result.add(pts);
        }
      } else if (type == 'LineString') {
        final pts = _toLatLngs(geom['coordinates'] as List);
        if (pts.length >= 2) result.add(pts);
      }
    }
    return result;
  }

  // ── Point parser ───────────────────────────────────────────────────────────

  static List<SectionPoint> _parsePoints(Map<String, dynamic> fc) {
    final result = <SectionPoint>[];
    for (final feature in fc['features'] as List) {
      final geom = feature['geometry'] as Map<String, dynamic>;
      if (geom['type'] != 'Point') continue;
      final coords = geom['coordinates'] as List;
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final label = (props['RoomName'] ?? props['name'] ?? '').toString();
      result.add(SectionPoint(position: _coordToLatLng(coords), label: label));
    }
    return result;
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────────

  /// GeoJSON coordinate: [lng, lat] or [lng, lat, z].
  static LatLng _coordToLatLng(List coord) => LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );

  static List<LatLng> _toLatLngs(List coords) =>
      coords.map((c) => _coordToLatLng(c as List)).toList();

  // ── Bounds ─────────────────────────────────────────────────────────────────

  static MapBounds _computeBounds(Iterable<LatLng> points) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return MapBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}