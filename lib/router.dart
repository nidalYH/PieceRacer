import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/enums/puzzle_mode.dart';
import 'features/auth/auth_screen.dart';
import 'features/game/game_screen.dart';
import 'features/lobby/lobby_screen.dart';
import 'features/matchmaking/matchmaking_screen.dart';
import 'features/results/results_screen.dart';
import 'core/enums/difficulty.dart';
import 'features/game/ai/ai_personality.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // If already signed in → go to lobby, else → auth screen
    initialLocation: FirebaseAuth.instance.currentUser != null
        ? LobbyScreen.routePath
        : AuthScreen.routePath,
    routes: <RouteBase>[
      GoRoute(
        path: AuthScreen.routePath,
        name: AuthScreen.routeName,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: LobbyScreen.routePath,
        name: LobbyScreen.routeName,
        builder: (context, state) => const LobbyScreen(),
      ),
      GoRoute(
        path: MatchmakingScreen.routePath,
        name: MatchmakingScreen.routeName,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final mode = extra?['mode'] as PuzzleMode? ?? PuzzleMode.local;
          return MatchmakingScreen(mode: mode);
        },
      ),
      GoRoute(
        path: GameScreen.routePath,
        name: GameScreen.routeName,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return GameScreen(
              roomId: extra['roomId'] as String? ?? 'offline',
              mode: extra['mode'] as PuzzleMode? ?? PuzzleMode.local,
              gridSize: extra['gridSize'] as int? ?? 3,
              aiDifficulty: extra['aiDifficulty'] as Difficulty?,
              aiPersonality: extra['aiPersonality'] as AIPersonality?,
              galleryImageBytes: extra['galleryImageBytes'] as Uint8List?,
            );
          }
          return const GameScreen(roomId: 'offline', mode: PuzzleMode.local);
        },
      ),
      GoRoute(
        path: ResultsScreen.routePath,
        name: ResultsScreen.routeName,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ResultsScreen(
            roomId: extra?['roomId'] as String? ?? '',
            myUid: extra?['myUid'] as String? ?? '',
            mode: extra?['mode'] as PuzzleMode?,
          );
        },
      ),
    ],
  );
});
