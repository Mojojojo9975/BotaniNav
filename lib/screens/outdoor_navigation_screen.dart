// lib/screens/outdoor_navigation_screen.dart
//
// Full outdoor navigation experience:
//   • Google Maps with encoded polyline decoded and drawn as a route.
//   • Step-by-step instruction banner at the top.
//   • Bottom sheet with remaining distance, ETA, and full step list.
//   • Watches GPS position and re-centres the camera as the user moves.
//   • Routes to ArrivalScreen when navigationState.arrived == true.
//
// All state comes from Riverpod providers — zero business logic in this file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_state.dart';
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_mapStyle);
  }

  // Re-centre camera to user position when GPS updates.
  void _animateTo(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantByIdProvider(widget.plantId));
    final routeAsync = ref.watch(outdoorRouteProvider(widget.plantId));
    final navAsync = ref.watch(navigationStateProvider(widget.plantId));
    final gpsAsync = ref.watch(gpsPositionProvider);

    // Handle arrival.
    ref.listen(navigationStateProvider(widget.plantId), (_, next) {
      next.whenData((state) {
        if (state.arrived && mounted) {
          context.go('/arrival/${widget.plantId}');
        }
      });
    });

    // Animate map when GPS updates.
    ref.listen(gpsPositionProvider, (_, next) {
      next.whenData((pos) {
        _animateTo(LatLng(pos.latitude, pos.longitude));
      });
    });

    final initialPosition = gpsAsync.whenOrNull(
          data: (pos) => LatLng(pos.latitude, pos.longitude),
        ) ??
        const LatLng(60.1699, 24.9384); // Helsinki default

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────────
          routeAsync.when(
            loading: () => GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 17,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            error: (e, _) => _MapError(message: e.toString()),
            data: (route) {
              final polylinePoints = _decodePolyline(route.polyline);
              final destination =
                  LatLng(route.destinationLat, route.destinationLng);

              return GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 17,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: polylinePoints,
                    color: Colors.greenAccent,
                    width: 5,
                  ),
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: destination,
                    infoWindow: InfoWindow(
                      title: route.plantName,
                      snippet: plant?.section,
                    ),
                  ),
                },
              );
            },
          ),

          // ── Top instruction banner ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _InstructionBanner(
                navAsync: navAsync,
                plantName: plant?.name ?? '…',
              ),
            ),
          ),

          // ── Bottom info sheet ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: routeAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (route) => _BottomRouteSheet(
                route: route,
                navState: navAsync.whenOrNull(data: (s) => s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Polyline decoder — converts Google encoded polyline → LatLng list.
// ─────────────────────────────────────────────────────────────────────────────

List<LatLng> _decodePolyline(String encoded) {
  final result = <LatLng>[];
  int index = 0;
  final len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int shift = 0;
    int result0 = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = ((result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1));
    lat += dlat;

    shift = 0;
    result0 = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = ((result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1));
    lng += dlng;

    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets — purely presentational
// ─────────────────────────────────────────────────────────────────────────────

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.navAsync,
    required this.plantName,
  });

  final AsyncValue<NavigationState> navAsync;
  final String plantName;

  @override
  Widget build(BuildContext context) {
    final hint = navAsync.whenOrNull(data: (s) => s.hint) ?? 'Loading…';
    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (distance != null)
            Text(
              distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)} km'
                  : '${distance.toStringAsFixed(0)} m',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomRouteSheet extends StatelessWidget {
  const _BottomRouteSheet({required this.route, this.navState});
  final OutdoorRoute route;
  final NavigationState? navState;

  @override
  Widget build(BuildContext context) {
    final minutes = (route.durationSeconds / 60).ceil();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.directions_walk,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${route.distanceMetres >= 1000 ? "${(route.distanceMetres / 1000).toStringAsFixed(1)} km" : "${route.distanceMetres.toStringAsFixed(0)} m"}'
                  '  ·  ~$minutes min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // First two steps only — keep sheet compact.
          ...route.steps.take(2).map(
                (step) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_forward,
                      color: Colors.white38, size: 16),
                  title: Text(
                    step.instruction,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white38, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Could not load route',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark map style JSON (optional aesthetic — matches the app theme).
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
