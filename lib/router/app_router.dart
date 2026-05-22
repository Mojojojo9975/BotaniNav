// lib/router/app_router.dart
//
// Defines all named routes and handles the deep link entry point:
//   botanicnav://navigate?plantId=plant_123&apiKey=abc123
//
// On deep link arrival:
//   1. Extracts plantId and apiKey from query parameters.
//   2. Injects apiKey into apiKeyProvider via ProviderScope override.
//   3. Fetches plant data to determine indoor vs outdoor.
//   4. Routes to the appropriate navigation screen.
//
// The router itself is stateless — all state lives in Riverpod providers.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/plant_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/plant_list_screen.dart';
import '../screens/outdoor_navigation_screen.dart';
import '../screens/indoor_navigation_screen.dart';
import '../screens/arrival_screen.dart';
import '../screens/greenhouse_map_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route names — use these constants instead of string literals everywhere.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const plantList = '/';
  static const outdoorNav = '/navigate/outdoor/:plantId';
  static const indoorNav = '/navigate/indoor/:plantId';
  static const arrival = '/arrival/:plantId';
}

// ─────────────────────────────────────────────────────────────────────────────
// Router factory — call once in app.dart and pass to MaterialApp.router
// ─────────────────────────────────────────────────────────────────────────────

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.plantList,

    // ── Deep link scheme registration ────────────────────────────────────────
    // iOS: Add to Info.plist under CFBundleURLSchemes.
    // Android: Add intent-filter in AndroidManifest.xml for botanicnav://.
    // Both platforms then hand the URI to go_router automatically.

    redirect: (BuildContext context, GoRouterState state) async {
      final uri = state.uri;

      // Only intercept our custom scheme deep links.
      if (uri.scheme != 'botanicnav') return null;
      if (uri.host != 'navigate') return null;

      final plantId = uri.queryParameters['plantId'];
      final apiKey = uri.queryParameters['apiKey'];

      if (plantId == null || plantId.isEmpty) {
        debugPrint('Deep link missing plantId — routing to plant list.');
        return AppRoutes.plantList;
      }

      // Inject the API key from the deep link into the provider graph so
      // ApiService picks it up before any network call is made.
      if (apiKey != null && apiKey.isNotEmpty) {
        ref.read(apiKeyProvider.notifier).set(apiKey);
      }

      // Store target plant ID so providers can reference it.
      ref.read(targetPlantIdProvider.notifier).set(plantId);

      // Determine indoor vs outdoor to pick the correct screen.
      // We have to await the plant catalogue here; show a loading redirect
      // and let the screen handle async loading via Riverpod.
      final plant = ref.read(plantByIdProvider(plantId));
      if (plant == null) {
        // Plant list not loaded yet — go to outdoor by default;
        // the screen will re-route once data arrives.
        return '/navigate/outdoor/$plantId';
      }

      return plant.isIndoor
          ? '/navigate/indoor/$plantId'
          : '/navigate/outdoor/$plantId';
    },

    routes: [
      // ── Plant catalogue ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.plantList,
        name: 'plantList',
        builder: (context, state) => const PlantListScreen(),
      ),

      // ── Outdoor navigation ─────────────────────────────────────────────────
      GoRoute(
        path: '/navigate/outdoor/:plantId',
        name: 'outdoorNav',
        builder: (context, state) {
          final plantId = state.pathParameters['plantId']!;
          return OutdoorNavigationScreen(plantId: plantId);
        },
      ),

      // ── Indoor navigation ──────────────────────────────────────────────────
      // TODO [Backend Phase 3 / Hardware]: IndoorNavigationScreen is a
      // placeholder with mock data until BLE + backend positioning is live.
      GoRoute(
        path: '/navigate/indoor/:plantId',
        name: 'indoorNav',
        builder: (context, state) {
          final plantId = state.pathParameters['plantId']!;
          return IndoorNavigationScreen(plantId: plantId);
        },
      ),

      // ── Greenhouse floor plan ──────────────────────────────────────────────
      GoRoute(
        path: '/greenhouse-map',
        name: 'greenhouseMap',
        builder: (context, state) => const GreenhouseMapScreen(),
      ),

      // ── Arrival ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/arrival/:plantId',
        name: 'arrival',
        builder: (context, state) {
          final plantId = state.pathParameters['plantId']!;
          return ArrivalScreen(plantId: plantId);
        },
      ),
    ],

    // ── Error page ────────────────────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Navigation error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.error?.toString() ?? 'Unknown error'),
          ],
        ),
      ),
    ),
  );
}