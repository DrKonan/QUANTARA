import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Matchs', style: TextStyle(color: AppColors.gold)),
      ),
    );
  }
}
