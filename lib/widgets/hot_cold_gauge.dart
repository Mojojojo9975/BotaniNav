// lib/widgets/hot_cold_gauge.dart
//
// Renders a vertical temperature gauge bar.
//   score == 0.0 → freezing blue
//   score == 0.5 → neutral green
//   score == 1.0 → burning red
//
// Smooth colour interpolation is done via HSV to avoid the muddy mid-range
// that RGB lerp produces.
//
// Usage:
//   HotColdGauge(score: hotColdScore, hint: hint)

import 'package:flutter/material.dart';

class HotColdGauge extends StatelessWidget {
  const HotColdGauge({
    super.key,
    required this.score,
    this.hint,
    this.height = 180,
    this.width = 28,
  }) : assert(score >= 0.0 && score <= 1.0, 'score must be in [0.0, 1.0]');

  /// 0.0 = coldest, 1.0 = hottest.
  final double score;

  /// Optional text hint from the backend (e.g. "Getting warmer").
  final String? hint;

  final double height;
  final double width;

  /// Maps score → colour via HSV hue rotation.
  /// Hue 240° = blue (cold), 120° = green, 0° = red (hot).
  static Color _scoreToColor(double score) {
    final hue = (1.0 - score) * 240.0; // 240 → 0
    return HSVColor.fromAHSV(1.0, hue, 0.85, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final fillColor = _scoreToColor(score);
    final emptyColor = Colors.white.withAlpha((0.15 * 255).round());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Temperature emoji ────────────────────────────────────────────────
        Text(
          score >= 0.7
              ? '🔥'
              : score >= 0.4
                  ? '🌡'
                  : '❄️',
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 6),

        // ── Gauge bar ────────────────────────────────────────────────────────
        SizedBox(
          height: height,
          width: width,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Track (empty)
              Container(
                decoration: BoxDecoration(
                  color: emptyColor,
                  borderRadius: BorderRadius.circular(width / 2),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
              // Fill (animated)
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                heightFactor: score.clamp(0.03, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(width / 2),
                    boxShadow: [
                      BoxShadow(
                        color: fillColor.withAlpha((0.55 * 255).round()),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Hint label ───────────────────────────────────────────────────────
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ],
    );
  }
}
