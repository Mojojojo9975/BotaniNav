// lib/models/treasure_hunt.dart

import 'dart:convert';
import 'package:flutter/services.dart';

enum HuntDifficulty { easy, medium, hard }

extension HuntDifficultyLabel on HuntDifficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
  String get description => switch (this) {
        HuntDifficulty.easy   => 'Section hints included. Great for beginners.',
        HuntDifficulty.medium => 'No section given. Use your knowledge.',
        HuntDifficulty.hard   => 'Scientific clues only. Expert mode.',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// HuntPlant — one entry from assets/hunt/plants.json
// ─────────────────────────────────────────────────────────────────────────────

class HuntPlant {
  const HuntPlant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.section,
    required this.imageDescription,
    required this.hints,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final String section;

  /// True visual description used by the vision LLM to judge a photo.
  final String imageDescription;

  /// Hints keyed by difficulty name.
  final Map<String, String> hints;

  String hintFor(HuntDifficulty difficulty) =>
      hints[difficulty.name] ?? hints['easy'] ?? '';

  factory HuntPlant.fromJson(Map<String, dynamic> json) => HuntPlant(
        id: json['id'] as String,
        commonName: json['common_name'] as String,
        scientificName: json['scientific_name'] as String,
        section: json['section'] as String,
        imageDescription: json['image_description'] as String,
        hints: Map<String, String>.from(json['hints'] as Map),
      );

  /// Load and shuffle all plants from the asset bundle.
  static Future<List<HuntPlant>> loadAll() async {
    final raw = await rootBundle.loadString('assets/hunt/plants.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['plants'] as List)
        .map((e) => HuntPlant.fromJson(e as Map<String, dynamic>))
        .toList();
    list.shuffle();
    return list;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HuntResult — outcome of one plant photo check
// ─────────────────────────────────────────────────────────────────────────────

class HuntResult {
  const HuntResult({
    required this.plantId,
    required this.matched,
    required this.confidence,
    required this.explanation,
  });

  final String plantId;
  final bool matched;
  final double confidence;
  final String explanation;

  factory HuntResult.fromJson(Map<String, dynamic> json, String plantId) =>
      HuntResult(
        plantId: plantId,
        matched: json['matched'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        explanation: json['explanation'] as String,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HuntSession — full game state
// ─────────────────────────────────────────────────────────────────────────────

class HuntSession {
  HuntSession({
    required this.plants,
    required this.difficulty,
    Map<String, HuntResult>? results,
    this.currentIndex = 0,
  }) : results = results ?? {};

  final List<HuntPlant> plants;
  final HuntDifficulty difficulty;
  final Map<String, HuntResult> results; // plantId → result
  final int currentIndex;

  HuntPlant get currentPlant => plants[currentIndex];
  bool get isComplete => currentIndex >= plants.length;
  int get score => results.values.where((r) => r.matched).length;
  int get total => plants.length;

  HuntSession copyWith({
    int? currentIndex,
    Map<String, HuntResult>? results,
  }) =>
      HuntSession(
        plants: plants,
        difficulty: difficulty,
        results: results ?? Map.from(this.results),
        currentIndex: currentIndex ?? this.currentIndex,
      );
}
