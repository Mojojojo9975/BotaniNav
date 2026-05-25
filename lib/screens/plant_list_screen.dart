// lib/screens/plant_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';

class PlantListScreen extends ConsumerWidget {
  const PlantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _HeroHeader()),

          // ── Refresh action bar ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Plants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white38),
                    onPressed: () => ref.invalidate(plantsProvider),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ),

          // ── Plant list / loading / error ─────────────────────────────────────
          plantsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(plantsProvider),
              ),
            ),
            data: (plants) => _PlantListSliver(plants: plants),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header — logo + welcome message
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B0D), Color(0xFF1A3D1A), Color(0xFF0D2420)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo mark ────────────────────────────────────────────────────
              Row(
                children: [
                  _LogoMark(),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
<<<<<<< HEAD
                    children: const [
                      Text(
=======
                    children: [
                      const Text(
>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5
                        'BotanicNav',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
<<<<<<< HEAD
                      Text(
=======
                      const Text(
>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5
                        'Botanical Garden Guide',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Welcome message ───────────────────────────────────────────────
              const Text(
                'Welcome to the garden.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore thousands of species at your own pace. '
                'Tap any plant below and we\'ll guide you straight to it — '
                'outdoors on the map, or deep inside the greenhouse.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 24),

              // ── Stat chips ────────────────────────────────────────────────────
              const Row(
                children: [
                  _StatChip(icon: Icons.park_outlined, label: 'Outdoor trails'),
                  SizedBox(width: 10),
                  _StatChip(icon: Icons.home_work_outlined, label: 'Greenhouses'),
                  SizedBox(width: 10),
                  _StatChip(icon: Icons.near_me_outlined, label: 'Live guidance'),
                ],
              ),

              const SizedBox(height: 20),

              // ── Greenhouse map button ─────────────────────────────────────────
              _GreenhouseMapButton(),
<<<<<<< HEAD
=======

              const SizedBox(height: 10),

              // ── Treasure hunt button ──────────────────────────────────────────
              _TreasureHuntButton(),
>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo mark — SVG-style leaf drawn with Canvas
// ─────────────────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF00BFA5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(painter: _LeafPainter()),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    // Draw a stylised leaf shape
    final path = Path();
    path.moveTo(cx, cy - 16);
    path.cubicTo(cx + 14, cy - 10, cx + 14, cy + 8, cx, cy + 16);
    path.cubicTo(cx - 14, cy + 8, cx - 14, cy - 10, cx, cy - 16);
    canvas.drawPath(path, paint);

    // Centre vein
    final veinPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 13), Offset(cx, cy + 14), veinPaint);

    // Side veins
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx + 8, cy + 2), veinPaint);
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx - 8, cy + 2), veinPaint);
    canvas.drawLine(Offset(cx, cy + 4), Offset(cx + 7, cy + 9), veinPaint);
    canvas.drawLine(Offset(cx, cy + 4), Offset(cx - 7, cy + 9), veinPaint);
  }

  @override
  bool shouldRepaint(_LeafPainter _) => false;
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.greenAccent, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenhouseMapButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.go('/greenhouse-map'),
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('View Greenhouse Floor Plan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.greenAccent,
          side: const BorderSide(color: Colors.greenAccent, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }
}

<<<<<<< HEAD
=======
class _TreasureHuntButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.go('/treasure-hunt'),
        icon: const Text('🌿', style: TextStyle(fontSize: 16)),
        label: const Text('Treasure Hunt'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.greenAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
              color: Colors.greenAccent.withOpacity(0.4), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }
}

>>>>>>> 1bb466ce91c7732671b0c0712adf7d6204bfc6f5
// ─────────────────────────────────────────────────────────────────────────────
// Plant list sliver
// ─────────────────────────────────────────────────────────────────────────────

class _PlantListSliver extends StatelessWidget {
  const _PlantListSliver({required this.plants});
  final List<Plant> plants;

  @override
  Widget build(BuildContext context) {
    if (plants.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No plants found.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final outdoor = plants.where((p) => !p.isIndoor).toList();
    final indoor = plants.where((p) => p.isIndoor).toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        if (outdoor.isNotEmpty) ...[
          _SectionHeader(label: '🌿 Outdoor Plants (${outdoor.length})'),
          ...outdoor.map((p) => _PlantTile(plant: p)),
        ],
        if (indoor.isNotEmpty) ...[
          _SectionHeader(label: '🏡 Greenhouse Plants (${indoor.length})'),
          ...indoor.map((p) => _PlantTile(plant: p)),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.plant});
  final Plant plant;

  void _navigate(BuildContext context) {
    final route = plant.isIndoor
        ? '/navigate/indoor/${plant.id}'
        : '/navigate/outdoor/${plant.id}';
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF1A2E1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: plant.isIndoor
              ? Colors.teal.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
          child: Icon(
            plant.isIndoor ? Icons.home_work_outlined : Icons.park_outlined,
            color: plant.isIndoor ? Colors.tealAccent : Colors.greenAccent,
            size: 22,
          ),
        ),
        title: Text(
          plant.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plant.scientificName,
              style: const TextStyle(
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Section ${plant.section}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => _navigate(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load plants',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}