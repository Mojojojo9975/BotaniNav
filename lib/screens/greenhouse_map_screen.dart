// lib/screens/greenhouse_map_screen.dart
//
// Two modes:
//   Browse  (plantId == null) — floor plan with section popups only.
//   Navigate (plantId != null) — adds arrow, gauge, QR scan, active section.

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

  /// Build a section → plant-name map from the loaded plant catalogue.
  Map<String, String> _buildSectionMap(List<Plant> plants) {
    return {
      for (final p in plants.where((p) => p.isIndoor && p.section.isNotEmpty))
        p.section: p.commonNameOrName,
    };
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
    final targetPlant = plantId != null
        ? ref.watch(plantByIdProvider(plantId!))
        : null;

    // Build section→name map from backend plants when available,
    // fall back to empty map while loading.
    final sectionMap = plantsAsync.whenOrNull(
          data: (plants) => _buildSectionMap(plants),
        ) ??
        {};

    final activeSection = targetPlant?.section;

    return _GreenhouseMapScaffold(
      plantId: plantId,
      sectionPlantMap: sectionMap,
      activeSection: activeSection,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateful scaffold (owns QR scanner visibility)
// ─────────────────────────────────────────────────────────────────────────────

class _GreenhouseMapScaffold extends ConsumerStatefulWidget {
  const _GreenhouseMapScaffold({
    required this.plantId,
    required this.sectionPlantMap,
    required this.activeSection,
  });
  final String? plantId;
  final Map<String, String> sectionPlantMap;
  final String? activeSection;

  @override
  ConsumerState<_GreenhouseMapScaffold> createState() =>
      _GreenhouseMapScaffoldState();
}

class _GreenhouseMapScaffoldState
    extends ConsumerState<_GreenhouseMapScaffold> {
  bool _scannerVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Floor plan ────────────────────────────────────────────────────
          IndoorMapWidget(
            plantId: widget.plantId,
            activeSection: widget.activeSection,
            sectionPlantMap: widget.sectionPlantMap,
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: widget.plantId != null
                  ? _NavTopBar(plantId: widget.plantId!)
                  : _BrowseTopBar(),
            ),
          ),

          // ── Navigation overlays ───────────────────────────────────────────
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

          // ── Legend (browse mode) ──────────────────────────────────────────
          if (widget.plantId == null)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(child: _Legend()),
            ),

          // ── QR scanner overlay ────────────────────────────────────────────
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
// Arrow + gauge panels
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowPanel extends ConsumerWidget {
  const _ArrowPanel({required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final angle = ref.watch(arrowAngleProvider(plantId));
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.65),
        border: Border.all(
            color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.15),
            blurRadius: 12, spreadRadius: 2,
          ),
        ],
      ),
      child: Transform.rotate(
        angle: angle * 3.14159265 / 180,
        child: const Icon(Icons.navigation,
            color: Colors.greenAccent, size: 34),
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
            height: 100, width: 16,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                          color: color.withOpacity(0.5), blurRadius: 8),
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
// QR button + scanner overlay
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
            child:
                Icon(Icons.qr_code_scanner, color: Colors.black87, size: 24),
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
          top: 48, right: 16,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: widget.onClose,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          bottom: 80, left: 0, right: 0,
          child: Text(
            'Point at a section QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: 14,
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension — Plant.commonNameOrName helper
// ─────────────────────────────────────────────────────────────────────────────

extension PlantDisplayName on Plant {
  String get commonNameOrName => name;
}