import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/biometric_service.dart';

/// Wraps the app and listens for auth state changes.
/// When the session expires (token refresh fails), shows a re-login dialog
/// with biometric option if available.
class SessionGuard extends ConsumerStatefulWidget {
  final Widget child;
  const SessionGuard({super.key, required this.child});

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard> with WidgetsBindingObserver {
  bool _wasAuthenticated = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasAuthenticated = Supabase.instance.client.auth.currentSession != null;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final hasSession = data.session != null;

      if (event == AuthChangeEvent.tokenRefreshed) {
        _wasAuthenticated = true;
        return;
      }

      if (event == AuthChangeEvent.signedIn) {
        _wasAuthenticated = true;
        if (_dialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _dialogShown = false;
        }
        return;
      }

      // Session lost unexpectedly (not user-initiated signout)
      if (_wasAuthenticated && !hasSession && event == AuthChangeEvent.signedOut) {
        _wasAuthenticated = false;
        _showSessionExpiredDialog();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryRefreshSession();
    }
  }

  Future<void> _tryRefreshSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    // If token expires within 60s, try refresh
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiresIn = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
          .difference(DateTime.now())
          .inSeconds;
      if (expiresIn < 60) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {
          // Will be caught by onAuthStateChange listener
        }
      }
    }
  }

  Future<void> _showSessionExpiredDialog() async {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;

    final bio = BiometricService();
    final canBio = await bio.isDeviceSupported &&
        await bio.isEnabled &&
        await bio.hasStoredCredentials;
    final bioLabel = canBio ? await bio.biometricLabel : '';

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SessionExpiredDialog(
        canBiometric: canBio,
        biometricLabel: bioLabel,
        onBiometricLogin: () async {
          final success = await bio.authenticateAndSignIn();
          if (success && ctx.mounted) {
            Navigator.of(ctx).pop();
            _dialogShown = false;
          }
        },
        onManualLogin: () {
          Navigator.of(ctx).pop();
          _dialogShown = false;
          // Router redirect will handle navigation to /auth
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _SessionExpiredDialog extends StatefulWidget {
  final bool canBiometric;
  final String biometricLabel;
  final Future<void> Function() onBiometricLogin;
  final VoidCallback onManualLogin;

  const _SessionExpiredDialog({
    required this.canBiometric,
    required this.biometricLabel,
    required this.onBiometricLogin,
    required this.onManualLogin,
  });

  @override
  State<_SessionExpiredDialog> createState() => _SessionExpiredDialogState();
}

class _SessionExpiredDialogState extends State<_SessionExpiredDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.timer_off_rounded, color: AppColors.gold, size: 24),
          SizedBox(width: 8),
          Text(
            "Session expirée",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: const Text(
        "Votre session a expiré. Reconnectez-vous pour continuer.",
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (widget.canBiometric) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await widget.onBiometricLogin();
                      if (mounted) setState(() => _loading = false);
                    },
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.fingerprint, size: 20),
              label: Text(
                widget.biometricLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.onManualLogin,
            child: Text(
              widget.canBiometric ? "Se connecter manuellement" : "Se reconnecter",
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
