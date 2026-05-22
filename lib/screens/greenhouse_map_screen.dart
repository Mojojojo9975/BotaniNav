// lib/screens/greenhouse_map_screen.dart
//
// Standalone floor plan viewer — shows all GeoJSON layers without starting
// navigation for any specific plant. Accessible from the landing page.

import 'package:flutter/material.dart';
import '../widgets/indoor_map_widget.dart';

class GreenhouseMapScreen extends StatelessWidget {
  const GreenhouseMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1A0D),
        foregroundColor: Colors.white,
        title: const Text('Greenhouse Floor Plan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _Legend(color: const Color(0xFF1E3A1E), label: 'Areas'),
                const SizedBox(width: 10),
                _Legend(color: const Color(0xFF4CAF50), label: 'Walls'),
                const SizedBox(width: 10),
                _Legend(color: Colors.greenAccent, label: 'Sections'),
              ],
            ),
          ),
        ],
      ),
      body: const IndoorMapWidget(),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
