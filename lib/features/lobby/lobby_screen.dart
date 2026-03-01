import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/enums/puzzle_mode.dart';
import '../../core/enums/difficulty.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_system.dart';
import '../auth/auth_screen.dart';
import '../game/ai/ai_personality.dart';
import '../game/game_screen.dart';
import '../matchmaking/matchmaking_screen.dart';

import 'data/auth_repository.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  static const String routePath = '/lobby';
  static const String routeName = 'lobby';

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (mounted) context.goNamed(AuthScreen.routeName);
  }

  Future<void> _startVsAI() async {
    int gridSize = 3;
    Difficulty difficulty = Difficulty.normal;
    AIPersonality personality = AIPersonality.calm;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚙️ Configurar partida', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Tamaño: ${gridSize}x$gridSize', style: const TextStyle(color: AppColors.textGray)),
            SliderTheme(
              data: SliderThemeData(activeTrackColor: AppColors.neonCyan, thumbColor: AppColors.neonCyan, inactiveTrackColor: AppColors.bgCardLight),
              child: Slider(value: gridSize.toDouble(), min: 3, max: 8, divisions: 5,
                onChanged: (v) => setDialogState(() => gridSize = v.toInt())),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Difficulty>(
              value: difficulty,
              dropdownColor: AppColors.bgCard,
              decoration: InputDecoration(
                labelText: 'Dificultad IA',
                labelStyle: const TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textGray.withOpacity(0.3))),
              ),
              items: Difficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()))).toList(),
              onChanged: (v) { if (v != null) setDialogState(() => difficulty = v); },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textGray))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {'gridSize': gridSize, 'difficulty': difficulty, 'personality': personality}),
              style: FilledButton.styleFrom(backgroundColor: AppColors.neonCyan, foregroundColor: AppColors.bgDark),
              child: const Text('¡Jugar!'),
            ),
          ],
        );
      }),
    );
    if (result == null || !mounted) return;
    context.goNamed(GameScreen.routeName, extra: {
      'roomId': 'ai_${DateTime.now().millisecondsSinceEpoch}', 'mode': PuzzleMode.vsAI,
      'gridSize': result['gridSize'], 'aiDifficulty': result['difficulty'], 'aiPersonality': result['personality'],
    });
  }

  Future<void> _startLocal() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    int gridSize = 4;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('📸 Tamaño del puzzle', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${gridSize}x$gridSize (${gridSize * gridSize} piezas)', style: const TextStyle(color: AppColors.textGray)),
            SliderTheme(
              data: SliderThemeData(activeTrackColor: AppColors.neonCyan, thumbColor: AppColors.neonCyan, inactiveTrackColor: AppColors.bgCardLight),
              child: Slider(value: gridSize.toDouble(), min: 3, max: 8, divisions: 5,
                onChanged: (v) => setDialogState(() => gridSize = v.toInt())),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textGray))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, gridSize),
              style: FilledButton.styleFrom(backgroundColor: AppColors.neonCyan, foregroundColor: AppColors.bgDark),
              child: const Text('¡Armar!'),
            ),
          ],
        );
      }),
    );
    if (result == null || !mounted) return;
    context.goNamed(GameScreen.routeName, extra: {
      'roomId': 'local_${DateTime.now().millisecondsSinceEpoch}', 'mode': PuzzleMode.local,
      'gridSize': result, 'galleryImageBytes': bytes,
    });
  }

  void _startOnlineMode(PuzzleMode mode) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Inicia sesión con Google para jugar online'),
          backgroundColor: AppColors.neonPink, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
    context.goNamed(MatchmakingScreen.routeName, extra: {'mode': mode});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final String greeting = user?.displayName ?? 'Jugador';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), AppColors.bgDark]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 12),
              // Top bar
              Row(children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.neonCyan.withOpacity(0.2),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? const Icon(Icons.person, color: AppColors.neonCyan, size: 22) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hola, $greeting 👋', style: context.textTheme.titleMedium),
                    Text('¿Listo para competir?', style: context.textTheme.bodySmall),
                  ]),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppColors.textGray, size: 20),
                  ),
                  onPressed: _signOut,
                ),
              ]),
              const SizedBox(height: 24),
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppColors.neonCyan, AppColors.neonPurple]).createShader(bounds),
                child: Text('🧩 PieceRacer', textAlign: TextAlign.center,
                  style: context.textTheme.displayLarge?.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: 24),
              // Mode cards
              Expanded(
                child: ListView(children: [
                  _ModeCard(icon: Icons.smart_toy_outlined, title: '1 vs IA', subtitle: 'Compite contra la máquina',
                    gradient: [AppColors.neonPurple, const Color(0xFF6C3AED)], onTap: _startVsAI),
                  const SizedBox(height: 12),
                  _ModeCard(icon: Icons.photo_library_outlined, title: 'Local', subtitle: 'Tu foto → tu puzzle',
                    gradient: [AppColors.neonGreen, const Color(0xFF059669)], onTap: _startLocal),
                  const SizedBox(height: 12),
                  _ModeCard(icon: Icons.flash_on, title: '1 vs 1', subtitle: 'Rival online en tiempo real',
                    gradient: [AppColors.neonOrange, const Color(0xFFDC2626)], onTap: () => _startOnlineMode(PuzzleMode.oneVsOne)),
                  const SizedBox(height: 12),
                  _ModeCard(icon: Icons.groups_outlined, title: '2 vs 2', subtitle: 'Armen el puzzle en equipo',
                    gradient: [AppColors.neonCyan, const Color(0xFF2563EB)], onTap: () => _startOnlineMode(PuzzleMode.twoVsTwo)),
                  const SizedBox(height: 12),
                  _ModeCard(icon: Icons.celebration_outlined, title: 'Amigos', subtitle: '3-4 jugadores, primero gana',
                    gradient: [AppColors.neonPink, const Color(0xFFBE185D)], onTap: () => _startOnlineMode(PuzzleMode.friends)),
                  const SizedBox(height: 20),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [gradient[0].withOpacity(0.15), gradient[1].withOpacity(0.08)],
            ),
            border: Border.all(color: gradient[0].withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: context.textTheme.bodySmall),
            ])),
            Icon(Icons.arrow_forward_ios, color: gradient[0].withOpacity(0.5), size: 16),
          ]),
        ),
      ),
    );
  }
}
