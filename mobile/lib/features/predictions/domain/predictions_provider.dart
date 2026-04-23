import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/supabase_repository.dart';
import '../../../core/services/notification_service.dart';
import 'combo_prediction_model.dart';
import 'match_model.dart';
import 'prediction_model.dart';
import 'today_match_model.dart';

// ── Adaptive polling intervals ──
// Aligned with backend cron schedules:
//   - update-live-scores: every 5 min
//   - fetch-lineups: every 5 min (matches < 90 min from KO)
//   - predict-live: every 5 min during live
const _intervalLive = Duration(seconds: 30);      // Live match → catch score/prono updates fast
const _intervalPreKickoff = Duration(seconds: 45); // < 1h before KO → lineups & refined pronos
const _intervalCalm = Duration(minutes: 3);        // > 1h before KO → routine check
const _intervalIdle = Duration(minutes: 5);        // No match or all finished → minimal

/// Determines optimal polling interval based on current match states.
Duration _computePollingInterval(List<TodayMatch> matches) {
  if (matches.isEmpty) return _intervalIdle;

  bool hasLive = false;
  bool hasPreKickoff = false;
  bool hasUpcoming = false;

  for (final m in matches) {
    if (m.isLive) {
      hasLive = true;
      break; // Live = highest priority, no need to check further
    }
    if (!m.isEffectivelyFinished && m.minutesUntilKickoff > 0 && m.minutesUntilKickoff <= 60) {
      hasPreKickoff = true;
    } else if (!m.isEffectivelyFinished && m.minutesUntilKickoff > 60) {
      hasUpcoming = true;
    }
  }

  if (hasLive) return _intervalLive;
  if (hasPreKickoff) return _intervalPreKickoff;
  if (hasUpcoming) return _intervalCalm;
  return _intervalIdle; // All finished
}

// ── Today eligible matches (Edge Function with auth, fallback without) ──
// Auto-refreshes with adaptive polling: 30s (live) → 45s (pre-KO) → 3min → 5min

// ── Daily response (matches + combos from Edge Function) ──
// Single API call, split into matches and combos for downstream consumers.

final _dailyResponseProvider = FutureProvider<DailyResponse>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  final user = Supabase.instance.client.auth.currentUser;
  final result = await repo.fetchTodayEligibleMatches(useEdgeFunction: user != null);

  // Adaptive polling based on match states
  final interval = _computePollingInterval(result.matches);
  debugPrint('[Nakora] Next refresh in ${interval.inSeconds}s '
      '(${result.matches.where((m) => m.isLive).length} live, '
      '${result.matches.where((m) => !m.isEffectivelyFinished && !m.isLive && m.minutesUntilKickoff <= 60 && m.minutesUntilKickoff > 0).length} pre-KO)');

  // Trigger local notifications for new predictions & combos
  final notifService = NotificationService();
  final allPredictions = <Map<String, dynamic>>[];
  for (final m in result.matches) {
    for (final p in m.officialPredictions) {
      allPredictions.add({
        'id': '${m.match.id}_${p.predictionType}_${p.id}',
        'match': {'home_team': m.match.homeTeam.name, 'away_team': m.match.awayTeam.name},
      });
    }
    if (m.isLive) {
      for (final p in m.officialPredictions) {
        notifService.notifyLivePrediction({
          'id': 'live_${m.match.id}_${p.id}',
          'match': {'home_team': m.match.homeTeam.name, 'away_team': m.match.awayTeam.name},
        });
      }
    }
  }
  notifService.notifyNewPredictions(allPredictions);
  if (result.combos.isNotEmpty) {
    notifService.notifyCombosAvailable(
      result.combos.map((c) => {'id': c.id.toString()}).toList(),
    );
  }

  final timer = Timer(interval, () {
    debugPrint('[Nakora] Auto-refresh daily data (adaptive)');
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return result;
});

// ── Today eligible matches (derived from daily response) ──

final todayEligibleMatchesProvider = FutureProvider<List<TodayMatch>>((ref) async {
  final daily = await ref.watch(_dailyResponseProvider.future);
  return daily.matches;
});

// ── Today combos (derived from daily response) ──

final todayCombosProvider = FutureProvider<List<ComboPrediction>>((ref) async {
  final daily = await ref.watch(_dailyResponseProvider.future);
  return daily.combos;
});

/// Active matches only (upcoming + live, excluding finished/effectively finished)
/// Uses hasValue check to always show previous data during refresh (silent refresh).
final activeMatchesProvider = Provider<AsyncValue<List<TodayMatch>>>((ref) {
  final async = ref.watch(todayEligibleMatchesProvider);
  if (async.hasValue) {
    return AsyncData(async.value!.where((m) => !m.isEffectivelyFinished).toList());
  }
  if (async.isLoading) return const AsyncLoading();
  return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
});

/// Finished matches only (status=finished or effectively finished)
/// Uses hasValue check to always show previous data during refresh (silent refresh).
final finishedMatchesProvider = Provider<AsyncValue<List<TodayMatch>>>((ref) {
  final async = ref.watch(todayEligibleMatchesProvider);
  if (async.hasValue) {
    return AsyncData(async.value!.where((m) => m.isEffectivelyFinished).toList());
  }
  if (async.isLoading) return const AsyncLoading();
  return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
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
