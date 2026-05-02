import 'package:flutter/material.dart';
import '../../../predictions/domain/combo_prediction_model.dart';

/// Card for displaying a combo prediction (safe or bold accumulator).
class ComboCard extends StatelessWidget {
  final ComboPrediction combo;
  final bool isLocked;
  final VoidCallback? onTap;
  final VoidCallback? onUpgradeTap;

  const ComboCard({
    super.key,
    required this.combo,
    this.isLocked = false,
    this.onTap,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSafe = combo.isSafe;
    final accentColor = isSafe
        ? const Color(0xFF00C896)  // Emerald for safe
        : const Color(0xFFFF6B35); // Orange for bold
    final bgColor = const Color(0xFF1A1A2E);
    final borderColor = accentColor.withAlpha(80);

    return GestureDetector(
      onTap: isLocked ? onUpgradeTap : onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(accentColor),
            // Legs list
            if (!isLocked && combo.legs != null)
              ...combo.legs!.take(4).map((leg) => _buildLegRow(leg, accentColor)),
            if (!isLocked && combo.legs != null && combo.legs!.length > 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  '+${combo.legs!.length - 4} autre(s)',
                  style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
                ),
              ),
            // Locked overlay
            if (isLocked)
              _buildLockedOverlay(accentColor),
            // Footer with odds
            _buildFooter(accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(combo.typeEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  combo.typeLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      combo.slotEmoji,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      combo.slotLabel,
                      style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${combo.legCount} sélections',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Combined odds badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(80)),
            ),
            child: Text(
              combo.oddsLabel,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegRow(ComboLeg leg, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(leg.typeIcon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leg.homeTeam} vs ${leg.awayTeam}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  leg.eventLabel,
                  style: TextStyle(
                    color: accent.withAlpha(200),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '@${leg.bookmakerOdds.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Icon(Icons.lock_rounded, color: accent.withAlpha(150), size: 28),
          const SizedBox(height: 6),
          Text(
            combo.isSafe ? 'Disponible avec Pro ou VIP' : 'Exclusif VIP',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withAlpha(80)),
            ),
            child: Text(
              'Débloquer',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(20)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Confidence
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: accent, size: 14),
              const SizedBox(width: 4),
              Text(
                '${combo.confidencePercent}%',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          // Status badge
          if (!combo.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: combo.isWon
                    ? const Color(0xFF00C896).withAlpha(30)
                    : combo.isLost
                        ? Colors.red.withAlpha(30)
                        : Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                combo.statusLabel,
                style: TextStyle(
                  color: combo.isWon
                      ? const Color(0xFF00C896)
                      : combo.isLost
                          ? Colors.red
                          : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Min plan badge
          if (combo.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                combo.minPlan.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
