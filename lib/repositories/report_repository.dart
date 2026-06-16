abstract class ReportRepository {
  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required String reason,
  });
}
