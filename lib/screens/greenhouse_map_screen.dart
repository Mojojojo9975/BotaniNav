// lib/screens/greenhouse_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/plant.dart';
import '../providers/navigation_provider.dart';
import '../providers/plant_provider.dart';
import '../services/api_service.dart';
import '../widgets/indoor_map_widget.dart';

class GreenhouseMapScreen extends ConsumerWidget {
  const GreenhouseMapScreen({super.key, this.plantId});
  final String? plantId;

  /// Build a section → List<Plant> map from the loaded plant catalogue.
  /// Multiple plants can share the same section.
  Map<String, List<Plant>> _buildSectionMap(List<Plant> plants) {
    final map = <String, List<Plant>>{};
    for (final p in plants.where((p) => p.isIndoor && p.section.isNotEmpty)) {
      map.putIfAbsent(p.section, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plantId != null) {
      ref.listen(navigationStateProvider(plantId!), (_, next) {
        next.whenData((state) {
          if (state.arrived && context.mounted) {
            context.go('/arrival/$plantId');
          }
        });
      });
    }

    final plantsAsync = ref.watch(plantsProvider);
    final targetPlant =
        plantId != null ? ref.watch(plantByIdProvider(plantId!)) : null;

    final sectionMap = plantsAsync.whenOrNull(
          data: (plants) => _buildSectionMap(plants),
        ) ??
        {};

    return _GreenhouseMapScaffold(
      plantId: plantId,
      sectionPlantMap: sectionMap,
      activeSection: targetPlant?.section,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _GreenhouseMapScaffold extends ConsumerStatefulWidget {
  const _GreenhouseMapScaffold({
    required this.plantId,
    required this.sectionPlantMap,
    required this.activeSection,
  });
  final String? plantId;
  final Map<String, List<Plant>> sectionPlantMap;
  final String? activeSection;

  @override
  ConsumerState<_GreenhouseMapScaffold> createState() =>
      _GreenhouseMapScaffoldState();
}

class _GreenhouseMapScaffoldState
    extends ConsumerState<_GreenhouseMapScaffold> {
  bool _scannerVisible = false;

  void _onSectionTapped(String label, List<Plant> plants) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SectionBottomSheet(
        sectionLabel: label,
        plants: plants,
        currentPlantId: widget.plantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndoorMapWidget(
            plantId: widget.plantId,
            activeSection: widget.activeSection,
            sectionPlantMap: widget.sectionPlantMap,
            onSectionTapped: _onSectionTapped,
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: widget.plantId != null
                  ? _NavTopBar(plantId: widget.plantId!)
                  : _BrowseTopBar(),
            ),
          ),

          if (widget.plantId != null) ...[
            Positioned(
              bottom: 48, left: 24,
              child: _ArrowPanel(plantId: widget.plantId!),
            ),
            Positioned(
              bottom: 48, right: 80,
              child: _HotColdPanel(plantId: widget.plantId!),
            ),
            Positioned(
              bottom: 48, right: 24,
              child: _QrButton(
                onPressed: () => setState(() => _scannerVisible = true),
              ),
            ),
          ],

          if (widget.plantId == null)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(child: _Legend()),
            ),

          if (_scannerVisible)
            _QrScannerOverlay(
              plantId: widget.plantId ?? '',
              onClose: () => setState(() => _scannerVisible = false),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section bottom sheet — scrollable list of all plants in a section
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBottomSheet extends StatelessWidget {
  const _SectionBottomSheet({
    required this.sectionLabel,
    required this.plants,
    this.currentPlantId,
  });

  final String sectionLabel;
  final List<Plant> plants;
  final String? currentPlantId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: plants.length == 1 ? 0.28 : 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent.withOpacity(0.15),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(
                        sectionLabel,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Section $sectionLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${plants.length} plant${plants.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Scrollable plant list
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                itemCount: plants.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (_, i) => _PlantRow(
                  plant: plants[i],
                  isActive: plants[i].id == currentPlantId,
                  onNavigate: () {
                    Navigator.of(context).pop();
                    context.go('/navigate/indoor/${plants[i].id}');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantRow extends StatelessWidget {
  const _PlantRow({
    required this.plant,
    required this.isActive,
    required this.onNavigate,
  });

  final Plant plant;
  final bool isActive;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.white10,
              border: isActive
                  ? Border.all(color: Colors.greenAccent, width: 1.5)
                  : null,
            ),
            child: Icon(
              Icons.eco,
              color: isActive ? Colors.greenAccent : Colors.white38,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Name + scientific name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plant.name,
                        style: TextStyle(
                          color: isActive
                              ? Colors.greenAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Navigating',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  plant.scientificName,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                if (plant.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    plant.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11, height: 1.4),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Navigate button
          if (!isActive)
            IconButton(
              onPressed: onNavigate,
              icon: const Icon(Icons.near_me_outlined,
                  color: Colors.greenAccent, size: 22),
              tooltip: 'Navigate here',
              style: IconButton.styleFrom(
                backgroundColor: Colors.greenAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bars
// ─────────────────────────────────────────────────────────────────────────────

class _BrowseTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
          const Text(
            'Greenhouse Floor Plan',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                _LegendDot(color: Colors.greenAccent, label: 'Has plant'),
                const SizedBox(width: 10),
                _LegendDot(color: Colors.white38, label: 'Empty'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTopBar extends ConsumerWidget {
  const _NavTopBar({required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = ref.watch(plantByIdProvider(plantId));
    final navAsync = ref.watch(navigationStateProvider(plantId));
    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);
    final hint = navAsync.whenOrNull(data: (s) => s.hint);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => context.go('/'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.eco, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant?.name ?? 'Navigating…',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                if (plant?.section.isNotEmpty == true)
                  Text(
                    'Section ${plant!.section}',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 11),
                  )
                else if (hint != null)
                  Text(hint,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          if (distance != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Text(
                '${distance.toStringAsFixed(1)} m',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow + Gauge panels
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowPanel extends ConsumerWidget {
  const _ArrowPanel({required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final angle = ref.watch(arrowAngleProvider(plantId));
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.65),
        border:
            Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.greenAccent.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2),
        ],
      ),
      child: Transform.rotate(
        angle: angle * 3.14159265 / 180,
        child:
            const Icon(Icons.navigation, color: Colors.greenAccent, size: 34),
      ),
    );
  }
}

class _HotColdPanel extends ConsumerWidget {
  const _HotColdPanel({required this.plantId});
  final String plantId;

  static Color _scoreColor(double s) =>
      HSVColor.fromAHSV(1.0, (1.0 - s) * 240.0, 0.85, 0.95).toColor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navAsync = ref.watch(navigationStateProvider(plantId));
    final score = navAsync.whenOrNull(data: (s) => s.hotColdScore) ?? 0.5;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(score >= 0.7 ? '🔥' : score >= 0.4 ? '🌡' : '❄️',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          SizedBox(
            height: 100,
            width: 16,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8)),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  heightFactor: score.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.5), blurRadius: 8)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR button + scanner
// ─────────────────────────────────────────────────────────────────────────────

class _QrButton extends StatelessWidget {
  const _QrButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.tealAccent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.qr_code_scanner,
                color: Colors.black87, size: 24),
          ),
        ),
      );
}

class _QrScannerOverlay extends ConsumerStatefulWidget {
  const _QrScannerOverlay(
      {required this.plantId, required this.onClose});
  final String plantId;
  final VoidCallback onClose;

  @override
  ConsumerState<_QrScannerOverlay> createState() =>
      _QrScannerOverlayState();
}

class _QrScannerOverlayState extends ConsumerState<_QrScannerOverlay> {
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final sectionId = capture.barcodes.firstOrNull?.rawValue;
    if (sectionId == null) return;
    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.postQrScan(sectionId: sectionId);
      if (mounted) widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('QR scan pending backend phase 3: $e'),
          backgroundColor: Colors.orange,
        ));
        widget.onClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(onDetect: _onDetect),
        Positioned(
          top: 48,
          right: 16,
          child: SafeArea(
            child: IconButton(
              icon:
                  const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: widget.onClose,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            'Point at a section QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: Color(0xFF1E3A1E), label: 'Areas'),
            SizedBox(width: 14),
            _LegendDot(color: Color(0xFF4CAF50), label: 'Walls'),
            SizedBox(width: 14),
            _LegendDot(color: Colors.greenAccent, label: 'Has plant'),
            SizedBox(width: 14),
            _LegendDot(color: Colors.white38, label: 'Empty'),
          ],
        ),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );
}

extension PlantDisplayName on Plant {
  String get commonNameOrName => name;
}