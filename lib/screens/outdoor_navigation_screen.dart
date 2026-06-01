// lib/screens/outdoor_navigation_screen.dart
//
// Full outdoor navigation experience:
//   • Google Maps with all outdoor plant markers.
//   • Green route polyline to the target plant.
//   • Top banner — plant name, hint, live distance from WebSocket.
//   • Rotating navigation arrow indicating bearing to target.
//   • Bottom sheet — walking distance, ETA, step-by-step instructions.
//   • "No coordinates yet" state shown if the plant hasn't been mapped.
//   • Auto-routes to ArrivalScreen on arrival.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_state.dart';
import '../models/plant.dart';
import '../providers/navigation_provider.dart';
import '../providers/plant_provider.dart';

class OutdoorNavigationScreen extends ConsumerStatefulWidget {
  const OutdoorNavigationScreen({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<OutdoorNavigationScreen> createState() =>
      _OutdoorNavigationScreenState();
}

class _OutdoorNavigationScreenState
    extends ConsumerState<OutdoorNavigationScreen> {
  GoogleMapController? _mapController;
  bool _followUser = true;       // auto-pan to user; disabled on manual drag
  bool _sheetExpanded = false;   // bottom sheet toggle

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _mapController?.setMapStyle(_mapStyle);
  }

  void _animateTo(LatLng pos) {
    if (!_followUser) return;
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  void _fitRoute(LatLng user, LatLng dest) {
    final sw = LatLng(
      user.latitude  < dest.latitude  ? user.latitude  : dest.latitude,
      user.longitude < dest.longitude ? user.longitude : dest.longitude,
    );
    final ne = LatLng(
      user.latitude  > dest.latitude  ? user.latitude  : dest.latitude,
      user.longitude > dest.longitude ? user.longitude : dest.longitude,
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plant      = ref.watch(plantByIdProvider(widget.plantId));
    final plantsAsync = ref.watch(plantsProvider);
    final routeAsync = ref.watch(outdoorRouteProvider(widget.plantId));
    final navAsync   = ref.watch(navigationStateProvider(widget.plantId));
    final arrowAngle = ref.watch(arrowAngleProvider(widget.plantId));
    final gpsAsync   = ref.watch(gpsPositionProvider);

    // Arrival listener
    ref.listen(navigationStateProvider(widget.plantId), (_, next) {
      next.whenData((s) {
        if (s.arrived && mounted) context.go('/arrival/${widget.plantId}');
      });
    });

    // Auto-pan to user
    ref.listen(gpsPositionProvider, (_, next) {
      next.whenData((pos) => _animateTo(LatLng(pos.latitude, pos.longitude)));
    });

    // Fit both user + destination once route loads
    ref.listen(outdoorRouteProvider(widget.plantId), (_, next) {
      next.whenData((route) {
        final pos = gpsAsync.whenOrNull(data: (p) => p);
        if (pos != null && _mapController != null) {
          _fitRoute(
            LatLng(pos.latitude, pos.longitude),
            LatLng(route.destinationLat, route.destinationLng),
          );
        }
      });
    });

    final userPos = gpsAsync.whenOrNull(
      data: (p) => LatLng(p.latitude, p.longitude),
    );

    // Show "no coordinates" screen if plant exists but has no GPS
    if (plant != null && !plant.isIndoor && !plant.hasGpsCoords) {
      return _NoCoordinatesScreen(plant: plant);
    }

    // Collect all outdoor mapped plants for markers
    final allOutdoorMarkers = <Marker>{};
    plantsAsync.whenOrNull(data: (plants) {
      for (final p in plants.where((p) => !p.isIndoor && p.hasGpsCoords)) {
        final isTarget = p.id == widget.plantId;
        allOutdoorMarkers.add(Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.gpsLat!, p.gpsLng!),
          infoWindow: InfoWindow(
            title: p.displayName,
            snippet: p.section,
          ),
          icon: isTarget
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueCyan),
          zIndex: isTarget ? 2 : 1,
          onTap: isTarget
              ? null
              : () => context.go('/navigate/outdoor/${p.id}'),
        ));
      }
    });

    // Route polyline
    Set<Polyline> polylines = {};
    routeAsync.whenOrNull(data: (route) {
      polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _decodePolyline(route.polyline),
          color: Colors.greenAccent,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    });

    final initialTarget = userPos ??
        (plant?.hasGpsCoords == true
            ? LatLng(plant!.gpsLat!, plant.gpsLng!)
            : const LatLng(65.0638, 25.4638)); // Oulu Botanical Garden

    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);
    final hint     = navAsync.whenOrNull(data: (s) => s.hint);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: initialTarget, zoom: 17),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: allOutdoorMarkers,
            polylines: polylines,
            onCameraMoveStarted: () {
              // User dragged — stop auto-following
              setState(() => _followUser = false);
            },
          ),

          // ── Top banner ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: _TopBanner(
                plant: plant,
                hint: hint,
                distance: distance,
                isLoading: routeAsync.isLoading,
                hasError: routeAsync.hasError,
                onBack: () => context.go('/'),
              ),
            ),
          ),

          // ── Re-centre button (shown when user has panned away) ─────────────
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

          // ── Navigation arrow ───────────────────────────────────────────────
          Positioned(
            bottom: _sheetExpanded ? 260 : 140,
            left: 16,
            child: _ArrowIndicator(
              angleDegrees: arrowAngle,
              distance: distance,
            ),
          ),

          // ── Bottom route sheet ─────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: routeAsync.when(
              loading: () => _BottomSheetLoading(),
              error: (e, _) => _BottomSheetError(message: e.toString()),
              data: (route) => _BottomRouteSheet(
                route: route,
                expanded: _sheetExpanded,
                onToggle: () =>
                    setState(() => _sheetExpanded = !_sheetExpanded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No coordinates screen
// ─────────────────────────────────────────────────────────────────────────────

class _NoCoordinatesScreen extends StatelessWidget {
  const _NoCoordinatesScreen({required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Icon(Icons.location_off,
                    color: Colors.amber, size: 42),
              ),
              const SizedBox(height: 24),
              Text(
                plant.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                plant.name,
                style: const TextStyle(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                    fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Text(
                  'This plant hasn\'t been mapped yet.\n\n'
                  'A staff member needs to use the Coordinate Picker tool '
                  'to assign GPS coordinates to this plant, then the '
                  'backend must be updated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      height: 1.6),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to plant list'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top banner
// ─────────────────────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  const _TopBanner({
    required this.plant,
    required this.hint,
    required this.distance,
    required this.isLoading,
    required this.hasError,
    required this.onBack,
  });

  final Plant? plant;
  final String? hint;
  final double? distance;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
            blurRadius: 8)],
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
          const Icon(Icons.park_outlined, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant?.displayName ?? '…',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isLoading
                      ? 'Calculating route…'
                      : hasError
                          ? 'Could not load route'
                          : (hint ?? 'Follow the route'),
                  style: TextStyle(
                      color: hasError ? Colors.redAccent : Colors.white60,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          if (distance != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Text(
                distance! >= 1000
                    ? '${(distance! / 1000).toStringAsFixed(1)} km'
                    : '${distance!.toStringAsFixed(0)} m',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation arrow
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
        child: const Icon(Icons.navigation,
            color: Colors.greenAccent, size: 30),
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
              Text('Calculating route…',
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
                message.contains('route')
                    ? 'Route unavailable — walk toward the green marker'
                    : message,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _BottomRouteSheet extends StatelessWidget {
  const _BottomRouteSheet({
    required this.route,
    required this.expanded,
    required this.onToggle,
  });
  final OutdoorRoute route;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final minutes = (route.durationSeconds / 60).ceil();
    final distStr = route.distanceMetres >= 1000
        ? '${(route.distanceMetres / 1000).toStringAsFixed(1)} km'
        : '${route.distanceMetres.toStringAsFixed(0)} m';

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
          // Handle + summary row
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
                        '$distStr  ·  ~$minutes min',
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
                ],
              ),
            ),
          ),

          // Expanded steps list
          if (expanded) ...[
            const Divider(color: Colors.white12, height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: route.steps.length,
                itemBuilder: (_, i) {
                  final step = route.steps[i];
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
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Polyline decoder
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
// Dark map style
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