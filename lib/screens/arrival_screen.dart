// lib/screens/arrival_screen.dart
//
// Shown when navigationState.arrived == true.
// Displays plant details and provides a "Done" button that can return
// control to the partner app (via the deep link return mechanism,
// or simply pop to the plant list as a fallback).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/plant_provider.dart';

class ArrivalScreen extends ConsumerWidget {
  const ArrivalScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = ref.watch(plantByIdProvider(plantId));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Arrival icon ─────────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: const Icon(
                  Icons.eco,
                  size: 60,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 32),

              // ── Arrived text ─────────────────────────────────────────────
              const Text(
                "You've arrived! 🌿",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // ── Plant info ───────────────────────────────────────────────
              if (plant != null) ...[
                Text(
                  plant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  plant.scientificName,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Section ${plant.section}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                if (plant.description != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    plant.description!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 48),

              // ── Done button ───────────────────────────────────────────────
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
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
