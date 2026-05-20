// lib/screens/indoor_navigation_screen.dart
//
// Indoor navigation experience using:
//   • Live camera feed as fullscreen background (via CameraOverlay).
//   • Directional arrow pointing toward the target plant.
//   • Hot/cold gauge reacting to BLE-derived distance estimate.
//   • QR code scanner for position anchoring.
//
// TODO [Backend Phase 3 / Hardware]: This screen currently uses:
//   - MockWebSocketService (simulated bearing/distance/hotColdScore).
//   - MockBleService (simulated RSSI values).
//   - QR scanner UI is wired up but postQrScan() throws UnimplementedError.
// Replace all Mock* services and enable postQrScan once backend is live.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/navigation_provider.dart';
import '../providers/plant_provider.dart';
import '../widgets/camera_overlay.dart';

class IndoorNavigationScreen extends ConsumerStatefulWidget {
  const IndoorNavigationScreen({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<IndoorNavigationScreen> createState() =>
      _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState
    extends ConsumerState<IndoorNavigationScreen> {
  bool _scannerVisible = false;

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantByIdProvider(widget.plantId));
    final navAsync = ref.watch(navigationStateProvider(widget.plantId));
    final arrowAngle = ref.watch(arrowAngleProvider(widget.plantId));
    // TODO [Backend Phase 3 / Hardware]: Observe bleRssiProvider to display
    // live beacon signal strength debug info or pass to backend trilateration.

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
          // ── Camera + arrow + gauge ─────────────────────────────────────────
          CameraOverlay(
            angleDegrees: arrowAngle,
            hotColdScore: hotColdScore,
            hint: hint,
          ),

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

          // ── QR scan button ─────────────────────────────────────────────────
          // TODO [Backend Phase 3 / Hardware]: QR scanning is visible but
          // postQrScan() will throw UnimplementedError until the endpoint
          // exists. The button is intentionally shown so the flow is testable
          // with a real device once the backend is ready.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _QrButton(
                onPressed: () => setState(() => _scannerVisible = true),
              ),
            ),
          ),

          // ── QR scanner overlay ─────────────────────────────────────────────
          if (_scannerVisible)
            _QrScannerOverlay(
              plantId: widget.plantId,
              onClose: () => setState(() => _scannerVisible = false),
            ),

          // ── Mock data badge ────────────────────────────────────────────────
          // TODO [Backend Phase 3 / Hardware]: Remove this badge in production.
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
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.plantName,
    this.section,
    this.distanceMetres,
  });

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
          const Icon(Icons.home_work_outlined,
              color: Colors.tealAccent, size: 20),
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
                if (section != null)
                  Text(
                    'Section $section',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (distanceMetres != null)
            Text(
              '${distanceMetres!.toStringAsFixed(1)} m',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan section QR'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR scanner overlay
// ─────────────────────────────────────────────────────────────────────────────

class _QrScannerOverlay extends ConsumerStatefulWidget {
  const _QrScannerOverlay({
    required this.plantId,
    required this.onClose,
  });

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
      // TODO [Backend Phase 3 / Hardware]: Remove this snackbar once the
      // endpoint is live; errors will be handled via the provider stream.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR scan not yet available: $e'),
            backgroundColor: Colors.orange,
          ),
        );
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
        // Close button
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
        // Viewfinder hint
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

// ─────────────────────────────────────────────────────────────────────────────
// Mock data badge
// TODO [Backend Phase 3 / Hardware]: Delete this widget before production.
// ─────────────────────────────────────────────────────────────────────────────

class _MockDataBadge extends StatelessWidget {
  const _MockDataBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          letterSpacing: 1,
        ),
      ),
    );
  }
}
