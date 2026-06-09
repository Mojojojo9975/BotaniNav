// lib/providers/treasure_hunt_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/treasure_hunt.dart';
import '../services/vision_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Plant pool — loaded once from assets
// ─────────────────────────────────────────────────────────────────────────────

final huntPlantPoolProvider = FutureProvider<List<HuntPlant>>((ref) async {
  return HuntPlant.loadAll();
});

// ─────────────────────────────────────────────────────────────────────────────
// Active game session
// ─────────────────────────────────────────────────────────────────────────────

class HuntSessionNotifier extends Notifier<HuntSession?> {
  @override
  HuntSession? build() => null;

  /// Start a new game — randomly picks [count] plants from the pool.
  void startGame({
    required HuntDifficulty difficulty,
    required List<HuntPlant> pool,
    int count = 5,
  }) {
    final shuffled = List<HuntPlant>.from(pool)..shuffle();
    state = HuntSession(
      plants: shuffled.take(count).toList(),
      difficulty: difficulty,
    );
  }

  void abandonGame() => state = null;

  void _updateSession(HuntSession updated) => state = updated;
}

final huntSessionProvider =
    NotifierProvider<HuntSessionNotifier, HuntSession?>(
  HuntSessionNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Vision check — async, keyed by plant ID
// ─────────────────────────────────────────────────────────────────────────────

/// Call this to submit a photo for the current plant.
/// Updates the session state with the result and advances the index on match.
class VisionCheckNotifier extends AsyncNotifier<HuntResult?> {
  @override
  Future<HuntResult?> build() async => null;

  Future<void> check(File imageFile) async {
    final session = ref.read(huntSessionProvider);
    if (session == null || session.isComplete) return;

    state = const AsyncLoading();

    try {
      final result = await VisionService.checkPlant(
        imageFile: imageFile,
        plant: session.currentPlant,
        difficulty: session.difficulty,
      );

      // Store result.
      final updatedResults = Map<String, HuntResult>.from(session.results)
        ..[session.currentPlant.id] = result;

      // Advance to next plant if matched.
      final nextIndex =
          result.matched ? session.currentIndex + 1 : session.currentIndex;

      ref.read(huntSessionProvider.notifier)._updateSession(
            session.copyWith(
              results: updatedResults,
              currentIndex: nextIndex,
            ),
          );

      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = const AsyncData(null);
}

final visionCheckProvider =
    AsyncNotifierProvider<VisionCheckNotifier, HuntResult?>(
  VisionCheckNotifier.new,
);
