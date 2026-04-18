import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/league_utils.dart';
import '../../../../core/widgets/access_gate.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../predictions/domain/combo_prediction_model.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/today_match_model.dart';
import '../../../predictions/domain/match_model.dart';
import '../../../matches/presentation/widgets/match_detail_sheet.dart';
import '../../../matches/presentation/widgets/combo_card.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../widgets/stats_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(activeMatchesProvider);
    final allMatchesAsync = ref.watch(todayEligibleMatchesProvider);
    final combosAsync = ref.watch(todayCombosProvider);
    final profile = ref.watch(userProfileProvider);
    final userProfile = profile.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(todayEligibleMatchesProvider);
            ref.invalidate(todayCombosProvider);
            ref.invalidate(monthlyStatsProvider);
            ref.invalidate(userProfileProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(userProfile?.username)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: StatsCard(),
                ),
              ),
              matchesAsync.when(
                data: (activeMatches) {
                  final finishedCount = allMatchesAsync.whenOrNull(
                    data: (all) => all.where((m) => m.isEffectivelyFinished).length,
                  ) ?? 0;
                  return _buildContent(context, activeMatches, finishedCount);
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  ),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Impossible de charger les matchs",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.toString(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(todayEligibleMatchesProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("R\u00e9essayer"),
                          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Combos section
              combosAsync.when(
                data: (combos) {
                  if (combos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return _buildCombosSection(context, combos, userProfile);
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<TodayMatch> allMatches, int finishedCount) {
    final liveMatches = allMatches.where((m) => m.isLive).toList();
    final withPredictions = allMatches.where((m) => m.hasOfficialPredictions && !m.isLive).toList();
    final upcoming = allMatches
        .where((m) => !m.isLive && !m.hasOfficialPredictions)
        .toList()
      ..sort((a, b) => a.match.dateTime.compareTo(b.match.dateTime));
    final upcomingSoon = upcoming.take(5).toList();

    return SliverMainAxisGroup(
      slivers: [
        // Summary bar -> Matches tab
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: () => context.go('/matches'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.sports_soccer_rounded, color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text("${allMatches.length} matchs \u00e0 venir", style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    ),
                    if (finishedCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text("$finishedCount termin\u00e9s", style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ],
                    if (liveMatches.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text("${liveMatches.length} LIVE", style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Text("Voir tout", style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ),

        // LIVE section
        if (liveMatches.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader("\ud83d\udd34 EN DIRECT", "${liveMatches.length}", AppColors.error),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _HomeMatchCard(todayMatch: liveMatches[i]),
                childCount: liveMatches.length,
              ),
            ),
          ),
        ],

        // Predictions available section (max 10)
        if (withPredictions.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader("\ud83c\udfaf PRONOS DISPONIBLES", "${withPredictions.length}", AppColors.emerald),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _HomeMatchCard(todayMatch: withPredictions[i]),
                childCount: withPredictions.length > 10 ? 10 : withPredictions.length,
              ),
            ),
          ),
          if (withPredictions.length > 10)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: () => context.go('/matches'),
                  child: Text("+${withPredictions.length - 10} autres \u2192 Voir tout", style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                ),
              ),
            ),
        ],

        // Upcoming soon (next 5 without predictions yet)
        if (upcomingSoon.isNotEmpty && liveMatches.isEmpty && withPredictions.isEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader("\u23f3 PROCHAINS MATCHS", "${upcomingSoon.length}", AppColors.info),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _HomeMatchCard(todayMatch: upcomingSoon[i]),
                childCount: upcomingSoon.length,
              ),
            ),
          ),
        ] else if (upcomingSoon.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader("\u23f3 BIENT\u00d4T", "${upcomingSoon.length}", AppColors.textSecondary),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _HomeMatchCard(todayMatch: upcomingSoon[i], compact: true),
                childCount: upcomingSoon.length,
              ),
            ),
          ),
        ],

        // Empty state (no live, no predictions, no upcoming)
        if (allMatches.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState()),
      ],
    );
  }

  Widget _sectionHeader(String title, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(count, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? username) {
    final greeting = username != null ? "Salut $username \ud83d\udc4b" : "Bonjour \ud83d\udc4b";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'Q', style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w800)),
                    TextSpan(text: 'uantara', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.sports_soccer_rounded, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 16),
          const Text(
            "Aucun match \u00e9ligible pour le moment",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Les pronos arrivent ~1h avant chaque match.\nConsultez l'onglet Matchs pour les rencontres du jour.",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  SliverMainAxisGroup _buildCombosSection(BuildContext context, List<ComboPrediction> combos, UserProfile? profile) {
    final hasComboAccess = profile?.hasComboAccess ?? false;
    final comboLimit = profile?.comboLimit ?? 0;
    final isPro = profile?.isPro ?? false;
    final isVip = profile?.isVip ?? false;

    // Split into safe/bold
    final safeCombos = combos.where((c) => c.isSafe).toList();
    final boldCombos = combos.where((c) => c.isBold).toList();

    // Apply combo limits: PRO sees 1 total, VIP sees 3 total
    // PRO: 1 safe combo only (no bold)
    // VIP: up to 3 (safe + bold)
    int safeVisible = safeCombos.length;
    int boldVisible = boldCombos.length;

    if (hasComboAccess && comboLimit > 0) {
      if (isPro && !isVip) {
        // Pro: 1 combo total, safe only
        safeVisible = safeVisible.clamp(0, 1);
        boldVisible = 0;
      } else if (isVip) {
        // VIP: 3 total, distribute between safe & bold
        safeVisible = safeVisible.clamp(0, comboLimit);
        final remaining = comboLimit - safeVisible;
        boldVisible = boldVisible.clamp(0, remaining);
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _sectionHeader("🎰 COMBINÉS DU JOUR", "${combos.length}", const Color(0xFFD4AF37)),
        ),
        if (safeCombos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    "🛡️ Combinés Sûrs · ${safeCombos.length}",
                    style: TextStyle(
                      color: const Color(0xFF00C896).withAlpha(200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasComboAccess && comboLimit > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$safeVisible visible${safeVisible > 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: safeCombos.length,
                itemBuilder: (_, i) {
                  final isWithinLimit = i < safeVisible && hasComboAccess;
                  return ComboCard(
                    combo: safeCombos[i],
                    isLocked: !isWithinLimit || safeCombos[i].isLocked,
                    onUpgradeTap: () => context.go('/subscription'),
                  );
                },
              ),
            ),
          ),
        ],
        if (boldCombos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    "🔥 Combinés Audacieux · ${boldCombos.length}",
                    style: TextStyle(
                      color: const Color(0xFFFF6B35).withAlpha(200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isVip) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: boldCombos.length,
                itemBuilder: (_, i) {
                  final isWithinLimit = i < boldVisible && isVip;
                  return ComboCard(
                    combo: boldCombos[i],
                    isLocked: !isWithinLimit || boldCombos[i].isLocked,
                    onUpgradeTap: () => context.go('/subscription'),
                  );
                },
              ),
            ),
          ),
        ],
        if (!hasComboAccess)
          SliverToBoxAdapter(
            child: UpgradeBanner(
              requiredPlan: 'pro',
              text: 'Débloquez les combinés avec Pro ou VIP',
            ),
          ),
      ],
    );
  }
}

