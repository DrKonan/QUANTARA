import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../predictions/domain/predictions_provider.dart';
import '../../../predictions/domain/prediction_model.dart';
import '../../../predictions/presentation/widgets/prediction_card.dart';

enum _PeriodType { all, day, week, month, custom }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _PeriodType _period = _PeriodType.all;
  int _offset = 0; // 0 = current, -1 = previous, etc.
  DateTimeRange? _customRange;

  // Period boundaries
  DateTime get _periodStart {
    final now = DateTime.now();
    switch (_period) {
      case _PeriodType.day:
        final d = now.add(Duration(days: _offset));
        return DateTime(d.year, d.month, d.day);
      case _PeriodType.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final shifted = monday.add(Duration(days: _offset * 7));
        return DateTime(shifted.year, shifted.month, shifted.day);
      case _PeriodType.month:
        final m = DateTime(now.year, now.month + _offset, 1);
        return m;
      case _PeriodType.custom:
        return _customRange != null
            ? DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day)
            : DateTime(2000);
      case _PeriodType.all:
        return DateTime(2000);
    }
  }

  DateTime get _periodEnd {
    switch (_period) {
      case _PeriodType.day:
        return _periodStart.add(const Duration(days: 1));
      case _PeriodType.week:
        return _periodStart.add(const Duration(days: 7));
      case _PeriodType.month:
        return DateTime(_periodStart.year, _periodStart.month + 1, 1);
      case _PeriodType.custom:
        if (_customRange == null) return DateTime(2100);
        final end = _customRange!.end;
        return DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
      case _PeriodType.all:
        return DateTime(2100);
    }
  }

  bool get _canGoForward => _offset < 0;

  String get _periodLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fmt = DateFormat('d MMM', 'fr_FR');

    switch (_period) {
      case _PeriodType.day:
        final d = _periodStart;
        if (d == today) return "Aujourd'hui";
        if (d == today.subtract(const Duration(days: 1))) return "Hier";
        return DateFormat('EEEE d MMM', 'fr_FR').format(d);
      case _PeriodType.week:
        final end = _periodEnd.subtract(const Duration(days: 1));
        if (_offset == 0) return "Cette semaine";
        if (_offset == -1) return "Semaine dernière";
        return "${fmt.format(_periodStart)} — ${fmt.format(end)}";
      case _PeriodType.month:
        if (_offset == 0) return "Ce mois";
        if (_offset == -1) return "Mois dernier";
        return DateFormat('MMMM yyyy', 'fr_FR').format(_periodStart);
      case _PeriodType.custom:
        if (_customRange == null) return "Sélectionner";
        return "${fmt.format(_customRange!.start)} — ${fmt.format(_customRange!.end)}";
      case _PeriodType.all:
        return "Tout l'historique";
    }
  }

  List<Prediction> _filterByPeriod(List<Prediction> results) {
    if (_period == _PeriodType.all) return results;
    if (_period == _PeriodType.custom && _customRange == null) return results;

    final start = _periodStart;
    final end = _periodEnd;

    return results.where((p) {
      final date = p.match?.dateTime ?? p.createdAt;
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  void _selectPeriod(_PeriodType type) {
    if (type == _PeriodType.custom) {
      _openDateRangePicker();
      return;
    }
    setState(() {
      _period = type;
      _offset = 0;
    });
  }

  Future<void> _openDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.background,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.background,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _period = _PeriodType.custom;
        _customRange = picked;
        _offset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(recentResultsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.refresh(recentResultsProvider.future),
          child: CustomScrollView(
            slivers: [
              // Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Historique",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Coupon Officiel — Paris validés par notre IA",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Period type chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    children: [
                      _FilterChip(label: "Tout", selected: _period == _PeriodType.all, onTap: () => _selectPeriod(_PeriodType.all)),
                      const SizedBox(width: 8),
                      _FilterChip(label: "Jour", selected: _period == _PeriodType.day, onTap: () => _selectPeriod(_PeriodType.day)),
                      const SizedBox(width: 8),
                      _FilterChip(label: "Semaine", selected: _period == _PeriodType.week, onTap: () => _selectPeriod(_PeriodType.week)),
                      const SizedBox(width: 8),
                      _FilterChip(label: "Mois", selected: _period == _PeriodType.month, onTap: () => _selectPeriod(_PeriodType.month)),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _period == _PeriodType.custom && _customRange != null ? "📅 Plage" : "📅 Plage",
                        selected: _period == _PeriodType.custom,
                        onTap: () => _selectPeriod(_PeriodType.custom),
                      ),
                    ],
                  ),
                ),
              ),

              // Period navigator (prev / label / next) — for day/week/month
              if (_period == _PeriodType.day || _period == _PeriodType.week || _period == _PeriodType.month)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.gold),
                          onPressed: () => setState(() => _offset--),
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Text(
                            _periodLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: _canGoForward ? AppColors.gold : AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          onPressed: _canGoForward ? () => setState(() => _offset++) : null,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),

              // Custom range label + edit button
              if (_period == _PeriodType.custom)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: GestureDetector(
                      onTap: _openDateRangePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.date_range_rounded, color: AppColors.gold, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _periodLabel,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Stats + List
              resultsAsync.when(
                skipLoadingOnRefresh: true,
                data: (results) {
                  final filtered = _filterByPeriod(results);

                  if (results.isEmpty) {
                    return SliverFillRemaining(child: _buildEmpty());
                  }

                  final won = filtered.where((p) => p.result == PredictionResult.won).length;
                  final lost = filtered.where((p) => p.result == PredictionResult.lost).length;
                  final settled = won + lost;
                  final rate = settled > 0 ? (won / settled * 100).round() : 0;

                  final listItems = _buildListItems(filtered);

                  return SliverMainAxisGroup(
                    slivers: [
                      // Period stats
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              _StatChip(
                                label: "Win Rate",
                                value: settled > 0 ? "$rate%" : "—",
                                color: settled == 0
                                    ? AppColors.textSecondary
                                    : rate >= 70
                                        ? AppColors.success
                                        : rate >= 50
                                            ? AppColors.warning
                                            : AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              _StatChip(label: "Gagnés", value: "$won", color: AppColors.success),
                              const SizedBox(width: 10),
                              _StatChip(label: "Perdus", value: "$lost", color: AppColors.error),
                              const SizedBox(width: 10),
                              _StatChip(label: "Total", value: "$settled", color: AppColors.textPrimary),
                            ],
                          ),
                        ),
                      ),

                      if (filtered.isEmpty)
                        SliverFillRemaining(child: _buildEmptyFilter())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => listItems[index],
                              childCount: listItems.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                ),
                error: (e, st) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Impossible de charger l'historique",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
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

  List<Widget> _buildListItems(List<Prediction> filtered) {
    final items = <Widget>[];
    String? lastDateLabel;

    for (final pred in filtered) {
      final date = pred.match?.dateTime ?? pred.createdAt;
      final label = _formatDateLabel(date);

      if (label != lastDateLabel) {
        final dayPreds = filtered.where((p) {
          final d = p.match?.dateTime ?? p.createdAt;
          return _formatDateLabel(d) == label;
        }).toList();
        final dayWon = dayPreds.where((p) => p.result == PredictionResult.won).length;
        final daySettled = dayPreds.where((p) =>
            p.result == PredictionResult.won || p.result == PredictionResult.lost).length;

        items.add(_buildDateHeader(label, dayWon, daySettled));
        lastDateLabel = label;
      }

      if (pred.match != null) {
        items.add(PredictionCard(prediction: pred, match: pred.match!));
      }
    }
    return items;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Hier";
    if (diff < 7) return DateFormat('EEEE', 'fr_FR').format(date);
    return DateFormat('d MMM yyyy', 'fr_FR').format(date);
  }

  Widget _buildDateHeader(String label, int won, int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (won == total ? AppColors.success : won > 0 ? AppColors.warning : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "$won/$total ✓",
                style: TextStyle(
                  color: won == total ? AppColors.success : won > 0 ? AppColors.warning : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 56),
          const SizedBox(height: 16),
          const Text(
            "Aucun résultat pour le moment",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            "Les résultats des pronos apparaîtront ici",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilter() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 16),
          Text(
            "Aucun résultat pour $_periodLabel",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _selectPeriod(_PeriodType.all),
            child: const Text(
              "Voir tout l'historique",
              style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.5) : AppColors.surface,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
