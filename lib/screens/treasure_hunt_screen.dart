// lib/screens/treasure_hunt_screen.dart
//
// Entry point for the treasure hunt. Shows:
//   • Difficulty picker (if no active session)
//   • Active game progress with plant hints and tick/cross per plant

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/treasure_hunt.dart';
import '../providers/treasure_hunt_provider.dart';

class TreasureHuntScreen extends ConsumerWidget {
  const TreasureHuntScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(huntSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: session == null
          ? _DifficultyPicker()
          : _ActiveHunt(session: session),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty picker
// ─────────────────────────────────────────────────────────────────────────────

class _DifficultyPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(huntPlantPoolProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => context.go('/'),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Title
            const Text('🌿  Treasure Hunt',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Follow the clues, find the plants, snap a photo — '
              'the AI will judge if you found the right one.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),

            const Text('Choose difficulty',
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
            const SizedBox(height: 16),

            // Difficulty cards
            ...HuntDifficulty.values.map((d) => _DifficultyCard(
                  difficulty: d,
                  onStart: poolAsync.whenOrNull(
                    data: (pool) => () {
                      ref.read(huntSessionProvider.notifier).startGame(
                            difficulty: d,
                            pool: pool,
                            count: 5,
                          );
                    },
                  ),
                )),

            if (poolAsync.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({required this.difficulty, this.onStart});
  final HuntDifficulty difficulty;
  final VoidCallback? onStart;

  static const _icons = {
    HuntDifficulty.easy: Icons.sentiment_satisfied_alt,
    HuntDifficulty.medium: Icons.psychology_outlined,
    HuntDifficulty.hard: Icons.science_outlined,
  };

  static const _colors = {
    HuntDifficulty.easy: Color(0xFF4CAF50),
    HuntDifficulty.medium: Color(0xFFFF9800),
    HuntDifficulty.hard: Color(0xFFE53935),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[difficulty]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                  ),
                  child: Icon(_icons[difficulty], color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(difficulty.label,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(difficulty.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active hunt — hint + progress list
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveHunt extends ConsumerWidget {
  const _ActiveHunt({required this.session});
  final HuntSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.isComplete) {
      return _CompletionView(session: session);
    }

    return SafeArea(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    ref.read(huntSessionProvider.notifier).abandonGame();
                  },
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                const Text('Treasure Hunt',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const Spacer(),
                _DifficultyBadge(difficulty: session.difficulty),
              ],
            ),
          ),

          // ── Progress bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _ProgressBar(session: session),
          ),

          // ── Current plant hint ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _CurrentHintCard(session: session),
                  const SizedBox(height: 20),
                  _PlantChecklist(session: session),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Find it button ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.go('/treasure-hunt/camera'),
                icon: const Icon(Icons.camera_alt),
                label: const Text("I found it — take photo"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
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
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.session});
  final HuntSession session;

  @override
  Widget build(BuildContext context) {
    final progress = session.currentIndex / session.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Plant ${session.currentIndex + 1} of ${session.total}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${session.score} found ✓',
                style: const TextStyle(
                    color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}

class _CurrentHintCard extends StatelessWidget {
  const _CurrentHintCard({required this.session});
  final HuntSession session;

  @override
  Widget build(BuildContext context) {
    final plant = session.currentPlant;
    final hint = plant.hintFor(session.difficulty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3D1A), Color(0xFF0D2420)],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              const Text('Your clue',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 14),
          Text(hint,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.map_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(
                session.difficulty == HuntDifficulty.easy
                    ? 'Check the section labels on the indoor map'
                    : 'Use the indoor map to explore',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlantChecklist extends StatelessWidget {
  const _PlantChecklist({required this.session});
  final HuntSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Progress',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...session.plants.asMap().entries.map((entry) {
          final i = entry.key;
          final plant = entry.value;
          final result = session.results[plant.id];
          final isCurrent = i == session.currentIndex;
          final isPast = i < session.currentIndex;

          return _ChecklistRow(
            plant: plant,
            result: result,
            isCurrent: isCurrent,
            isPast: isPast,
            index: i,
          );
        }),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.plant,
    required this.result,
    required this.isCurrent,
    required this.isPast,
    required this.index,
  });

  final HuntPlant plant;
  final HuntResult? result;
  final bool isCurrent;
  final bool isPast;
  final int index;

  @override
  Widget build(BuildContext context) {
    final matched = result?.matched ?? false;

    Color borderColor = Colors.white12;
    Color textColor = Colors.white38;
    Widget indicator;

    if (isCurrent) {
      borderColor = Colors.greenAccent.withOpacity(0.5);
      textColor = Colors.white;
      indicator = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.greenAccent, width: 2),
        ),
        child: Center(
          child: Text('${index + 1}',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      );
    } else if (matched) {
      borderColor = Colors.green.withOpacity(0.3);
      textColor = Colors.white70;
      indicator = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2E7D32),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isPast && !matched) {
      indicator = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.3),
        ),
        child:
            const Icon(Icons.close, color: Colors.redAccent, size: 16),
      );
    } else {
      indicator = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text('${index + 1}',
              style: const TextStyle(
                  color: Colors.white24, fontSize: 12)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.greenAccent.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          indicator,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent || isPast ? plant.commonName : '???',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14),
                ),
                if ((isCurrent || isPast) && result?.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(result!.explanation,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});
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
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion screen
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionView extends ConsumerWidget {
  const _CompletionView({required this.session});
  final HuntSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPerfect = session.score == session.total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isPerfect ? '🏆' : '🌿',
                style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              isPerfect ? 'Perfect Score!' : 'Hunt Complete!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'You found ${session.score} out of ${session.total} plants',
              style:
                  const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${session.difficulty.label} difficulty',
              style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 14),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                ref.read(huntSessionProvider.notifier).abandonGame();
                ref.read(visionCheckProvider.notifier).reset();
              },
              icon: const Icon(Icons.replay),
              label: const Text('Play again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black87,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(huntSessionProvider.notifier).abandonGame();
                ref.read(visionCheckProvider.notifier).reset();
                context.go('/');
              },
              child: const Text('Back to garden',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
