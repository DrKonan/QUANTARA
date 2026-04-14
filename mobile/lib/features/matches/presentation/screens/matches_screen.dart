import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/league_utils.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/today_match_model.dart';
import '../../../predictions/domain/match_model.dart';
import '../widgets/match_detail_sheet.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> with SingleTickerProviderStateMixin {
  String _search = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeMatchesProvider);
    final finishedAsync = ref.watch(finishedMatchesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(todayEligibleMatchesProvider),
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Matchs du jour",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat("EEEE d MMMM yyyy", "fr_FR").format(DateTime.now()),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Rechercher une \u00e9quipe ou comp\u00e9tition...",
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              // Tab bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: AppColors.gold,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: "\u00c0 venir ${_tabCount(activeAsync)}"),
                        Tab(text: "Termin\u00e9s ${_tabCount(finishedAsync)}"),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMatchList(activeAsync, isFinished: false),
                _buildMatchList(finishedAsync, isFinished: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tabCount(AsyncValue<List<TodayMatch>> async) {
    return async.whenOrNull(data: (list) => "(${list.length})") ?? "";
  }

  Widget _buildMatchList(AsyncValue<List<TodayMatch>> matchesAsync, {required bool isFinished}) {
    return matchesAsync.when(
      data: (allMatches) {
        final filtered = _search.isEmpty
            ? allMatches
            : allMatches.where((m) {
                final q = _search;
                return m.match.homeTeam.name.toLowerCase().contains(q) ||
                    m.match.awayTeam.name.toLowerCase().contains(q) ||
                    m.match.league.name.toLowerCase().contains(q) ||
                    m.match.league.country.toLowerCase().contains(q);
              }).toList();

        if (filtered.isEmpty && _search.isNotEmpty) return _buildNoResults();
        if (filtered.isEmpty) {
          return isFinished ? _buildEmptyFinished() : _buildEmpty();
        }

        final live = filtered.where((m) => m.isLive).length;
        final withPred = filtered.where((m) => m.hasPredictions).length;
        final groups = _groupByCategoryCountryLeague(filtered);

        return CustomScrollView(
          slivers: [
            // Summary badges
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _badge("${filtered.length} matchs", AppColors.textSecondary),
                    if (live > 0) _badge("$live LIVE", AppColors.error),
                    if (withPred > 0) _badge("$withPred pronos", AppColors.emerald),
                    if (isFinished) ...[
                      _badge(
                        "${filtered.where((m) => m.predictions.any((p) => p.isCorrect == true)).length} \u2705",
                        AppColors.success,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Category → Country → League → Matches
            ...groups.expand((cat) => [
              SliverToBoxAdapter(child: _CategoryHeader(group: cat)),
              ...cat.countries.expand((country) => [
                SliverToBoxAdapter(child: _CountryHeader(group: country)),
                ...country.leagues.expand((league) => [
                  SliverToBoxAdapter(child: _LeagueSubHeader(league: league)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _MatchTile(todayMatch: league.matches[i]),
                        childCount: league.matches.length,
                      ),
                    ),
                  ),
                ]),
              ]),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 40),
              const SizedBox(height: 12),
              const Text("Erreur de chargement", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(todayEligibleMatchesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("R\u00e9essayer"),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Grouping: Category → Country → League ──

  static const _categoryOrder = {
    'major_international': 0,
    'top5': 1,
    'europe': 2,
    'south_america': 3,
    'rest_of_world': 4,
    'other': 5,
  };

  static const _categoryLabels = {
    'major_international': '\ud83c\udfc6 Comp\u00e9titions internationales',
    'top5': '\u2b50 Top 5 europ\u00e9en',
    'europe': '\ud83c\uddea\ud83c\uddfa Europe',
    'south_america': '\ud83c\udf0e Am\u00e9rique du Sud',
    'rest_of_world': '\ud83c\udf0d Reste du monde',
    'other': '\u26bd Autres',
  };

  List<_CategoryGroup> _groupByCategoryCountryLeague(List<TodayMatch> matches) {
    // Sort all matches: LIVE first, then by soonest kickoff
    final sorted = List<TodayMatch>.from(matches)
      ..sort((a, b) {
        final aLive = a.isLive ? 0 : 1;
        final bLive = b.isLive ? 0 : 1;
        if (aLive != bLive) return aLive.compareTo(bLive);
        return a.match.dateTime.compareTo(b.match.dateTime);
      });

    // Category → Country → League → Matches
    final catMap = <String, Map<String, Map<String, List<TodayMatch>>>>{};

    for (final m in sorted) {
      final cat = m.category.isNotEmpty ? m.category : 'other';
      final country = m.match.league.country.isNotEmpty ? m.match.league.country : 'Autres';
      final league = m.match.league.name;

      catMap.putIfAbsent(cat, () => {});
      catMap[cat]!.putIfAbsent(country, () => {});
      catMap[cat]![country]!.putIfAbsent(league, () => []);
      catMap[cat]![country]![league]!.add(m);
    }

    final groups = catMap.entries.map((catEntry) {
      final countries = catEntry.value.entries.map((countryEntry) {
        final leagues = countryEntry.value.entries.map((leagueEntry) {
          return _LeagueGroup(
            leagueName: leagueEntry.key,
            tier: leagueEntry.value.first.match.tier,
            matches: leagueEntry.value,
          );
        }).toList()
          ..sort((a, b) {
            // Leagues with live matches first, then by soonest kickoff
            if (a.liveCount != b.liveCount) return b.liveCount.compareTo(a.liveCount);
            return a.matches.first.match.dateTime.compareTo(b.matches.first.match.dateTime);
          });

        return _CountryGroup(
          country: countryEntry.key,
          flag: LeagueUtils.countryFlag(countryEntry.key),
          displayName: LeagueUtils.countryDisplayName(countryEntry.key),
          leagues: leagues,
        );
      }).toList()
        ..sort((a, b) {
          // Countries with live matches first, then alphabetical
          if (a.liveCount != b.liveCount) return b.liveCount.compareTo(a.liveCount);
          return a.displayName.compareTo(b.displayName);
        });

      return _CategoryGroup(
        category: catEntry.key,
        label: _categoryLabels[catEntry.key] ?? '\u26bd ${catEntry.key}',
        order: _categoryOrder[catEntry.key] ?? 5,
        countries: countries,
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return groups;
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text("Aucun match \u00e0 venir", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          const Text("Tirez vers le bas pour actualiser", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyFinished() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_score_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text("Aucun match termin\u00e9 aujourd'hui", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text("Aucun r\u00e9sultat pour \"$_search\"", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Data classes ──

class _CategoryGroup {
  final String category;
  final String label;
  final int order;
  final List<_CountryGroup> countries;

  _CategoryGroup({required this.category, required this.label, required this.order, required this.countries});

  int get totalMatches => countries.fold(0, (sum, c) => sum + c.totalMatches);
}

class _CountryGroup {
  final String country;
  final String flag;
  final String displayName;
  final List<_LeagueGroup> leagues;

  _CountryGroup({required this.country, required this.flag, required this.displayName, required this.leagues});

  int get totalMatches => leagues.fold(0, (sum, l) => sum + l.matches.length);
  int get liveCount => leagues.fold(0, (sum, l) => sum + l.liveCount);
}

class _LeagueGroup {
  final String leagueName;
  final int tier;
  final List<TodayMatch> matches;

  _LeagueGroup({required this.leagueName, required this.tier, required this.matches});

  int get liveCount => matches.where((m) => m.isLive).length;
  int get predCount => matches.where((m) => m.hasPredictions).length;
}

// ── Category header ──

class _CategoryHeader extends StatelessWidget {
  final _CategoryGroup group;
  const _CategoryHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.label,
              style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(
              "${group.totalMatches}",
              style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Country header ──

class _CountryHeader extends StatelessWidget {
  final _CountryGroup group;
  const _CountryHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(group.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.displayName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "${group.totalMatches}",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          if (group.liveCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text("${group.liveCount} LIVE", style: const TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── League sub-header ──

class _LeagueSubHeader extends StatelessWidget {
  final _LeagueGroup league;
  const _LeagueSubHeader({required this.league});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 16, 4),
      child: Row(
        children: [
          Text(LeagueUtils.flag(league.leagueName), style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              league.leagueName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (league.tier == 1)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
              child: const Text("TOP", style: TextStyle(color: AppColors.gold, fontSize: 7, fontWeight: FontWeight.w700)),
            ),
          Text("${league.matches.length}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
          if (league.predCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
              child: Text("${league.predCount} pronos", style: const TextStyle(color: AppColors.emerald, fontSize: 8, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Match tile ──

class _MatchTile extends StatelessWidget {
  final TodayMatch todayMatch;
  const _MatchTile({required this.todayMatch});

  @override
  Widget build(BuildContext context) {
    final match = todayMatch.match;
    final isLive = match.status == MatchStatus.live;
    final isFinished = todayMatch.isFinished;

    final timeStr = isLive
        ? match.statusLabel
        : isFinished
            ? "Termin\u00e9"
            : DateFormat('HH:mm').format(match.dateTime.toLocal());

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MatchDetailSheet(todayMatch: todayMatch),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: isLive
              ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
              : isFinished
                  ? Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1))
                  : null,
        ),
        child: Row(
          children: [
            // Time column
            SizedBox(
              width: 52,
              child: isLive
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(timeStr, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w700)),
                    )
                  : isFinished
                      ? Text(timeStr, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500))
                      : Text(timeStr, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            // Teams
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.homeTeam.name, style: TextStyle(color: isFinished ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(match.awayTeam.name, style: TextStyle(color: isFinished ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            // Score
            if (match.score != null)
              Column(
                children: [
                  Text("${match.score!.home}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text("${match.score!.away}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            const SizedBox(width: 10),
            // Status icon
            _buildStatusIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (todayMatch.isFinished) {
      // For finished matches: show result of predictions
      final preds = todayMatch.predictions;
      if (preds.isEmpty) {
        return Icon(Icons.sports_score_rounded, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 18);
      }
      final anyCorrect = preds.any((p) => p.isCorrect == true);
      final anyIncorrect = preds.any((p) => p.isCorrect == false);
      if (anyCorrect && !anyIncorrect) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 14),
        );
      }
      if (anyIncorrect && !anyCorrect) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: AppColors.error, size: 14),
        );
      }
      if (anyCorrect && anyIncorrect) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.remove_rounded, color: AppColors.warning, size: 14),
        );
      }
      // Pending evaluation
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.hourglass_empty_rounded, color: AppColors.textSecondary, size: 14),
      );
    }

    switch (todayMatch.predictionStatus) {
      case 'available':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: AppColors.emerald, size: 14),
        );
      case 'generating':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.autorenew_rounded, color: AppColors.gold, size: 14),
        );
      case 'pending_live':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.autorenew_rounded, color: AppColors.warning, size: 14),
        );
      case 'waiting_lineups':
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.access_time_rounded, color: AppColors.info, size: 14),
        );
      default:
        return Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 18);
    }
  }
}
