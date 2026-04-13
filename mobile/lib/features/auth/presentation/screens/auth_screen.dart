import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Auth', style: TextStyle(color: AppColors.gold)),
      ),
    );
  }
}
