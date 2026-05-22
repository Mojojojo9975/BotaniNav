// lib/widgets/indoor_map_widget.dart
//
// Renders the indoor floor plan from four GeoJSON layers using flutter_map.
// No tile server required — the map background is plain dark canvas.
//
// Layer render order (bottom → top):
//   1. PolygonLayer    — filled floor areas / wall masses   (Section_Layer_1)
//   2. PolylineLayer   — primary wall outlines              (Section_Layer_2)
//   3. PolylineLayer   — secondary line detail              (Section_Layer_3)
//   4. MarkerLayer     — section labels A1, B2, …           (Section_Layer)
//   5. (optional) user position dot if [userPosition] is provided

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';

class IndoorMapWidget extends StatefulWidget {
  const IndoorMapWidget({
    super.key,
    this.userPosition,
    this.targetPosition,
  });

  /// Live user position — shown as a blue dot if non-null.
  final LatLng? userPosition;

  /// Target plant position — shown as a green pin if non-null.
  final LatLng? targetPosition;

  @override
  State<IndoorMapWidget> createState() => _IndoorMapWidgetState();
}

class _IndoorMapWidgetState extends State<IndoorMapWidget> {
  late final MapController _mapController;
  IndoorMapData? _mapData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadMap();
  }

  Future<void> _loadMap() async {
    try {
      final data = await GeoJsonService.loadIndoorMap();
      if (mounted) setState(() => _mapData = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MapError(message: _error!);
    }

    if (_mapData == null) {
      return const _MapLoading();
    }

    final data = _mapData!;
    final centre = data.bounds.centre;
    final zoom = data.bounds.fitZoom;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centre,
        initialZoom: zoom,
        minZoom: zoom - 3,
        maxZoom: zoom + 5,
        backgroundColor: const Color(0xFF0D1A0D),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // ── 1. Filled floor areas / wall masses ──────────────────────────────
        PolygonLayer(
          polygons: data.polygons
              .map(
                (ring) => Polygon(
                  points: ring,
                  color: const Color(0xFF1E3A1E),
                  borderColor: const Color(0xFF2E5A2E),
                  borderStrokeWidth: 0.5,
                ),
              )
              .toList(),
        ),

        // ── 2. Primary wall outlines ─────────────────────────────────────────
        PolylineLayer(
          polylines: data.polylines
              .map(
                (pts) => Polyline(
                  points: pts,
                  color: const Color(0xFF4CAF50),
                  strokeWidth: 1.2,
                ),
              )
              .toList(),
        ),

        // ── 3. Secondary line detail ─────────────────────────────────────────
        PolylineLayer(
          polylines: data.secondaryPolylines
              .map(
                (pts) => Polyline(
                  points: pts,
                  color: const Color(0xFF2E7D32).withOpacity(0.6),
                  strokeWidth: 0.7,
                ),
              )
              .toList(),
        ),

        // ── 4. Section label markers ─────────────────────────────────────────
        MarkerLayer(
          markers: data.sectionPoints
              .map(
                (sp) => Marker(
                  point: sp.position,
                  width: 36,
                  height: 18,
                  child: _SectionLabel(label: sp.label),
                ),
              )
              .toList(),
        ),

        // ── 5. User position dot ─────────────────────────────────────────────
        if (widget.userPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.userPosition!,
                width: 20,
                height: 20,
                child: _UserDot(),
              ),
            ],
          ),

        // ── 6. Target plant marker ───────────────────────────────────────────
        if (widget.targetPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.targetPosition!,
                width: 28,
                height: 28,
                child: const _TargetPin(),
              ),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _UserDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

class _TargetPin extends StatelessWidget {
  const _TargetPin();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.eco,
        color: Colors.greenAccent,
        size: 28,
        shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
      );
}

class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF0D1A0D),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 14),
              Text(
                'Loading floor plan…',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF0D1A0D),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Could not load floor plan',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
}
