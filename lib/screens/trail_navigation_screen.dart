// lib/screens/trail_navigation_screen.dart
//
// Multi-plant trail navigation screen.
//
// Shows all trail legs on the map simultaneously:
//   • Current leg — bright green polyline + green target marker
//   • Future legs — dim teal polylines + numbered cyan markers
//   • Completed legs — grey polylines + grey markers
//
// Bottom sheet: current leg distance/ETA + overall progress bar.
// Top banner:   current plant name + "Plant X of Y".
// On intermediate arrival: 3-second card, then auto-advances to next leg.
// On final arrival: navigates to /arrival/{lastPlantId}.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/trail_route.dart';
import '../providers/navigation_provider.dart';

class TrailNavigationScreen extends ConsumerStatefulWidget {
  const TrailNavigationScreen({super.key, required this.plantIds});

  /// Ordered list of plant taxon IDs for this trail.
  final List<String> plantIds;

  @override
  ConsumerState<TrailNavigationScreen> createState() =>
      _TrailNavigationScreenState();
}

class _TrailNavigationScreenState
    extends ConsumerState<TrailNavigationScreen> {
  GoogleMapController? _mapController;
  bool _followUser = true;
  bool _sheetExpanded = false;

  // Intermediate arrival overlay
  bool _showArrivalCard = false;
  String? _arrivedPlantName;
  Timer? _arrivalTimer;

  // Cached map objects — only rebuilt when route/leg changes
  Set<Marker>   _cachedMarkers   = {};
  Set<Polyline> _cachedPolylines = {};
  int           _lastBuiltLeg    = -1;

  late final String _key; // trailKey — used for all provider lookups

  @override
  void initState() {
    super.initState();
    _key = trailKey(widget.plantIds);
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Map controller ──────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _mapController?.setMapStyle(_mapStyle);
  }

  void _animateTo(LatLng pos) {
    if (!_followUser) return;
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  void _fitAllLegs(TrailRoute trail) {
    if (trail.legs.isEmpty) return;
    double minLat = trail.legs.first.destinationLat;
    double maxLat = minLat;
    double minLng = trail.legs.first.destinationLng;
    double maxLng = minLng;
    for (final leg in trail.legs) {
      if (leg.destinationLat < minLat) minLat = leg.destinationLat;
      if (leg.destinationLat > maxLat) maxLat = leg.destinationLat;
      if (leg.destinationLng < minLng) minLng = leg.destinationLng;
      if (leg.destinationLng > maxLng) maxLng = leg.destinationLng;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.0003, minLng - 0.0003),
          northeast: LatLng(maxLat + 0.0003, maxLng + 0.0003),
        ),
        60,
      ),
    );
  }

  // ── Map cache helpers ───────────────────────────────────────────────────────

  void _rebuildMap(TrailRoute trail, int currentLeg) {
    if (_lastBuiltLeg == currentLeg) return;
    _lastBuiltLeg = currentLeg;

    final markers   = <Marker>{};
    final polylines = <Polyline>{};

    for (int i = 0; i < trail.legs.length; i++) {
      final leg = trail.legs[i];
      final isDone    = i < currentLeg;
      final isCurrent = i == currentLeg;

      // Polyline color
      final color = isDone
          ? Colors.grey.withOpacity(0.5)
          : isCurrent
              ? Colors.greenAccent
              : Colors.tealAccent.withOpacity(0.55);
      final width = isCurrent ? 5 : 3;

      polylines.add(Polyline(
        polylineId: PolylineId('leg_$i'),
        points: _decodePolyline(leg.polyline),
        color: color,
        width: width,
        startCap: Cap.roundCap,
        endCap:   Cap.roundCap,
        jointType: JointType.round,
      ));

      // Marker hue
      final hue = isDone
          ? BitmapDescriptor.hueAzure
          : isCurrent
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueCyan;

      markers.add(Marker(
        markerId: MarkerId('leg_$i'),
        position: LatLng(leg.destinationLat, leg.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: '${i + 1}. ${leg.plantName}',
          snippet: isDone ? 'Visited ✓' : isCurrent ? 'Current target' : 'Upcoming',
        ),
        zIndex: isCurrent ? 3 : isDone ? 1 : 2,
      ));
    }

    setState(() {
      _cachedMarkers   = markers;
      _cachedPolylines = polylines;
    });
  }

  // ── Intermediate arrival ────────────────────────────────────────────────────

  void _showIntermediateArrival(String plantName) {
    setState(() {
      _showArrivalCard  = true;
      _arrivedPlantName = plantName;
    });
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showArrivalCard = false);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final routeAsync   = ref.watch(trailRouteProvider(_key));
    final navAsync     = ref.watch(trailNavigationStateProvider(_key));
    final currentLeg   = ref.watch(currentTrailLegIndexProvider(_key));
    final arrowAngle   = ref.watch(trailArrowAngleProvider(_key));
    final gpsAsync     = ref.watch(gpsPositionProvider);

    final userPos = gpsAsync.whenOrNull(
      data: (p) => LatLng(p.latitude, p.longitude),
    );

    // Auto-pan on GPS update
    ref.listen(gpsPositionProvider, (_, next) {
      next.whenData((pos) => _animateTo(LatLng(pos.latitude, pos.longitude)));
    });

    // Route loaded — rebuild map and fit camera
    ref.listen(trailRouteProvider(_key), (_, next) {
      next.whenData((trail) {
        _rebuildMap(trail, currentLeg);
        if (_mapController != null) _fitAllLegs(trail);
      });
    });

    // Leg change — rebuild map with new current leg highlighted
    ref.listen(currentTrailLegIndexProvider(_key), (prev, next) {
      final trail = routeAsync.whenOrNull(data: (t) => t);
      if (trail == null) return;
      _rebuildMap(trail, next);

      // Show intermediate arrival card (not on the first change or final)
      final prevLeg = prev ?? 0;
      if (next > prevLeg && next < trail.legs.length) {
        _showIntermediateArrival(trail.legs[prevLeg].plantName);
      }
    });

    // Final arrival
    ref.listen(trailNavigationStateProvider(_key), (_, next) {
      next.whenData((s) {
        if (s.arrived && mounted) {
          context.go('/arrival/${widget.plantIds.last}');
        }
      });
    });

    // Also rebuild map when trail loads and currentLeg is known
    routeAsync.whenData((trail) => _rebuildMap(trail, currentLeg));

    final trail    = routeAsync.whenOrNull(data: (t) => t);
    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);
    final hint     = navAsync.whenOrNull(data: (s) => s.hint);

    final currentLegData = trail != null && currentLeg < trail.legs.length
        ? trail.legs[currentLeg]
        : null;

    final initialTarget = currentLegData != null
        ? LatLng(currentLegData.destinationLat, currentLegData.destinationLng)
        : userPos ?? const LatLng(65.0638, 25.4638);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 17),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _cachedMarkers,
            polylines: _cachedPolylines,
            onCameraMoveStarted: () => setState(() => _followUser = false),
          ),

          // ── Top banner ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: _TopBanner(
                currentLegData: currentLegData,
                legIndex: currentLeg,
                totalLegs: trail?.legs.length ?? widget.plantIds.length,
                hint: hint,
                distance: distance,
                isLoading: routeAsync.isLoading,
                hasError: routeAsync.hasError,
                onBack: () => context.go('/outdoor-map'),
              ),
            ),
          ),

          // ── Intermediate arrival card ─────────────────────────────────────
          if (_showArrivalCard && _arrivedPlantName != null)
            Positioned(
              top: 100, left: 24, right: 24,
              child: _IntermediateArrivalCard(plantName: _arrivedPlantName!),
            ),

          // ── Re-centre button ─────────────────────────────────────────────
          if (!_followUser)
            Positioned(
              bottom: _sheetExpanded ? 260 : 140,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recentre',
                backgroundColor: const Color(0xFF1A2E1A),
                foregroundColor: Colors.greenAccent,
                onPressed: () {
                  setState(() => _followUser = true);
                  if (userPos != null) {
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(userPos, 17));
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ),

          // ── Fit all legs button ──────────────────────────────────────────
          Positioned(
            bottom: _sheetExpanded ? 260 : 140,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arrow indicator
                _ArrowIndicator(angleDegrees: arrowAngle, distance: distance),
                const SizedBox(height: 8),
                // Overview button
                if (trail != null)
                  FloatingActionButton.small(
                    heroTag: 'overview',
                    backgroundColor: const Color(0xFF1A2E1A),
                    foregroundColor: Colors.tealAccent,
                    onPressed: () => _fitAllLegs(trail),
                    child: const Icon(Icons.route, size: 18),
                  ),
              ],
            ),
          ),

          // ── Bottom sheet ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: routeAsync.when(
              loading: () => _BottomSheetLoading(),
              error: (e, _) => _BottomSheetError(message: e.toString()),
              data: (trail) => _BottomRouteSheet(
                trail: trail,
                currentLeg: currentLeg,
                distance: distance,
                expanded: _sheetExpanded,
                onToggle: () =>
                    setState(() => _sheetExpanded = !_sheetExpanded),
              ),
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────────
          if (routeAsync.isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top banner
// ─────────────────────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  const _TopBanner({
    required this.currentLegData,
    required this.legIndex,
    required this.totalLegs,
    required this.hint,
    required this.distance,
    required this.isLoading,
    required this.hasError,
    required this.onBack,
  });

  final TrailLeg? currentLegData;
  final int legIndex;
  final int totalLegs;
  final String? hint;
  final double? distance;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final plantName = currentLegData?.plantName ?? '…';
    final progress  = '${ legIndex + 1} of $totalLegs';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.route, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plantName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isLoading
                      ? 'Building trail…'
                      : hasError
                          ? 'Trail unavailable'
                          : (hint ?? 'Plant $progress'),
                  style: TextStyle(
                      color: hasError ? Colors.redAccent : Colors.white60,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          // Leg badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
            ),
            child: Text(
              'Plant $progress',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intermediate arrival card (auto-dismisses after 3 s)
// ─────────────────────────────────────────────────────────────────────────────

class _IntermediateArrivalCard extends StatelessWidget {
  const _IntermediateArrivalCard({required this.plantName});
  final String plantName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3D1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.2),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
              ),
              child: const Icon(Icons.check, color: Colors.greenAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arrived! 🎉',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plantName,
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Heading to next plant…',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow indicator
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowIndicator extends StatelessWidget {
  const _ArrowIndicator({required this.angleDegrees, this.distance});
  final double angleDegrees;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A2E1A).withOpacity(0.92),
        border: Border.all(
            color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.greenAccent.withOpacity(0.15),
            blurRadius: 10, spreadRadius: 2)],
      ),
      child: Transform.rotate(
        angle: angleDegrees * 3.14159265 / 180,
        child: const Icon(Icons.navigation, color: Colors.greenAccent, size: 30),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet states
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.greenAccent, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Building trail…',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _BottomSheetError extends StatelessWidget {
  const _BottomSheetError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trail unavailable — check your connection',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _BottomRouteSheet extends StatelessWidget {
  const _BottomRouteSheet({
    required this.trail,
    required this.currentLeg,
    required this.distance,
    required this.expanded,
    required this.onToggle,
  });

  final TrailRoute trail;
  final int currentLeg;
  final double? distance;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final leg = currentLeg < trail.legs.length ? trail.legs[currentLeg] : null;
    final legMinutes = leg != null ? (leg.durationSeconds / 60).ceil() : 0;
    final legDist = leg != null
        ? (leg.distanceMetres >= 1000
            ? '${(leg.distanceMetres / 1000).toStringAsFixed(1)} km'
            : '${leg.distanceMetres.toStringAsFixed(0)} m')
        : '—';

    // Overall progress
    final completedLegs = currentLeg;
    final totalLegs     = trail.legs.length;
    final progressFraction = totalLegs > 0 ? completedLegs / totalLegs : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + summary
          GestureDetector(
            onTap: onToggle,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$legDist  ·  ~$legMinutes min to next',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.white38, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Overall trail progress bar
                  Row(
                    children: [
                      Text(
                        '${trail.distanceString}  ·  ${trail.walkingMinutes} min total',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        '$completedLegs / $totalLegs plants',
                        style: const TextStyle(
                            color: Colors.tealAccent, fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      backgroundColor: Colors.white12,
                      color: Colors.greenAccent,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded step list for current leg
          if (expanded && leg != null) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.turn_right, color: Colors.tealAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Steps to ${leg.plantName}',
                    style: const TextStyle(
                        color: Colors.tealAccent, fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: leg.steps.length,
                itemBuilder: (_, i) {
                  final step = leg.steps[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.greenAccent.withOpacity(0.15),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(step.instruction,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    subtitle: Text(
                      '${step.distanceMetres.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google encoded polyline decoder (same as OutdoorNavigationScreen)
// ─────────────────────────────────────────────────────────────────────────────

List<LatLng> _decodePolyline(String encoded) {
  final result = <LatLng>[];
  int index = 0, lat = 0, lng = 0;
  final len = encoded.length;
  while (index < len) {
    int shift = 0, r = 0, b;
    do { b = encoded.codeUnitAt(index++) - 63; r |= (b & 0x1f) << shift; shift += 5; }
    while (b >= 0x20);
    lat += (r & 1) != 0 ? ~(r >> 1) : r >> 1;
    shift = 0; r = 0;
    do { b = encoded.codeUnitAt(index++) - 63; r |= (b & 0x1f) << shift; shift += 5; }
    while (b >= 0x20);
    lng += (r & 1) != 0 ? ~(r >> 1) : r >> 1;
    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark map style (same palette as OutdoorNavigationScreen)
// ─────────────────────────────────────────────────────────────────────────────

const String _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1a2e1a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#a5b4a5"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d1f0d"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2d4a2d"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a2e1a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d2030"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f3d1f"}]}
]
''';
