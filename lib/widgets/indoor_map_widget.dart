// lib/widgets/indoor_map_widget.dart
//
// Renders the indoor floor plan from four GeoJSON layers using flutter_map.
//
// Section markers are tappable — tapping one shows a popup card with the
// plant name assigned to that section.
//
// The [activeSection] marker glows and pulses to highlight the navigation
// target or the current treasure hunt plant.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';
import '../providers/plant_provider.dart';

class IndoorMapWidget extends ConsumerStatefulWidget {
  const IndoorMapWidget({
    super.key,
    this.plantId,
    this.activeSection,
    this.sectionPlantMap,
  });

  /// When non-null, shows a target pin for this plant's coordinates.
  final String? plantId;

  /// Section label to highlight (e.g. "A8") — glows green.
  final String? activeSection;

  /// Maps section label → plant name for tap popups.
  /// e.g. {"A8": "Bird of Paradise", "B2": "Corpse Lily"}
  final Map<String, String>? sectionPlantMap;

  @override
  ConsumerState<IndoorMapWidget> createState() => _IndoorMapWidgetState();
}

class _IndoorMapWidgetState extends ConsumerState<IndoorMapWidget>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  IndoorMapData? _mapData;
  String? _error;
  SectionPoint? _tappedSection;

  // Pulse animation for active section marker
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadMap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    if (_error != null) return _MapError(message: _error!);
    if (_mapData == null) return const _MapLoading();

    final data = _mapData!;

    LatLng? targetPosition;
    if (widget.plantId != null) {
      final plant = ref.watch(plantByIdProvider(widget.plantId!));
      if (plant?.latitude != null && plant?.longitude != null) {
        targetPosition = LatLng(plant!.latitude!, plant.longitude!);
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: data.bounds.centre,
            initialZoom: data.bounds.fitZoom,
            minZoom: data.bounds.fitZoom - 3,
            maxZoom: data.bounds.fitZoom + 6,
            backgroundColor: const Color(0xFF0D1A0D),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            // Dismiss popup on map tap
            onTap: (_, __) => setState(() => _tappedSection = null),
          ),
          children: [
            // ── 1. Filled floor areas ───────────────────────────────────────
            PolygonLayer(
              polygons: data.polygons
                  .map((ring) => Polygon(
                        points: ring,
                        color: const Color(0xFF1E3A1E),
                        borderColor: const Color(0xFF2E5A2E),
                        borderStrokeWidth: 0.5,
                      ))
                  .toList(),
            ),

            // ── 2. Primary wall outlines ────────────────────────────────────
            PolylineLayer(
              polylines: data.polylines
                  .map((pts) => Polyline(
                        points: pts,
                        color: const Color(0xFF4CAF50),
                        strokeWidth: 1.2,
                      ))
                  .toList(),
            ),

            // ── 3. Secondary line detail ────────────────────────────────────
            PolylineLayer(
              polylines: data.secondaryPolylines
                  .map((pts) => Polyline(
                        points: pts,
                        color: const Color(0xFF2E7D32),
                        strokeWidth: 0.7,
                      ))
                  .toList(),
            ),

            // ── 4. Section label markers (tappable) ─────────────────────────
            MarkerLayer(
              markers: data.sectionPoints.map((sp) {
                final isActive = widget.activeSection == sp.label;
                final plantName = widget.sectionPlantMap?[sp.label];
                return Marker(
                  point: sp.position,
                  width: isActive ? 44 : 36,
                  height: isActive ? 22 : 18,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tappedSection =
                          _tappedSection?.label == sp.label ? null : sp;
                    }),
                    child: isActive
                        ? AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => _ActiveSectionLabel(
                              label: sp.label,
                              opacity: _pulseAnim.value,
                            ),
                          )
                        : _SectionLabel(
                            label: sp.label,
                            hasPlant: plantName != null,
                          ),
                  ),
                );
              }).toList(),
            ),

            // ── 5. Target plant pin ─────────────────────────────────────────
            if (targetPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: targetPosition,
                    width: 32,
                    height: 32,
                    child: const _TargetPin(),
                  ),
                ],
              ),

            // ── Zoom controls ───────────────────────────────────────────────
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 140, right: 12),
                child: _ZoomControls(controller: _mapController),
              ),
            ),
          ],
        ),

        // ── Section popup (rendered outside FlutterMap to avoid clipping) ───
        if (_tappedSection != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _SectionPopup(
              section: _tappedSection!,
              plantName: widget.sectionPlantMap?[_tappedSection!.label],
              onClose: () => setState(() => _tappedSection = null),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label markers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.hasPlant});
  final String label;
  final bool hasPlant;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasPlant
              ? Colors.greenAccent.withOpacity(0.18)
              : Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasPlant
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: hasPlant ? Colors.greenAccent : Colors.white54,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _ActiveSectionLabel extends StatelessWidget {
  const _ActiveSectionLabel({required this.label, required this.opacity});
  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.3 * opacity),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Colors.greenAccent.withOpacity(opacity),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4 * opacity),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section popup card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionPopup extends StatelessWidget {
  const _SectionPopup({
    required this.section,
    required this.onClose,
    this.plantName,
  });
  final SectionPoint section;
  final String? plantName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plantName != null
                ? Colors.greenAccent.withOpacity(0.4)
                : Colors.white12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Section badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: plantName != null
                    ? Colors.greenAccent.withOpacity(0.15)
                    : Colors.white10,
                border: Border.all(
                  color: plantName != null
                      ? Colors.greenAccent.withOpacity(0.5)
                      : Colors.white24,
                ),
              ),
              child: Center(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: plantName != null
                        ? Colors.greenAccent
                        : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plantName ?? 'Empty section',
                    style: TextStyle(
                      color: plantName != null
                          ? Colors.white
                          : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plantName != null
                        ? 'Greenhouse section ${section.label}'
                        : 'No plant assigned to this section',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zoom controls
// ─────────────────────────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.controller});
  final MapController controller;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add,
            onPressed: () => controller.move(
              controller.camera.center,
              controller.camera.zoom + 1,
            ),
          ),
          const SizedBox(height: 4),
          _ZoomButton(
            icon: Icons.remove,
            onPressed: () => controller.move(
              controller.camera.center,
              controller.camera.zoom - 1,
            ),
          ),
        ],
      );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 20),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Target pin
// ─────────────────────────────────────────────────────────────────────────────

class _TargetPin extends StatelessWidget {
  const _TargetPin();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.greenAccent.withOpacity(0.2),
          border: Border.all(color: Colors.greenAccent, width: 2),
        ),
        child: const Icon(Icons.eco, color: Colors.greenAccent, size: 20),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / error states
// ─────────────────────────────────────────────────────────────────────────────

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
              Text('Loading floor plan…',
                  style: TextStyle(color: Colors.white54)),
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
                const Text('Could not load floor plan',
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}