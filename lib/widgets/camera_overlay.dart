// lib/widgets/camera_overlay.dart
//
// Composites the live camera preview as a fullscreen background with
// ArrowPainter and HotColdGauge overlaid on top.
//
// The widget owns the CameraController lifecycle. It initialises the first
// available back-facing camera and disposes cleanly on unmount.
//
// Business logic (angle, score, hint) is passed in as parameters — this widget
// is purely presentational.
//
// TODO [Backend Phase 3 / Hardware]: Camera permissions must be declared in
// AndroidManifest.xml and Info.plist before this widget works on device.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'arrow_painter.dart';
import 'hot_cold_gauge.dart';

class CameraOverlay extends StatefulWidget {
  const CameraOverlay({
    super.key,
    required this.angleDegrees,
    required this.hotColdScore,
    this.hint,
  });

  /// Pre-computed arrow rotation angle from [arrowAngleProvider].
  final double angleDegrees;

  /// 0.0 = cold, 1.0 = hot — drives [HotColdGauge].
  final double hotColdScore;

  /// Human-readable navigation hint from the backend.
  final String? hint;

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay> {
  CameraController? _controller;
  bool _initialised = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on device.');
        return;
      }

      // Prefer back camera; fall back to first available.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initialised = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera background ──────────────────────────────────────────────
        if (_initialised && _controller != null)
          CameraPreview(_controller!)
        else if (_errorMessage != null)
          _CameraError(message: _errorMessage!)
        else
          const _CameraLoading(),

        // ── Dark vignette scrim ────────────────────────────────────────────
        const _Scrim(),

        // ── Directional arrow ──────────────────────────────────────────────
        Center(
          child: CustomPaint(
            painter: ArrowPainter(angleDegrees: widget.angleDegrees),
            size: const Size(140, 140),
          ),
        ),

        // ── Hot/cold gauge — pinned to the right edge ──────────────────────
        Positioned(
          right: 24,
          top: 0,
          bottom: 0,
          child: Center(
            child: HotColdGauge(
              score: widget.hotColdScore,
              hint: widget.hint,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.45),
          ],
        ),
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
