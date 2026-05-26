// lib/screens/hunt_camera_screen.dart
//
// Camera capture + vision check for the treasure hunt.
// On result: animated fullscreen overlay pops up —
//   ✓ Match   → green burst + confetti-style particles → auto-advances after 2.5s
//   ✗ No match → red shake animation → retry / skip options

import 'dart:io';
import 'dart:math' as math;
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
  bool _showResultOverlay = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
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
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_photo == null) return;
    await ref.read(visionCheckProvider.notifier).check(_photo!);
    if (mounted) setState(() => _showResultOverlay = true);
  }

  void _dismissAndRetry() {
    ref.read(visionCheckProvider.notifier).reset();
    setState(() {
      _photo = null;
      _showResultOverlay = false;
    });
  }

  void _dismissAndNext() {
    ref.read(visionCheckProvider.notifier).reset();
    setState(() => _showResultOverlay = false);
    context.go('/treasure-hunt');
  }

  void _dismissAndSkip() {
    ref.read(visionCheckProvider.notifier).reset();
    setState(() => _showResultOverlay = false);
    context.go('/treasure-hunt');
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
    final result = checkAsync.whenOrNull(data: (r) => r);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Main camera UI ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                        onPressed: () => context.go('/treasure-hunt'),
                      ),
                      const Expanded(
                        child: Text(
                          'Take a photo of the plant',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      _DifficultyChip(difficulty: session.difficulty),
                    ],
                  ),
                ),

                // Hint card
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

                // Photo area / loading
                Expanded(
                  child: checkAsync.isLoading
                      ? _LoadingOverlay(photo: _photo)
                      : checkAsync.hasError
                          ? _ErrorView(
                              error: checkAsync.error.toString(),
                              onRetry: () {
                                ref
                                    .read(visionCheckProvider.notifier)
                                    .reset();
                              },
                            )
                          : _PhotoArea(
                              photo: _photo,
                              onTakePhoto: _takePhoto,
                            ),
                ),

                // Submit button
                if (_photo != null && !checkAsync.isLoading && result == null)
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Animated result overlay ───────────────────────────────────────
          if (_showResultOverlay && result != null)
            result.matched
                ? _SuccessOverlay(
                    result: result,
                    session: session,
                    onDone: _dismissAndNext,
                  )
                : _FailureOverlay(
                    result: result,
                    onRetry: _dismissAndRetry,
                    onSkip: _dismissAndSkip,
                  ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success overlay — green burst + floating particles + auto-advance
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay({
    required this.result,
    required this.session,
    required this.onDone,
  });
  final HuntResult result;
  final HuntSession session;
  final VoidCallback onDone;

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _iconController;
  late final AnimationController _textController;
  late final AnimationController _particleController;

  late final Animation<double> _bgAnim;
  late final Animation<double> _iconScaleAnim;
  late final Animation<double> _iconRotateAnim;
  late final Animation<double> _textAnim;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _iconController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _particleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);
    _iconScaleAnim = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40),
    ]).animate(_iconController);
    _iconRotateAnim = Tween(begin: -0.2, end: 0.0)
        .animate(CurvedAnimation(
            parent: _iconController, curve: Curves.elasticOut));
    _textAnim =
        CurvedAnimation(parent: _textController, curve: Curves.easeOut);

    // Stagger the animations
    _bgController.forward();
    Future.delayed(const Duration(milliseconds: 150),
        () => _iconController.forward());
    Future.delayed(const Duration(milliseconds: 400),
        () => _textController.forward());
    Future.delayed(const Duration(milliseconds: 200),
        () => _particleController.forward());

    // Auto-advance after 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _iconController.dispose();
    _textController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.session.currentIndex >= widget.session.total;
    final confidence =
        (widget.result.confidence * 100).toStringAsFixed(0);

    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (_, __) => Opacity(
        opacity: _bgAnim.value,
        child: Container(
          color: const Color(0xFF0D2E0D).withOpacity(0.97),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Floating particles
              AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) => CustomPaint(
                  painter: _ParticlePainter(
                      progress: _particleController.value),
                ),
              ),

              // Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated check icon
                      AnimatedBuilder(
                        animation: _iconController,
                        builder: (_, __) => Transform.rotate(
                          angle: _iconRotateAnim.value,
                          child: Transform.scale(
                            scale: _iconScaleAnim.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.greenAccent.withOpacity(0.2),
                                border: Border.all(
                                    color: Colors.greenAccent, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.greenAccent.withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.greenAccent, size: 60),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Text content
                      FadeTransition(
                        opacity: _textAnim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(_textAnim),
                          child: Column(
                            children: [
                              const Text(
                                "That's it! 🌿",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.greenAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.greenAccent
                                          .withOpacity(0.4)),
                                ),
                                child: Text(
                                  '$confidence% match',
                                  style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.result.explanation,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                isLast
                                    ? 'Hunt complete!'
                                    : 'Moving to next plant…',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              // Progress dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.session.total,
                                  (i) => Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    width: i < widget.session.currentIndex
                                        ? 10
                                        : 8,
                                    height: i < widget.session.currentIndex
                                        ? 10
                                        : 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < widget.session.currentIndex
                                          ? Colors.greenAccent
                                          : Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
// Particle painter — floating leaf/dot particles for success
// ─────────────────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});
  final double progress;

  static final _rng = math.Random(42);
  static final _particles = List.generate(24, (i) => [
    _rng.nextDouble(), // x start (0–1)
    _rng.nextDouble(), // y start (0–1)
    _rng.nextDouble() * 0.4 + 0.1, // size
    _rng.nextDouble() * 2 - 1, // x drift
    _rng.nextDouble(), // delay (0–1)
    _rng.nextInt(4).toDouble(), // shape
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final delay = p[4];
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = p[0] * size.width + p[2] * size.width * t;
      final y = p[1] * size.height - t * size.height * 0.6;
      final sz = p[2] * 12 + 4;
      final opacity = (1 - t) * 0.8;

      final paint = Paint()
        ..color = [
          Colors.greenAccent,
          Colors.green,
          Colors.lightGreenAccent,
          Colors.tealAccent,
        ][p[5].toInt()].withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * p[3]);

      if (p[5] < 2) {
        canvas.drawCircle(Offset.zero, sz / 2, paint);
      } else {
        final path = Path()
          ..moveTo(0, -sz / 2)
          ..cubicTo(sz / 2, -sz / 4, sz / 2, sz / 4, 0, sz / 2)
          ..cubicTo(-sz / 2, sz / 4, -sz / 2, -sz / 4, 0, -sz / 2);
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Failure overlay — shake animation + red X
// ─────────────────────────────────────────────────────────────────────────────

class _FailureOverlay extends StatefulWidget {
  const _FailureOverlay({
    required this.result,
    required this.onRetry,
    required this.onSkip,
  });
  final HuntResult result;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  State<_FailureOverlay> createState() => _FailureOverlayState();
}

class _FailureOverlayState extends State<_FailureOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _shakeController;
  late final AnimationController _textController;

  late final Animation<double> _bgAnim;
  late final Animation<double> _shakeAnim;
  late final Animation<double> _textAnim;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -16.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -16.0, end: 16.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 16.0, end: -10.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(
        parent: _shakeController, curve: Curves.easeInOut));
    _textAnim =
        CurvedAnimation(parent: _textController, curve: Curves.easeOut);

    _bgController.forward();
    Future.delayed(
        const Duration(milliseconds: 100), () => _shakeController.forward());
    Future.delayed(
        const Duration(milliseconds: 400), () => _textController.forward());
  }

  @override
  void dispose() {
    _bgController.dispose();
    _shakeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confidence =
        (widget.result.confidence * 100).toStringAsFixed(0);

    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (_, __) => Opacity(
        opacity: _bgAnim.value,
        child: Container(
          color: const Color(0xFF1A0000).withOpacity(0.95),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shaking X icon
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.15),
                          border:
                              Border.all(color: Colors.redAccent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.redAccent, size: 60),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Text + buttons
                  FadeTransition(
                    opacity: _textAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textAnim),
                      child: Column(
                        children: [
                          const Text(
                            'Not quite… 🔍',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.4)),
                            ),
                            child: Text(
                              '$confidence% match',
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.result.explanation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5),
                          ),
                          const SizedBox(height: 36),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onSkip,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white54,
                                    side: const BorderSide(
                                        color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(32)),
                                  ),
                                  child: const Text('Skip'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: widget.onRetry,
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Try again'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(32)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
// Error view
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty chip
// ─────────────────────────────────────────────────────────────────────────────

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