import 'package:flutter/material.dart';

class OnboardingSlide {
  final String title;
  final String subtitle;
  final IconData icon;

  const OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const onboardingSlides = [
  OnboardingSlide(
    title: 'Des pronos intelligents',
    subtitle: "Pas des paris au hasard. Chaque prono est le fruit d'une analyse rigoureuse basee sur les donnees reelles.",
    icon: Icons.psychology_rounded,
  ),
  OnboardingSlide(
    title: "L'IA analyse tout",
    subtitle: "Forme, blessures, confrontations directes, stats domicile/exterieur... Aucun detail n'est laisse au hasard.",
    icon: Icons.analytics_rounded,
  ),
  OnboardingSlide(
    title: 'Pre-match & Live',
    subtitle: "On s'adapte a la physionomie du match. Si une opportunite apparait en cours de jeu, on te le dit.",
    icon: Icons.sports_soccer_rounded,
  ),
  OnboardingSlide(
    title: '3 jours gratuits',
    subtitle: 'Acces complet a toutes les fonctionnalites premium. Sans engagement.',
    icon: Icons.workspace_premium_rounded,
  ),
];
