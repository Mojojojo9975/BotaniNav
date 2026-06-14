import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_state.dart';
import '../models/trail_route.dart';
import '../services/websocket_service.dart';
import '../services/compass_service.dart';
import 'plant_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Session ID
// ─────────────────────────────────────────────────────────────────────────────

final sessionIdProvider = Provider<String>((ref) =>
    'session_${DateTime.now().millisecondsSinceEpoch}');

// ─────────────────────────────────────────────────────────────────────────────
// Target plant ID
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
      distanceFilter: 5,
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
// WebSocket navigation state
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
  return ref.watch(_wsServiceProvider(plantId)).stateStream;
});

// ─────────────────────────────────────────────────────────────────────────────
// Arrow angle — bearing minus compass heading
// ─────────────────────────────────────────────────────────────────────────────

final arrowAngleProvider = Provider.family<double, String>((ref, plantId) {
  final navAsync = ref.watch(navigationStateProvider(plantId));
  final headingAsync = ref.watch(compassHeadingProvider);

  final bearing = navAsync.whenOrNull(data: (s) => s.bearing) ?? 0.0;
  final heading = headingAsync.whenOrNull(data: (h) => h) ?? 0.0;

  return (bearing - heading + 360) % 360;
});

// ─────────────────────────────────────────────────────────────────────────────
// Trail route — fetched once when TrailNavigationScreen opens
// ─────────────────────────────────────────────────────────────────────────────

/// Key type for the trail providers — a joined string of plant IDs so Riverpod
/// can cache per unique trail combination.
typedef TrailKey = String;

String trailKey(List<String> plantIds) => plantIds.join(',');

final trailRouteProvider =
    FutureProvider.family<TrailRoute, TrailKey>((ref, key) async {
  final api = ref.watch(apiServiceProvider);
  final plantIds = key.split(',');
  final position = await ref.read(gpsPositionProvider.future);
  return api.getTrailRoute(
    plantIds: plantIds,
    userLat: position.latitude,
    userLng: position.longitude,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Trail WebSocket — connects once, sends plant list to backend on open
// ─────────────────────────────────────────────────────────────────────────────

final _trailWsServiceProvider =
    Provider.family<WebSocketService, TrailKey>((ref, key) {
  final apiKey = ref.watch(apiKeyProvider);
  final sessionId = '${ref.watch(sessionIdProvider)}_trail';
  final svc = WebSocketService(sessionId: sessionId, apiKey: apiKey);

  // Connect, then immediately tell the backend this is a trail session
  // by sending the ordered plant ID list.
  svc.connect();
  svc.send({'trail': key.split(',')});

  ref.onDispose(svc.dispose);
  return svc;
});

final trailNavigationStateProvider =
    StreamProvider.family<NavigationState, TrailKey>((ref, key) {
  return ref.watch(_trailWsServiceProvider(key)).stateStream;
});

/// Current leg index from the backend WS waypoint_index field.
final currentTrailLegIndexProvider =
    Provider.family<int, TrailKey>((ref, key) {
  final navAsync = ref.watch(trailNavigationStateProvider(key));
  return navAsync.whenOrNull(data: (s) => s.waypointIndex) ?? 0;
});

/// Arrow angle for the current trail leg.
final trailArrowAngleProvider =
    Provider.family<double, TrailKey>((ref, key) {
  final navAsync = ref.watch(trailNavigationStateProvider(key));
  final headingAsync = ref.watch(compassHeadingProvider);

  final bearing = navAsync.whenOrNull(data: (s) => s.bearing) ?? 0.0;
  final heading = headingAsync.whenOrNull(data: (h) => h) ?? 0.0;

  return (bearing - heading + 360) % 360;
});