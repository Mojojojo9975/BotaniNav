// lib/providers/navigation_provider.dart
//
// All navigation state management lives here.
// Widgets observe these providers and render accordingly.
// Services are wired up and torn down within provider lifecycle hooks.
//
// Riverpod 3.0 note: StateProvider moved to legacy.dart; targetPlantId
// is now a Notifier.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_state.dart';
import '../services/websocket_service.dart';
import '../services/ble_service.dart';
import '../services/compass_service.dart';
import 'plant_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Session ID — generated at app launch, used for WS channel keying
// ─────────────────────────────────────────────────────────────────────────────

final sessionIdProvider = Provider<String>((ref) {
  // Simple timestamp-based session ID; replace with UUID package if desired.
  return 'session_${DateTime.now().millisecondsSinceEpoch}';
});

// ─────────────────────────────────────────────────────────────────────────────
// Target plant ID — set by the router when a deep link or tile is tapped.
// ─────────────────────────────────────────────────────────────────────────────

class _TargetPlantIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final targetPlantIdProvider =
    NotifierProvider<_TargetPlantIdNotifier, String?>(
  _TargetPlantIdNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// GPS position
// ─────────────────────────────────────────────────────────────────────────────

final gpsPositionProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // emit only when moved ≥ 5 m
    ),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Compass heading
// ─────────────────────────────────────────────────────────────────────────────

final compassServiceProvider = Provider<CompassService>((ref) {
  final svc = CompassService();
  svc.startListening();
  ref.onDispose(svc.dispose);
  return svc;
});

final compassHeadingProvider = StreamProvider<double>((ref) {
  return ref.watch(compassServiceProvider).headingStream;
});

// ─────────────────────────────────────────────────────────────────────────────
// Outdoor route
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the outdoor walking route for [plantId] using the current position.
/// Re-fetches when GPS position changes (debounce via distanceFilter above).
final outdoorRouteProvider =
    FutureProvider.family<OutdoorRoute, String>((ref, plantId) async {
  final api = ref.watch(apiServiceProvider);
  final positionAsync = ref.watch(gpsPositionProvider);

  return positionAsync.when(
    data: (position) => api.getOutdoorRoute(
      plantId: plantId,
      userLat: position.latitude,
      userLng: position.longitude,
    ),
    loading: () => throw const _WaitingForGps(),
    error: (e, _) => throw e,
  );
});

class _WaitingForGps implements Exception {
  const _WaitingForGps();
}

// ─────────────────────────────────────────────────────────────────────────────
// WebSocket navigation state (outdoor — real; indoor — mock for now)
// ─────────────────────────────────────────────────────────────────────────────

final _wsServiceProvider = Provider.family<WebSocketService, String>(
  (ref, plantId) {
    final apiKey = ref.watch(apiKeyProvider);
    final sessionId = ref.watch(sessionIdProvider);
    final svc = WebSocketService(sessionId: sessionId, apiKey: apiKey);
    svc.connect();
    ref.onDispose(svc.dispose);
    return svc;
  },
);

final navigationStateProvider =
    StreamProvider.family<NavigationState, String>((ref, plantId) {
  final plant = ref.watch(plantByIdProvider(plantId));

  if (plant == null) {
    return Stream.value(NavigationState.loading);
  }

  if (plant.isIndoor) {
    // TODO [Backend Phase 3 / Hardware]: Replace MockWebSocketService with
    // WebSocketService once the indoor positioning backend is live.
    final mock = MockWebSocketService();
    mock.connect();
    ref.onDispose(mock.dispose);
    return mock.stateStream;
  }

  return ref.watch(_wsServiceProvider(plantId)).stateStream;
});

// ─────────────────────────────────────────────────────────────────────────────
// Arrow angle — bearing minus compass heading (degrees)
// ─────────────────────────────────────────────────────────────────────────────

/// Computed arrow rotation angle for ArrowPainter.
/// The widget just reads this — all math stays in the provider.
final arrowAngleProvider = Provider.family<double, String>((ref, plantId) {
  final navAsync = ref.watch(navigationStateProvider(plantId));
  final headingAsync = ref.watch(compassHeadingProvider);

  final bearing = navAsync.whenOrNull(data: (s) => s.bearing) ?? 0.0;
  final heading = headingAsync.whenOrNull(data: (h) => h) ?? 0.0;

  return (bearing - heading + 360) % 360;
});

// ─────────────────────────────────────────────────────────────────────────────
// BLE RSSI stream (indoor only)
// ─────────────────────────────────────────────────────────────────────────────

/// TODO [Backend Phase 3 / Hardware]: Switch bleServiceProvider to use
/// BleService (real) instead of MockBleService when hardware is available.
final bleServiceProvider = Provider<MockBleService>((ref) {
  final svc = MockBleService();
  svc.startScanning();
  ref.onDispose(svc.dispose);
  return svc;
});

final bleRssiProvider = StreamProvider<BeaconRssiMap>((ref) {
  return ref.watch(bleServiceProvider).rssiStream;
});