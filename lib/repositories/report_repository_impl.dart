import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import 'report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required String reason,
  }) async {
    DebugConfig.log(DebugConfig.firestoreWrite,
        'ReportRepository submitReport: target=$reportedUid reason=$reason');
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      DebugConfig.log(DebugConfig.firestoreWrite,
          'ReportRepository submitReport success: $reportedUid');
    } catch (e, s) {
      throw AppException.firestore('submitReport', e, s);
    }
  }
}
