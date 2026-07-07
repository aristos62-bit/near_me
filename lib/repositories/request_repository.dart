abstract class RequestRepository {
  Future<void> sendRequest(String toUid, String type, {String? message});
  Future<List<Map<String, dynamic>>> getIncomingRequests();
  Future<List<Map<String, dynamic>>> getOutgoingRequests();
  Stream<List<Map<String, dynamic>>> streamIncomingRequests();
  Stream<List<Map<String, dynamic>>> streamOutgoingRequests();
  Future<String?> respondToRequest(String requestId, String status);
  Future<void> deleteRequest(String requestId);
  Future<void> markRequestAsSeen(String requestId);
}
