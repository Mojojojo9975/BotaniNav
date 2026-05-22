// lib/screens/indoor_navigation_screen.dart
//
// Indoor navigation experience.
// Two view modes toggled by the user:
//   MAP    — flutter_map floor plan with GeoJSON layers + arrow/gauge overlay
//   CAMERA — live camera feed with AR-style arrow/gauge overlay
//
// TODO [Backend Phase 3 / Hardware]: BLE, WS, and QR scan use mock data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/navigation_provider.dart';
import '../providers/plant_provider.dart';
import '../services/api_service.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/indoor_map_widget.dart';

enum _ViewMode { map, camera }

class IndoorNavigationScreen extends ConsumerStatefulWidget {
  const IndoorNavigationScreen({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<IndoorNavigationScreen> createState() =>
      _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState
    extends ConsumerState<IndoorNavigationScreen> {
  _ViewMode _viewMode = _ViewMode.map;
  bool _scannerVisible = false;

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantByIdProvider(widget.plantId));
    final navAsync = ref.watch(navigationStateProvider(widget.plantId));
    final arrowAngle = ref.watch(arrowAngleProvider(widget.plantId));

    // Handle arrival.
    ref.listen(navigationStateProvider(widget.plantId), (_, next) {
      next.whenData((state) {
        if (state.arrived && mounted) {
          context.go('/arrival/${widget.plantId}');
        }
      });
    });

    final hotColdScore =
        navAsync.whenOrNull(data: (s) => s.hotColdScore) ?? 0.5;
    final hint = navAsync.whenOrNull(data: (s) => s.hint);
    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Main view (map or camera) ──────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _viewMode == _ViewMode.map
                ? IndoorMapWidget(key: const ValueKey('map'))
                : CameraOverlay(
                    key: const ValueKey('camera'),
                    angleDegrees: arrowAngle,
                    hotColdScore: hotColdScore,
                    hint: hint,
                  ),
          ),

          // ── Arrow + gauge overlay on map view ──────────────────────────────
          if (_viewMode == _ViewMode.map) ...[
            // Directional arrow centred on screen
            IgnorePointer(
              child: Center(
                child: _FloatingArrow(angleDegrees: arrowAngle),
              ),
            ),
            // Gauge pinned right
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: _GaugePanel(
                    score: hotColdScore,
                    hint: hint,
                  ),
                ),
              ),
            ),
          ],

          // ── Top info bar ───────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopBar(
                plantName: plant?.name ?? '…',
                section: plant?.section,
                distanceMetres: distance,
              ),
            ),
          ),

          // ── View toggle + QR button bar ────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _BottomBar(
              viewMode: _viewMode,
              onToggle: () => setState(() {
                _viewMode = _viewMode == _ViewMode.map
                    ? _ViewMode.camera
                    : _ViewMode.map;
              }),
              onQrScan: () => setState(() => _scannerVisible = true),
            ),
          ),

          // ── QR scanner overlay ─────────────────────────────────────────────
          if (_scannerVisible)
            _QrScannerOverlay(
              plantId: widget.plantId,
              onClose: () => setState(() => _scannerVisible = false),
            ),

          // ── Mock data badge ────────────────────────────────────────────────
          // TODO [Backend Phase 3 / Hardware]: Remove before production.
          const Positioned(
            bottom: 100,
            right: 12,
            child: _MockDataBadge(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow overlay for map mode (semi-transparent so map stays readable)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingArrow extends StatelessWidget {
  const _FloatingArrow({required this.angleDegrees});
  final double angleDegrees;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.45),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
      ),
      child: Transform.rotate(
        angle: angleDegrees * 3.14159265 / 180,
        child: const Icon(Icons.navigation, color: Colors.greenAccent, size: 36),
      ),
    );
  }
}

class _GaugePanel extends StatelessWidget {
  const _GaugePanel({required this.score, this.hint});
  final double score;
  final String? hint;

  static Color _scoreColor(double s) {
    final hue = (1.0 - s) * 240.0;
    return HSVColor.fromAHSV(1.0, hue, 0.85, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(score >= 0.7 ? '🔥' : score >= 0.4 ? '🌡' : '❄️',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            width: 18,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  heightFactor: score.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 48,
              child: Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.plantName, this.section, this.distanceMetres});
  final String plantName;
  final String? section;
  final double? distanceMetres;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_work_outlined, color: Colors.tealAccent, size: 20),
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
                      fontSize: 14),
                ),
                if (section != null)
                  Text('Section $section',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (distanceMetres != null)
            Text(
              '${distanceMetres!.toStringAsFixed(1)} m',
              style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.viewMode,
    required this.onToggle,
    required this.onQrScan,
  });
  final _ViewMode viewMode;
  final VoidCallback onToggle;
  final VoidCallback onQrScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Map/Camera toggle
        FilledButton.icon(
          onPressed: onToggle,
          icon: Icon(viewMode == _ViewMode.map
              ? Icons.videocam_outlined
              : Icons.map_outlined),
          label: Text(viewMode == _ViewMode.map ? 'Camera' : 'Floor Plan'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(width: 12),
        // QR scan
        FilledButton.icon(
          onPressed: onQrScan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black87,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR scanner overlay
// ─────────────────────────────────────────────────────────────────────────────

class _QrScannerOverlay extends ConsumerStatefulWidget {
  const _QrScannerOverlay({required this.plantId, required this.onClose});
  final String plantId;
  final VoidCallback onClose;

  @override
  ConsumerState<_QrScannerOverlay> createState() => _QrScannerOverlayState();
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
      // TODO [Backend Phase 3 / Hardware]: Remove snackbar once endpoint is live.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('QR scan pending backend: $e'),
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
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ),
      ],
    );
  }
}

class _MockDataBadge extends StatelessWidget {
  const _MockDataBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'MOCK DATA',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
        ),
      );
}