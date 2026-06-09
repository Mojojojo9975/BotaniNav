// lib/screens/outdoor_map_screen.dart
//
// Browse map — shows all outdoor plants as markers on Google Maps.
// No active navigation. Tapping a marker starts navigation to that plant.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';
import '../providers/navigation_provider.dart';

class OutdoorMapScreen extends ConsumerStatefulWidget {
  const OutdoorMapScreen({super.key});

  @override
  ConsumerState<OutdoorMapScreen> createState() => _OutdoorMapScreenState();
}

class _OutdoorMapScreenState extends ConsumerState<OutdoorMapScreen> {
  GoogleMapController? _mapController;
  Plant? _selectedPlant;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _mapController?.setMapStyle(_mapStyle);
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);
    final gpsAsync    = ref.watch(gpsPositionProvider);

    final userPos = gpsAsync.whenOrNull(
      data: (p) => LatLng(p.latitude, p.longitude),
    );

    // Build markers for all outdoor plants that have GPS coordinates
    final markers = <Marker>{};
    int unmapped = 0;

    plantsAsync.whenOrNull(data: (plants) {
      final outdoor = plants.where((p) => !p.isIndoor).toList();
      for (final p in outdoor) {
        if (!p.hasGpsCoords) { unmapped++; continue; }
        final isSelected = _selectedPlant?.id == p.id;
        markers.add(Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.gpsLat!, p.gpsLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueCyan,
          ),
          infoWindow: InfoWindow(
            title: p.displayName,
            snippet: '${p.name} · Section ${p.section}',
          ),
          zIndex: isSelected ? 2 : 1,
          onTap: () => setState(() => _selectedPlant = p),
        ));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              // Always open centred on Oulu Botanical Garden
              target: LatLng(65.0638, 25.4638),
              zoom: 17,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: markers,
            onTap: (_) => setState(() => _selectedPlant = null),
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E1A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.lightGreenAccent.withOpacity(0.3)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white70),
                      onPressed: () => context.go('/'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.park_outlined,
                        color: Colors.lightGreenAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Outdoor Plant Map',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                    // Plant count chip
                    plantsAsync.whenOrNull(
                      data: (plants) {
                        final mapped = plants
                            .where((p) => !p.isIndoor && p.hasGpsCoords)
                            .length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.lightGreenAccent
                                    .withOpacity(0.4)),
                          ),
                          child: Text(
                            '$mapped plants',
                            style: const TextStyle(
                                color: Colors.lightGreenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ) ?? const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),

          // ── Unmapped warning ──────────────────────────────────────────────
          if (unmapped > 0)
            Positioned(
              top: 80, left: 0, right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Text(
                      '$unmapped plant${unmapped == 1 ? '' : 's'} not yet mapped',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),

          // ── Selected plant card ───────────────────────────────────────────
          if (_selectedPlant != null)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _PlantCard(
                plant: _selectedPlant!,
                onNavigate: () =>
                    context.go('/navigate/outdoor/${_selectedPlant!.id}'),
                onDismiss: () => setState(() => _selectedPlant = null),
              ),
            ),

          // ── My location button ────────────────────────────────────────────
          Positioned(
            bottom: _selectedPlant != null ? 160 : 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: const Color(0xFF1A2E1A),
              foregroundColor: Colors.lightGreenAccent,
              onPressed: () {
                if (userPos != null) {
                  _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(userPos, 18));
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Loading state ─────────────────────────────────────────────────
          if (plantsAsync.isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.lightGreenAccent),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected plant card
// ─────────────────────────────────────────────────────────────────────────────

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.onNavigate,
    required this.onDismiss,
  });
  final Plant plant;
  final VoidCallback onNavigate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.lightGreenAccent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Plant image or icon
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: plant.displayImageUrl != null
                  ? Image.network(
                      plant.displayImageUrl!,
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconBox(),
                    )
                  : _iconBox(),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.name,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (plant.family != null) ...[
                          Text(plant.family!,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          const Text(' · ',
                              style: TextStyle(color: Colors.white24)),
                        ],
                        Text('Section ${plant.section}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.near_me, size: 14),
                    label: const Text('Go', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.lightGreenAccent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 80, height: 80,
        color: Colors.lightGreenAccent.withOpacity(0.1),
        child: const Icon(Icons.park_outlined,
            color: Colors.lightGreenAccent, size: 32),
      );
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