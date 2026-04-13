import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Historique', style: TextStyle(color: AppColors.gold)),
      ),
    );
  }
}
