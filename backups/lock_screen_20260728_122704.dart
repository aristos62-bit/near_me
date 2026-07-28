import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../debug/debug_config.dart';

class LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const LockScreen({required this.onUnlock, super.key});

  static Future<bool> authenticate({String reason = ''}) async {
    DebugConfig.log(DebugConfig.serviceCall,
        'LockScreen: authenticate requested${reason.isNotEmpty ? ' — $reason' : ''}');
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) {
        DebugConfig.warn('LockScreen: biometric not available on device');
        return false;
      }
      final authed = await auth.authenticate(
        localizedReason: reason.isNotEmpty ? reason : 'Authenticate to unlock NearMe',
        biometricOnly: false,
      );
      DebugConfig.log(DebugConfig.serviceCall,
          'LockScreen: authenticate result=$authed');
      return authed;
    } catch (e) {
      DebugConfig.warn('LockScreen: authenticate exception', data: e);
      return false;
    }
  }

  static Future<bool> canUseBiometric() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final deviceSupported = await auth.isDeviceSupported();
      final enrolled = await auth.getAvailableBiometrics();
      DebugConfig.log(DebugConfig.serviceCall,
          'LockScreen: canCheck=$canCheck | deviceSupported=$deviceSupported | enrolled=$enrolled');
      return (canCheck || deviceSupported) && enrolled.isNotEmpty;
    } catch (e) {
      DebugConfig.warn('LockScreen: canUseBiometric check failed', data: e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = Localizations.localeOf(context).languageCode == 'el';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'NearMe',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isGreek ? 'Εφαρμογή κλειδωμένη' : 'App locked',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: Text(isGreek ? 'Ξεκλείδωμα' : 'Unlock'),
                    onPressed: () async {
                      final authed = await authenticate(
                        reason: isGreek
                            ? 'Ξεκλείδωσε το NearMe'
                            : 'Unlock NearMe',
                      );
                      if (authed) {
                        DebugConfig.log(DebugConfig.serviceCall,
                            'LockScreen: unlock success');
                        onUnlock();
                      } else {
                        DebugConfig.warn('LockScreen: unlock failed');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isGreek
                                    ? 'Αποτυχία ταυτοποίησης. Προσπάθησε ξανά.'
                                    : 'Authentication failed. Try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
