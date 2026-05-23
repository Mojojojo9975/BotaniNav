// lib/screens/hunt_camera_screen.dart
//
// Camera capture + vision check screen for the treasure hunt.
// Flow: take photo → preview → submit → show result → next or retry.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/treasure_hunt.dart';
import '../providers/treasure_hunt_provider.dart';

class HuntCameraScreen extends ConsumerStatefulWidget {
  const HuntCameraScreen({super.key});

  @override
  ConsumerState<HuntCameraScreen> createState() => _HuntCameraScreenState();
}

class _HuntCameraScreenState extends ConsumerState<HuntCameraScreen> {
  File? _photo;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Reset any previous result when opening the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visionCheckProvider.notifier).reset();
    });
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_photo == null) return;
    await ref.read(visionCheckProvider.notifier).check(_photo!);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(huntSessionProvider);
    final checkAsync = ref.watch(visionCheckProvider);

    if (session == null) {
      context.go('/treasure-hunt');
      return const SizedBox.shrink();
    }

    final plant = session.currentPlant;
    final hint = plant.hintFor(session.difficulty);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => context.go('/treasure-hunt'),
                  ),
                  Expanded(
                    child: Text(
                      'Take a photo of the plant',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  _DifficultyChip(difficulty: session.difficulty),
                ],
              ),
            ),

            // ── Hint reminder ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(hint,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Photo area ───────────────────────────────────────────────────
            Expanded(
              child: checkAsync.when(
                data: (result) => result != null
                    ? _ResultOverlay(
                        photo: _photo!,
                        result: result,
                        session: session,
                        onRetry: () {
                          ref.read(visionCheckProvider.notifier).reset();
                          setState(() => _photo = null);
                        },
                        onNext: () => context.go('/treasure-hunt'),
                      )
                    : _PhotoArea(
                        photo: _photo,
                        onTakePhoto: _takePhoto,
                      ),
                loading: () => _LoadingOverlay(photo: _photo),
                error: (e, _) => _ErrorView(
                  error: e.toString(),
                  onRetry: () {
                    ref.read(visionCheckProvider.notifier).reset();
                  },
                ),
              ),
            ),

            // ── Submit button ────────────────────────────────────────────────
            if (_photo != null &&
                checkAsync.whenOrNull(data: (r) => r) == null &&
                !checkAsync.isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Check with AI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo area
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.photo, required this.onTakePhoto});
  final File? photo;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return GestureDetector(
        onTap: onTakePhoto,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.greenAccent.withOpacity(0.3),
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: Colors.greenAccent.withOpacity(0.6), size: 64),
              const SizedBox(height: 16),
              const Text('Tap to open camera',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Point at the plant and take a clear photo',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(
              image: FileImage(photo!),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 32,
          child: TextButton.icon(
            onPressed: onTakePhoto,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retake'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black54,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({this.photo});
  final File? photo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (photo != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                  image: FileImage(photo!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5), BlendMode.darken)),
            ),
          ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 16),
              Text('AI is checking your photo…',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              SizedBox(height: 6),
              Text('This takes a few seconds',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.photo,
    required this.result,
    required this.session,
    required this.onRetry,
    required this.onNext,
  });

  final File photo;
  final HuntResult result;
  final HuntSession session;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isMatch = result.matched;
    final color = isMatch ? Colors.greenAccent : Colors.redAccent;
    final icon = isMatch ? Icons.check_circle : Icons.cancel_outlined;
    final title = isMatch ? 'That\'s the one! ✓' : 'Not quite…';

    return Column(
      children: [
        // Photo with result tint
        Expanded(
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: FileImage(photo),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      (isMatch ? Colors.green : Colors.red).withOpacity(0.15),
                      BlendMode.overlay,
                    ),
                  ),
                ),
              ),
              // Badge
              Positioned(
                top: 16,
                right: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.black87, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${(result.confidence * 100).toStringAsFixed(0)}% match',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Result card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Text(result.explanation,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isMatch)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRetry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Try again'),
                      ),
                    ),
                  if (!isMatch) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isMatch ? Colors.greenAccent : Colors.white24,
                        foregroundColor:
                            isMatch ? Colors.black87 : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        isMatch
                            ? (session.currentIndex >= session.total
                                ? 'See results'
                                : 'Next plant →')
                            : 'Skip',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text('Vision check failed',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});
  final HuntDifficulty difficulty;

  static const _colors = {
    HuntDifficulty.easy: Color(0xFF4CAF50),
    HuntDifficulty.medium: Color(0xFFFF9800),
    HuntDifficulty.hard: Color(0xFFE53935),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[difficulty]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(difficulty.label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
