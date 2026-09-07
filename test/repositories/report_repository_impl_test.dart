import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/repositories/report_repository_impl.dart';

import '../helpers/failing_firestore.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReportRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ReportRepositoryImpl(firestore: firestore);
  });

  group('submitReport', () {
    test('επιτυχία → doc στη reports με σωστά πεδία', () async {
      await repo.submitReport(
        reporterUid: 'reporter',
        reportedUid: 'reported',
        reason: 'spam',
      );

      final snapshot =
          await firestore.collection('reports').get();
      expect(snapshot.docs, hasLength(1));
      final data = snapshot.docs.single.data();
      expect(data['reporterUid'], 'reporter');
      expect(data['reportedUid'], 'reported');
      expect(data['reason'], 'spam');
      expect(data['status'], 'pending');
      expect(data['createdAt'], isNotNull);
    });

    test('Firestore λάθος → AppException firestore_error', () async {
      final failingRepo = ReportRepositoryImpl(firestore: failingReportFirestore());

      await expectLater(
        failingRepo.submitReport(
          reporterUid: 'a',
          reportedUid: 'b',
          reason: 'x',
        ),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });
}
