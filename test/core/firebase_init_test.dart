import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/firebase/firebase_init.dart';

/// `FirebaseInit.tryInitialize` σε VM χωρίς app → false (bounded 6s).
void main() {
  group('FirebaseInit', () {
    test('χωρίς Firebase app → false, όχι throw, όχι hang', () async {
      final ok = await FirebaseInit.tryInitialize();
      expect(ok, isFalse);
    });

    test('δεύτερη κλήση → πάλι false (χωρίς διαρροή state)', () async {
      expect(await FirebaseInit.tryInitialize(), isFalse);
      expect(await FirebaseInit.tryInitialize(), isFalse);
    });
  });
}
