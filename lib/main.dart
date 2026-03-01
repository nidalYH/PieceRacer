import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_typography.dart';
import 'router.dart';
import 'services/firebase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: await resolveFirebaseOptions(),
  );

  runApp(
    const ProviderScope(
      child: PieceRacerApp(),
    ),
  );
}

class PieceRacerApp extends ConsumerWidget {
  const PieceRacerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Puzzle Speed',
      debugShowCheckedModeBanner: false,
      theme: AppTypography.theme,
      darkTheme: AppTypography.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

