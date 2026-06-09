// lib/app.dart
//
// Root widget. Wires up:
//   • MaterialApp.router (go_router)
//   • App theme (botanical dark green palette)
//   • ProviderScope is set up in main.dart, NOT here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';

class BotanicNavApp extends ConsumerWidget {
  const BotanicNavApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter(ref);

    return MaterialApp.router(
      title: 'BotanicNav',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _buildTheme(),
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF4CAF50);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF69F0AE),    // greenAccent[200]
        secondary: const Color(0xFF40E0D0),  // tealAccent
        surface: const Color(0xFF1A2E1A),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1F0D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2E1A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2E1A),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF69F0AE),
          foregroundColor: Colors.black87,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        bodyLarge: TextStyle(color: Colors.white),
      ),
    );
  }
}