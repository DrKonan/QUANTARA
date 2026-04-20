import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';

// Preference keys
const _kMaster = 'notif_master';
const _kPredictions = 'notif_predictions';
const _kResults = 'notif_results';
const _kLive = 'notif_live';
const _kCombos = 'notif_combos';
const _kPromos = 'notif_promos';

final _notifPrefsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    _kMaster: prefs.getBool(_kMaster) ?? true,
    _kPredictions: prefs.getBool(_kPredictions) ?? true,
    _kResults: prefs.getBool(_kResults) ?? true,
    _kLive: prefs.getBool(_kLive) ?? true,
    _kCombos: prefs.getBool(_kCombos) ?? true,
    _kPromos: prefs.getBool(_kPromos) ?? false,
  };
});

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _master = true;
  bool _predictions = true;
  bool _results = true;
  bool _live = true;
  bool _combos = true;
  bool _promos = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _master = prefs.getBool(_kMaster) ?? true;
      _predictions = prefs.getBool(_kPredictions) ?? true;
      _results = prefs.getBool(_kResults) ?? true;
      _live = prefs.getBool(_kLive) ?? true;
      _combos = prefs.getBool(_kCombos) ?? true;
      _promos = prefs.getBool(_kPromos) ?? false;
      _loaded = true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    ref.invalidate(_notifPrefsProvider);
  }

  void _toggleMaster(bool value) {
    setState(() => _master = value);
    _save(_kMaster, value);
  }

  void _toggle(String key, bool value, void Function(bool) setter) {
    if (!_master) return;
    setter(value);
    _save(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      "Notifications",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _loaded
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // Master toggle — hero card
                          _buildMasterCard(),

                          const SizedBox(height: 28),

                          // Category section
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              "CATÉGORIES",
                              style: TextStyle(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          _buildToggleTile(
                            icon: Icons.analytics_rounded,
                            iconColor: AppColors.gold,
                            title: "Nouvelles prédictions",
                            subtitle:
                                "Quand un pronostic officiel est disponible",
                            value: _predictions,
                            onChanged: (v) => _toggle(
                                _kPredictions, v, (val) => setState(() => _predictions = val)),
                          ),

                          _buildToggleTile(
                            icon: Icons.emoji_events_rounded,
                            iconColor: AppColors.emerald,
                            title: "Résultats des matchs",
                            subtitle:
                                "Score final et résultat de vos pronostics",
                            value: _results,
                            onChanged: (v) => _toggle(
                                _kResults, v, (val) => setState(() => _results = val)),
                          ),

                          _buildToggleTile(
                            icon: Icons.sports_soccer_rounded,
                            iconColor: AppColors.info,
                            title: "Matchs en direct",
                            subtitle: "Alertes pendant les matchs live",
                            value: _live,
                            onChanged: (v) => _toggle(
                                _kLive, v, (val) => setState(() => _live = val)),
                          ),

                          _buildToggleTile(
                            icon: Icons.layers_rounded,
                            iconColor: AppColors.gold,
                            title: "Combinaisons",
                            subtitle: "Quand un combo est disponible",
                            value: _combos,
                            onChanged: (v) => _toggle(
                                _kCombos, v, (val) => setState(() => _combos = val)),
                          ),

                          _buildToggleTile(
                            icon: Icons.campaign_rounded,
                            iconColor: AppColors.warning,
                            title: "Promotions & actualités",
                            subtitle: "Offres spéciales et mises à jour",
                            value: _promos,
                            onChanged: (v) => _toggle(
                                _kPromos, v, (val) => setState(() => _promos = val)),
                          ),

                          const SizedBox(height: 32),

                          // Info card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      AppColors.surfaceLight.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.6),
                                    size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Les notifications sont envoyées via Firebase Cloud Messaging. "
                                    "Vous pouvez aussi gérer les permissions dans les réglages de votre appareil.",
                                    style: TextStyle(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _master
              ? [
                  AppColors.gold.withValues(alpha: 0.12),
                  AppColors.gold.withValues(alpha: 0.04),
                ]
              : [
                  AppColors.surface,
                  AppColors.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _master
              ? AppColors.gold.withValues(alpha: 0.3)
              : AppColors.surfaceLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _master
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _master
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: _master ? AppColors.gold : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _master ? "Notifications activées" : "Notifications désactivées",
                  style: TextStyle(
                    color: _master
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _master
                      ? "Vous recevez les alertes importantes"
                      : "Aucune notification ne sera envoyée",
                  style: TextStyle(
                    color:
                        AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _master,
            activeTrackColor: AppColors.gold,
            onChanged: _toggleMaster,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final enabled = _master;
    final effectiveAlpha = enabled ? 1.0 : 0.35;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Opacity(
          opacity: effectiveAlpha,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
        title: Opacity(
          opacity: effectiveAlpha,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        subtitle: Opacity(
          opacity: effectiveAlpha,
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        trailing: CupertinoSwitch(
          value: enabled && value,
          activeTrackColor: iconColor,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
