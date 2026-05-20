// lib/main.dart
//
// Entry point. Responsibilities:
//   1. Load .env via flutter_dotenv before any widget renders.
//   2. Wrap the widget tree in ProviderScope (required by Riverpod).
//   3. Hand off to BotanicNavApp.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env bundled as a Flutter asset (declared in pubspec.yaml).
  await dotenv.load(fileName: '.env');

  runApp(
    const ProviderScope(
      child: BotanicNavApp(),
    ),
  );
}
