import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/supabase_repository.dart';
import 'match_model.dart';
import 'prediction_model.dart';

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
