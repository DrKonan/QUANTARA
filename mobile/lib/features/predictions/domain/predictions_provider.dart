import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/supabase_repository.dart';
import 'match_model.dart';
import 'prediction_model.dart';
import 'today_match_model.dart';

// ── Auto-refresh interval (60s for live match detection) ──
const _autoRefreshInterval = Duration(seconds: 60);

// ── Today eligible matches (Edge Function with auth, fallback without) ──
// Auto-refreshes every 60s so live status, scores & predictions stay current.

final todayEligibleMatchesProvider = FutureProvider<List<TodayMatch>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  final user = Supabase.instance.client.auth.currentUser;
  final result = await repo.fetchTodayEligibleMatches(useEdgeFunction: user != null);

  // Schedule next auto-refresh
  final timer = Timer(_autoRefreshInterval, () {
    debugPrint('[Quantara] Auto-refresh matches');
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return result;
});

/// Active matches only (upcoming + live, excluding finished/effectively finished)
final activeMatchesProvider = Provider<AsyncValue<List<TodayMatch>>>((ref) {
  return ref.watch(todayEligibleMatchesProvider).whenData(
    (all) => all.where((m) => !m.isEffectivelyFinished).toList(),
  );
});

/// Finished matches only (status=finished or effectively finished)
final finishedMatchesProvider = Provider<AsyncValue<List<TodayMatch>>>((ref) {
  return ref.watch(todayEligibleMatchesProvider).whenData(
    (all) => all.where((m) => m.isEffectivelyFinished).toList(),
  );
});

// ── Home data: live predictions + today predictions + stats ──

final homeLivePredictionsProvider = FutureProvider<List<Prediction>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchLivePredictions();
});

final homeTodayPredictionsProvider = FutureProvider<List<Prediction>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchTodayPredictions();
});

final monthlyStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchMonthlyStats();
});

final globalStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchGlobalStats();
});

// ── Matches ──

final todayMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchTodayMatches();
});

final liveMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchLiveMatches();
});

final upcomingMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchUpcomingMatches();
});

// ── History ──

final recentResultsProvider = FutureProvider<List<Prediction>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchRecentResults();
});

// ── Match detail predictions ──

final matchPredictionsProvider = FutureProvider.family<List<Prediction>, int>((ref, matchId) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchPredictionsForMatch(matchId);
});
