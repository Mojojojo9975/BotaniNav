// lib/config/env.dart
//
// Single source of truth for all environment-sourced configuration.
// Loaded once at app startup via flutter_dotenv.
// Access values via Env.someKey — never read dotenv directly in other files.

import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  // ── Backend ────────────────────────────────────────────────────────────────
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  static Uri get apiBase => Uri.parse(apiBaseUrl);

  // ── Google Maps ────────────────────────────────────────────────────────────
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Anthropic ──────────────────────────────────────────────────────────────
  /// Used by VisionService to call the Claude API for treasure hunt photo checks.
  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  // ── BLE Beacon UUIDs ───────────────────────────────────────────────────────
  // TODO [Backend Phase 3 / Hardware]: Replace with real provisioned UUIDs.
  static String get beaconUuidGreenhouseA =>
      dotenv.env['BEACON_UUID_GREENHOUSE_A'] ??
      '00000000-0000-0000-0000-000000000001';

  static String get beaconUuidGreenhouseB =>
      dotenv.env['BEACON_UUID_GREENHOUSE_B'] ??
      '00000000-0000-0000-0000-000000000002';

  static List<String> get beaconUuids => [
        beaconUuidGreenhouseA,
        beaconUuidGreenhouseB,
      ];
}