// Home match card 

class _HomeMatchCard extends StatelessWidget {
  final TodayMatch todayMatch;
  final bool compact;
  const _HomeMatchCard({required this.todayMatch, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final match = todayMatch.match;
    final isLive = match.status == MatchStatus.live;
    final timeStr = isLive
        ? match.statusLabel
        : DateFormat('HH:mm').format(match.dateTime.toLocal());
    // Only show official predictions on cards (tendances visible only on match detail)
    final officialPreds = todayMatch.officialPredictions;
    final bestPred = todayMatch.bestTopPick ?? (officialPreds.isNotEmpty
        ? officialPreds.reduce((a, b) => (a.confidence ?? 0) >= (b.confidence ?? 0) ? a : b)
        : null);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MatchDetailSheet(todayMatch: todayMatch),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(compact ? 12.0 : 14.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isLive ? Border.all(color: AppColors.error.withValues(alpha: 0.35)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // League + time
            Row(
              children: [
                Text(LeagueUtils.flag(match.league.name), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(match.league.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(timeStr, style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  )
                else
                  Text(timeStr, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            // Teams + score
            Row(
              children: [
                Expanded(
                  child: Text("${match.homeTeam.name}  vs  ${match.awayTeam.name}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (match.score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                    child: Text("${match.score!.home} - ${match.score!.away}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              // Best prediction or status
              if (bestPred != null && !bestPred.isLocked)
                Row(
                  children: [
                    const Text("⭐", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(bestPred.typeIcon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      bestPred.eventLabelWith(home: match.homeTeam.name, away: match.awayTeam.name),
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                    )),
                    if (bestPred.isRefined) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                        child: const Text("Affiné", style: TextStyle(color: AppColors.info, fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text("${bestPred.confidencePercent}%", style: TextStyle(color: _confidenceColor(bestPred.confidence ?? 0), fontSize: 12, fontWeight: FontWeight.w700)),
                    if (officialPreds.length > 1) ...[
                      const SizedBox(width: 6),
                      Text("+${officialPreds.length - 1}", style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 10)),
                    ],
                  ],
                )
              else if (bestPred != null && bestPred.isLocked)
                Row(children: [
                  const Icon(Icons.lock_rounded, color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  const Text("Premium", style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                ])
              else
                _buildStatusHint(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHint() {
    final status = todayMatch.predictionStatus;
    String label;
    Color color;

    switch (status) {
      case 'generating':
        label = "G\u00e9n\u00e9ration en cours...";
        color = AppColors.gold;
      case 'pending_live':
        label = "Analyse live en cours";
        color = AppColors.warning;
      case 'waiting_lineups':
        label = "Attente compositions ${todayMatch.waitLabel}";
        color = AppColors.info;
      default:
        label = "Pronos ~1h avant le match";
        color = AppColors.textSecondary;
    }

    return Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11));
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.92) return AppColors.emerald;
    if (confidence >= 0.85) return AppColors.success;
    if (confidence >= 0.80) return AppColors.gold;
    return AppColors.warning;
  }
}
