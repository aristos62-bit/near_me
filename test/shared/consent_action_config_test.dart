import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/consent_action_config.dart';

/// Pure `ConsentActionConfig` — lookups + fallbacks.
void main() {
  group('ConsentActionConfig.get', () {
    test('γνωστό action → info με ετικέτες', () {
      final info = ConsentActionConfig.get('sent_request');
      expect(info, isNotNull);
      expect(info!.elLabel, 'Αποστολή αιτήματος');
      expect(info.enLabel, 'Sent a request');
    });

    test('άγνωστο action → null', () {
      expect(ConsentActionConfig.get('nope'), isNull);
    });
  });

  group('ConsentActionConfig.icon', () {
    test('γνωστό → icon/outlined', () {
      expect(ConsentActionConfig.icon('published'), Icons.cloud_upload);
      expect(ConsentActionConfig.icon('published', outlined: true),
          Icons.cloud_upload_outlined);
    });

    test('άγνωστο → info_outline fallback', () {
      expect(ConsentActionConfig.icon('nope'), Icons.info_outline);
    });
  });

  group('ConsentActionConfig.color', () {
    test('γνωστό → το χρώμα του', () {
      expect(ConsentActionConfig.color('deleted_account'), isNotNull);
    });

    test('άγνωστο → grey fallback', () {
      expect(ConsentActionConfig.color('nope'), Colors.grey);
    });
  });

  group('ConsentActionConfig.label', () {
    test('el/en ανά action', () {
      expect(ConsentActionConfig.label('group_joined', true), 'Εγγραφή σε ομάδα');
      expect(ConsentActionConfig.label('group_joined', false), 'Joined a group');
      expect(ConsentActionConfig.label('help_request_activate', true),
          'Ενεργοποίηση επείγουσας βοήθειας');
    });

    test('άγνωστο → επιστρέφει το ίδιο το action', () {
      expect(ConsentActionConfig.label('mystery', true), 'mystery');
    });
  });
}
