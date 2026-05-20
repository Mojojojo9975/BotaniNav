// lib/screens/plant_list_screen.dart
//
// Displays the full plant catalogue fetched from GET /api/v1/plants.
// Users can tap a plant to begin navigation. Tapping triggers the deep-link
// route so that indoor/outdoor routing is handled centrally by app_router.dart.
//
// This screen is the default entry point when the app is opened directly
// (not via a deep link from the partner app).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';

class PlantListScreen extends ConsumerWidget {
  const PlantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D4A2D),
        foregroundColor: Colors.white,
        title: const Text('BotanicNav'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(plantsProvider),
            tooltip: 'Refresh plant list',
          ),
        ],
      ),
      body: plantsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(plantsProvider),
        ),
        data: (plants) => _PlantList(plants: plants),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plant list
// ─────────────────────────────────────────────────────────────────────────────

class _PlantList extends StatelessWidget {
  const _PlantList({required this.plants});
  final List<Plant> plants;

  @override
  Widget build(BuildContext context) {
    if (plants.isEmpty) {
      return const Center(
        child: Text(
          'No plants found.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Group into outdoor and indoor sections.
    final outdoor = plants.where((p) => !p.isIndoor).toList();
    final indoor = plants.where((p) => p.isIndoor).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (outdoor.isNotEmpty) ...[
          _SectionHeader(label: '🌿 Outdoor Plants (${outdoor.length})'),
          ...outdoor.map((p) => _PlantTile(plant: p)),
        ],
        if (indoor.isNotEmpty) ...[
          _SectionHeader(label: '🏡 Greenhouse Plants (${indoor.length})'),
          ...indoor.map((p) => _PlantTile(plant: p)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.plant});
  final Plant plant;

  void _navigate(BuildContext context) {
    final route = plant.isIndoor
        ? '/navigate/indoor/${plant.id}'
        : '/navigate/outdoor/${plant.id}';
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF2D4A2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: plant.isIndoor
              ? Colors.teal.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
          child: Icon(
            plant.isIndoor ? Icons.home_work_outlined : Icons.park_outlined,
            color: plant.isIndoor ? Colors.tealAccent : Colors.greenAccent,
            size: 22,
          ),
        ),
        title: Text(
          plant.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plant.scientificName,
              style: const TextStyle(
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Section ${plant.section}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
        ),
        onTap: () => _navigate(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load plants',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
