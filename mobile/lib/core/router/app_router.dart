import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/domain/onboarding_provider.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingAsync = ref.watch(onboardingDoneProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final onboardingDone = onboardingAsync.valueOrNull ?? false;
      final path = state.uri.path;

      // Step 1: Onboarding not done → force onboarding
      if (!onboardingDone) {
        return path == '/' ? null : '/';
      }

      // Step 2: Not authenticated → force auth (except forgot-password)
      if (!isAuthenticated) {
        if (path == '/auth' || path == '/auth/forgot-password') return null;
        return '/auth';
      }

      // Step 3: Authenticated but on auth/onboarding → go home
      if (path == '/' || path == '/auth') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/auth/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/matches', builder: (context, state) => const MatchesScreen()),
          GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
