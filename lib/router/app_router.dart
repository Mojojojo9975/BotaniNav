// lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/plant_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/plant_list_screen.dart';
import '../screens/outdoor_navigation_screen.dart';
import '../screens/arrival_screen.dart';
import '../screens/greenhouse_map_screen.dart';
<<<<<<< HEAD

// ─────────────────────────────────────────────────────────────────────────────
// Route names — use these constants instead of string literals everywhere.
// ─────────────────────────────────────────────────────────────────────────────
=======
import '../screens/treasure_hunt_screen.dart';
import '../screens/hunt_camera_screen.dart';
>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5

abstract final class AppRoutes {
  static const plantList    = '/';
  static const outdoorNav   = '/navigate/outdoor/:plantId';
  static const indoorNav    = '/navigate/indoor/:plantId';
  static const arrival      = '/arrival/:plantId';
  static const greenhouseMap = '/greenhouse-map';
  static const treasureHunt  = '/treasure-hunt';
  static const huntCamera    = '/treasure-hunt/camera';
}

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.plantList,

    redirect: (BuildContext context, GoRouterState state) async {
      final uri = state.uri;
      if (uri.scheme != 'botanicnav') return null;
      if (uri.host != 'navigate') return null;

      final plantId = uri.queryParameters['plantId'];
      final apiKey  = uri.queryParameters['apiKey'];

      if (plantId == null || plantId.isEmpty) return AppRoutes.plantList;

      if (apiKey != null && apiKey.isNotEmpty) {
        ref.read(apiKeyProvider.notifier).set(apiKey);
      }
      ref.read(targetPlantIdProvider.notifier).set(plantId);

      final plant = ref.read(plantByIdProvider(plantId));
      if (plant == null) return '/navigate/outdoor/$plantId';
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

      // ── Indoor navigation → greenhouse floor plan ──────────────────────────
      GoRoute(
        path: '/navigate/indoor/:plantId',
        name: 'indoorNav',
        builder: (context, state) {
          final plantId = state.pathParameters['plantId']!;
          return GreenhouseMapScreen(plantId: plantId);
        },
      ),

<<<<<<< HEAD
      // ── Greenhouse floor plan ──────────────────────────────────────────────
      GoRoute(
        path: '/greenhouse-map',
=======
      // ── Greenhouse floor plan (browse) ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.greenhouseMap,
>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5
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

      // ── Treasure Hunt ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.treasureHunt,
        name: 'treasureHunt',
        builder: (context, state) => const TreasureHuntScreen(),
      ),
      GoRoute(
        path: AppRoutes.huntCamera,
        name: 'huntCamera',
        builder: (context, state) => const HuntCameraScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Navigation error',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(state.error?.toString() ?? 'Unknown error'),
          ],
        ),
      ),
    ),
  );
}