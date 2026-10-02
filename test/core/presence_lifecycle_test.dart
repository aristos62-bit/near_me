import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/services/presence_service.dart';

/// Lifecycle paths χωρίς Firebase (`_ref == null` → early return).
/// Το resumed-with-user διαβάζει `FirebaseAuth.instance` (πετάει σε VM)
/// → ρητά εκτός, τεκμηριωμένο εδώ.
void main() {
  group('PresenceService lifecycle χωρίς Firebase', () {
    test('paused → no-throw (setOffline early return)', () {
      PresenceService.reset();
      expect(
          () => PresenceService.handleLifecycle(AppLifecycleState.paused),
          returnsNormally);
    });

    test('inactive + detached → no-throw', () {
      PresenceService.reset();
      expect(
          () => PresenceService.handleLifecycle(AppLifecycleState.inactive),
          returnsNormally);
      expect(
          () => PresenceService.handleLifecycle(AppLifecycleState.detached),
          returnsNormally);
    });

    test('reset → καθαρίζει flags, paused παραμένει ασφαλές', () {
      PresenceService.reset();
      PresenceService.reset();
      expect(
          () => PresenceService.handleLifecycle(AppLifecycleState.paused),
          returnsNormally);
    });
  });
}
