// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env bundled as a Flutter asset.
  await dotenv.load(fileName: '.env');

  // Request all permissions the app needs upfront.
  await _requestPermissions();

  runApp(
    const ProviderScope(
      child: BotanicNavApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  await [
    Permission.location,
    Permission.locationWhenInUse,
    Permission.camera,
    Permission.photos,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();
}
