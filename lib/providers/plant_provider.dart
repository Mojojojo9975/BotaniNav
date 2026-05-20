// lib/providers/plant_provider.dart
//
// Riverpod providers for the plant catalogue.
// No business logic lives in widgets — all state lives here.
//
// Riverpod 3.0 note: StateProvider moved to legacy.dart; we use Notifier
// instead throughout this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApiKey — injected at deep-link entry point by the router.
// ─────────────────────────────────────────────────────────────────────────────

class _ApiKeyNotifier extends Notifier<String> {
  @override
  String build() => '';

  // Convenience setter used by app_router.dart.
  void set(String key) => state = key;
}

/// Holds the API key extracted from the incoming deep link.
/// Write via: ref.read(apiKeyProvider.notifier).set('my-key');
final apiKeyProvider = NotifierProvider<_ApiKeyNotifier, String>(
  _ApiKeyNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// ApiService — scoped to the current apiKey value.
// ─────────────────────────────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) {
  final key = ref.watch(apiKeyProvider);
  final service = ApiService(apiKey: key);
  ref.onDispose(service.dispose);
  return service;
});

// ─────────────────────────────────────────────────────────────────────────────
// Plant list
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the full plant catalogue from the backend.
/// Re-fetches automatically when [apiKeyProvider] changes.
final plantsProvider = FutureProvider<List<Plant>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getPlants();
});

/// Find a single plant by ID from the cached list.
/// Returns null if the list hasn't loaded yet or the ID doesn't exist.
final plantByIdProvider = Provider.family<Plant?, String>((ref, plantId) {
  final asyncPlants = ref.watch(plantsProvider);
  return asyncPlants.whenOrNull(
    data: (plants) {
      try {
        return plants.firstWhere((p) => p.id == plantId);
      } catch (_) {
        return null;
      }
    },
  );
});

/// Filtered views — useful for the plant list screen search/filter UI.
final outdoorPlantsProvider = Provider<AsyncValue<List<Plant>>>((ref) {
  return ref.watch(plantsProvider).whenData(
        (plants) => plants.where((p) => !p.isIndoor).toList(),
      );
});

final indoorPlantsProvider = Provider<AsyncValue<List<Plant>>>((ref) {
  return ref.watch(plantsProvider).whenData(
        (plants) => plants.where((p) => p.isIndoor).toList(),
      );
});