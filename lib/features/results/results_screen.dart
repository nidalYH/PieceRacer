import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_system.dart';
import '../../core/utils/time_utils.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/jigsaw_primary_button.dart';
import '../lobby/lobby_screen.dart';
import '../matchmaking/matchmaking_screen.dart';

import '../game/data/room_repository.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({
    required this.roomId,
    required this.myUid,
    super.key,
  });

  static const String routePath = '/results';
  static const String routeName = 'results';

  final String roomId;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomRepo = ref.watch(roomRepositoryProvider);
    
    return Scaffold(
      backgroundColor: context.colors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: roomRepo.watchRoom(roomId),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.error,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }
          final DocumentSnapshot<Map<String, dynamic>> doc = snapshot.data!;
          if (!doc.exists) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('La sala ya no existe.'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      context.goNamed(LobbyScreen.routeName);
                    },
                    child: const Text('Volver al lobby'),
                  ),
                ],
              ),
            );
          }
          final Map<String, dynamic> data =
              doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
          final List<dynamic> resultsDynamic =
              data['results'] as List<dynamic>? ?? <dynamic>[];
          Map<String, dynamic>? myResult;
          Map<String, dynamic>? opponentResult;
          for (final dynamic item in resultsDynamic) {
            if (item is Map<String, dynamic>) {
              final String uid = item['uid'] as String? ?? '';
              if (uid == myUid) {
                myResult = item;
              } else {
                opponentResult = item;
              }
            } else if (item is Map) {
              final Map<String, dynamic> mapItem = Map<String, dynamic>.from(
                item as Map<dynamic, dynamic>,
              );
              final String uid = mapItem['uid'] as String? ?? '';
              if (uid == myUid) {
                myResult = mapItem;
              } else {
                opponentResult = mapItem;
              }
            }
          }
          final num? myTimeNum = myResult?['time'] as num?;
          final num? opponentTimeNum = opponentResult?['time'] as num?;
          final int? myTimeSeconds =
              myTimeNum != null ? myTimeNum.toInt() : null;
          final int? opponentTimeSeconds =
              opponentTimeNum != null ? opponentTimeNum.toInt() : null;

          bool didWin = false;
          if (myTimeSeconds != null && opponentTimeSeconds != null) {
            didWin = myTimeSeconds <= opponentTimeSeconds;
          }

          final List<dynamic> playersDynamic =
              data['players'] as List<dynamic>? ?? <dynamic>[];
          final List<String> players =
              List<String>.from(playersDynamic.map((dynamic e) => e.toString()));
          final String opponentUid = players.firstWhere(
            (String id) => id != myUid,
            orElse: () => '',
          );

          final String titleText = didWin ? '🏆 VICTORIA' : '💀 DERROTA';
          final Color titleColor = didWin ? AppColors.success : context.colors.error;

          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: context.textTheme.displayLarge?.copyWith(
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (myTimeSeconds != null)
                        Text(
                          'Tiempo: ${TimeUtils.formatSeconds(myTimeSeconds)}',
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      if (myTimeSeconds != null)
                        Text(
                          'Precisión: ${(100 - (myTimeSeconds / 10)).clamp(50, 100).toInt()}%',
                          style: context.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Tú   ',
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ..._buildPiecesRow(context, 5),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Rival',
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ..._buildPiecesRow(context, 3),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (opponentUid.isNotEmpty && opponentTimeSeconds != null)
                        FutureBuilder<String>(
                          future: fetchDisplayName(opponentUid),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<String> nameSnapshot,
                          ) {
                            final String opponentName =
                                nameSnapshot.data ?? 'Oponente';
                            return Text(
                              'vs $opponentName: '
                              '${TimeUtils.formatSeconds(opponentTimeSeconds)}',
                              style: context.textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        
                      const SizedBox(height: AppSpacing.xl),
                      const _RewardsRow(),
                      const SizedBox(height: AppSpacing.xl),
                      JigsawPrimaryButton(
                        label: '🔁 REVANCHA (15s)',
                        onPressed: () {
                          context.goNamed(MatchmakingScreen.routeName);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () {
                          context.goNamed(LobbyScreen.routeName);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: const Text('Volver al menú inicial'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPiecesRow(BuildContext context, int filled) {
    return List<Widget>.generate(5, (int index) {
      final bool isFilled = index < filled;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          Icons.extension,
          size: 20,
          color: isFilled
              ? AppColors.success
              : AppColors.textSecondary.withOpacity(0.2),
        ),
      );
    });
  }
}

class _RewardsRow extends StatelessWidget {
  const _RewardsRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 24, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '+ 1 Rango',
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 24, color: context.colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '+ 120 XP',
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

