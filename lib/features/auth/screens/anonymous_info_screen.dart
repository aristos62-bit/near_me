import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';

class AnonymousInfoScreen extends ConsumerStatefulWidget {
  const AnonymousInfoScreen({super.key});

  @override
  ConsumerState<AnonymousInfoScreen> createState() => _AnonymousInfoScreenState();
}

class _AnonymousInfoScreenState extends ConsumerState<AnonymousInfoScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'AnonymousInfoScreen: shown');
    _timer = Timer(const Duration(seconds: 10), _navigateToMain);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateToMain() {
    DebugConfig.log(DebugConfig.uiInteraction, 'AnonymousInfoScreen: auto-navigate to main');
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    return Scaffold(
      backgroundColor: Colors.black12,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = ResponsiveUtils.resolveWidth(context, constraints);
            return Center(
              child: SizedBox(
                width: ResponsiveUtils.maxContentWidthFromWidth(w),
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Image.asset('assets/icons/near_me.webp', width: 200, height: 200),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    isGreek
                        ? 'Καλωσήρθες στο NearMe!'
                        : 'Welcome to NearMe!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isGreek
                        ? 'Για συμμετοχή στην κοινότητα πρέπει στο Προφίλ → Ρυθμίσεις να κάνετε επαλήθευση του λογαριασμού σας και να δημιουργήσετε το δικό σας Προφίλ.'
                        : 'To join the community, go to Profile → Settings, verify your account and create your own Profile.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withAlpha(220),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGreek
                        ? 'Όλα τα προσωπικά σας δεδομένα θα αποθηκεύονται τοπικά και θα δημοσιεύετε για όσο χρόνο θέλετε αυτά που απαιτούνται όταν θελήσετε να συμμετάσχετε στην κοινότητα για κάποιο θέμα σας, έτσι ώστε να σας βλέπουν τα υπόλοιπα μέλη.'
                        : 'All your personal data is stored locally. You publish only what is needed, for as long as you want, when you want to participate in the community so that other members can see you.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(200),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: _navigateToMain,
                    child: Text(
                      isGreek ? 'Παράβλεψη' : 'Skip',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    ),
    );
  }
}
