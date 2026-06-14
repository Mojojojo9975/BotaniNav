// lib/screens/outdoor_map_screen.dart
//
// Browse map — shows all outdoor plants as markers on Google Maps.
// No active navigation. Tapping a marker starts navigation to that plant.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

  // Trail builder state variables
  bool _trailMode = false;
  final List<Plant> _trailPlants = [];
  final Map<int, BitmapDescriptor> _numberedIcons = {};
  bool _iconsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNumberedIcons();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _mapController?.setMapStyle(_mapStyle);
  }

  Future<void> _loadNumberedIcons() async {
    if (_iconsLoaded) return;
    for (int i = 1; i <= 10; i++) {
      final icon = await _createNumberedMarkerIcon(i);
      _numberedIcons[i] = icon;
    }
    if (mounted) {
      setState(() {
        _iconsLoaded = true;
      });
    }
  }

  Future<BitmapDescriptor> _createNumberedMarkerIcon(int number) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 80.0;

    // Draw marker background circle
    final Paint paint = Paint()..color = Colors.lightGreenAccent;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF0D1A0D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - 2.5, borderPaint);

    // Draw number text
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: '$number',
      style: const TextStyle(
        fontSize: 36.0,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D1A0D),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _toggleTrailMode() {
    setState(() {
      _trailMode = !_trailMode;
      _selectedPlant = null;
      _trailPlants.clear();
    });
  }

  double _calculateEstimatedDistance(LatLng? userPos) {
    if (_trailPlants.isEmpty) return 0.0;
    double total = 0.0;
    LatLng current = userPos ?? LatLng(_trailPlants.first.gpsLat!, _trailPlants.first.gpsLng!);
    
    // If we have user position, first leg is user to plant 1
    if (userPos != null) {
      total += Geolocator.distanceBetween(
        current.latitude, current.longitude,
        _trailPlants.first.gpsLat!, _trailPlants.first.gpsLng!,
      );
    }
    
    for (int i = 0; i < _trailPlants.length - 1; i++) {
      total += Geolocator.distanceBetween(
        _trailPlants[i].gpsLat!, _trailPlants[i].gpsLng!,
        _trailPlants[i+1].gpsLat!, _trailPlants[i+1].gpsLng!,
      );
    }
    return total;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
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
        
        final trailIndex = _trailPlants.indexWhere((tp) => tp.id == p.id);
        final isSelectedInTrail = _trailMode && trailIndex >= 0;
        final isSelected = _selectedPlant?.id == p.id;
        
        BitmapDescriptor icon;
        if (_trailMode) {
          if (isSelectedInTrail) {
            icon = _numberedIcons[trailIndex + 1] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          } else {
            icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
          }
        } else {
          icon = BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueCyan,
          );
        }

        markers.add(Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.gpsLat!, p.gpsLng!),
          icon: icon,
          infoWindow: InfoWindow(
            title: _trailMode
                ? (isSelectedInTrail ? '#${trailIndex + 1} · ${p.displayName}' : p.displayName)
                : p.displayName,
            snippet: '${p.name} · Section ${p.section}',
          ),
          zIndex: isSelectedInTrail ? 3 : (isSelected ? 2 : 1),
          onTap: () {
            if (_trailMode) {
              setState(() {
                final index = _trailPlants.indexWhere((tp) => tp.id == p.id);
                if (index >= 0) {
                  _trailPlants.removeAt(index);
                } else {
                  if (_trailPlants.length < 10) {
                    _trailPlants.add(p);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Maximum 10 plants in a trail')),
                    );
                  }
                }
              });
            } else {
              setState(() => _selectedPlant = p);
            }
          },
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
            onTap: (_) {
              if (!_trailMode) {
                setState(() => _selectedPlant = null);
              }
            },
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
                    Expanded(
                      child: Text(
                        _trailMode ? 'Trail Builder' : 'Outdoor Plant Map',
                        style: const TextStyle(
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
          if (!_trailMode && _selectedPlant != null)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _PlantCard(
                plant: _selectedPlant!,
                onNavigate: () =>
                    context.go('/navigate/outdoor/${_selectedPlant!.id}'),
                onDismiss: () => setState(() => _selectedPlant = null),
              ),
            ),

          // ── Trail builder bottom card ───────────────────────────────────────
          if (_trailMode)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _TrailBuilderCard(
                selectedCount: _trailPlants.length,
                distanceString: _formatDistance(_calculateEstimatedDistance(userPos)),
                onStart: _trailPlants.isEmpty
                    ? null
                    : () {
                        final plantIds = _trailPlants.map((p) => p.id).join(',');
                        context.go('/navigate/trail?plants=$plantIds');
                      },
                onCancel: _toggleTrailMode,
              ),
            ),

          // ── Build Trail FAB ───────────────────────────────────────────────
          if (!_trailMode)
            Positioned(
              bottom: _selectedPlant != null ? 210 : 130,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'build_trail',
                backgroundColor: const Color(0xFF1A2E1A),
                foregroundColor: Colors.lightGreenAccent,
                icon: const Icon(Icons.route),
                label: const Text('Build Trail'),
                onPressed: _toggleTrailMode,
              ),
            ),

          // ── My location button ────────────────────────────────────────────
          Positioned(
            bottom: _trailMode
                ? 210
                : (_selectedPlant != null ? 160 : 80),
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
// Trail builder bottom card
// ─────────────────────────────────────────────────────────────────────────────

class _TrailBuilderCard extends StatelessWidget {
  const _TrailBuilderCard({
    required this.selectedCount,
    required this.distanceString,
    required this.onStart,
    required this.onCancel,
  });

  final int selectedCount;
  final String distanceString;
  final VoidCallback? onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.lightGreenAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Trail Builder',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(Icons.close, color: Colors.white38, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap plants on the map in the order you want to visit them.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.lightGreenAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.lightGreenAccent.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$selectedCount / 10 plants',
                    style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                if (selectedCount > 0)
                  Text(
                    'Est. Distance: ~$distanceString',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.lightGreenAccent,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Start Trail',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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