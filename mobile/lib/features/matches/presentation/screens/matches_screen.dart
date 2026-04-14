import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/match_model.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(liveMatchesProvider);
    final todayAsync = ref.watch(todayMatchesProvider);
    final upcomingAsync = ref.watch(upcomingMatchesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(liveMatchesProvider);
            ref.invalidate(todayMatchesProvider);
            ref.invalidate(upcomingMatchesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    "Matchs",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),

              // Live matches
              liveAsync.when(
                data: (live) {
                  if (live.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return _buildSection("🔴 EN DIRECT", live, AppColors.error);
                },
                loading: () => _buildLoader(),
                error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Today matches
              todayAsync.when(
                data: (today) {
                  if (today.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return _buildSection("📅 AUJOURD'HUI", today, AppColors.info);
                },
                loading: () => _buildLoader(),
                error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Upcoming
              upcomingAsync.when(
                data: (upcoming) {
                  if (upcoming.isEmpty && todayAsync.valueOrNull?.isEmpty == true && liveAsync.valueOrNull?.isEmpty == true) {
                    return SliverFillRemaining(child: _buildEmpty());
                  }
                  if (upcoming.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return _buildSection("⏳ À VENIR", upcoming, AppColors.gold);
                },
                loading: () => _buildLoader(),
                error: (e, st) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Erreur de chargement",
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Match> matches, Color badgeColor) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${matches.length}",
                    style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _MatchTile(match: matches[index]),
              childCount: matches.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text(
            "Aucun match disponible",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tirez vers le bas pour actualiser",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Match match;
  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isFinished = match.status == MatchStatus.finished;
    final timeStr = isLive
        ? match.statusLabel
        : isFinished
            ? "Terminé"
            : DateFormat('HH:mm').format(match.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isLive ? Border.all(color: AppColors.error.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        children: [
          // League + time
          Row(
            children: [
              Expanded(
                child: Text(
                  match.league.name,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                )
              else
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isFinished ? AppColors.textSecondary : AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Teams
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeTeam.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (match.score != null)
                Text(
                  "${match.score!.home}",
                  style: TextStyle(
                    color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.awayTeam.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (match.score != null)
                Text(
                  "${match.score!.away}",
                  style: TextStyle(
                    color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          // Tier badge
          if (match.tier == 1) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "⭐ TOP LEAGUE",
                  style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
