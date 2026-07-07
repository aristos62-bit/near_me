import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/request_repository.dart';
import '../../../repositories/request_repository_impl.dart';

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'requestRepositoryProvider created');
  return RequestRepositoryImpl();
});

final incomingRequestsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(requestRepositoryProvider);
  DebugConfig.log(DebugConfig.providerCreate, 'incomingRequestsProvider: stream starting');
  return repo.streamIncomingRequests();
});

final outgoingRequestsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(requestRepositoryProvider);
  DebugConfig.log(DebugConfig.providerCreate, 'outgoingRequestsProvider: stream starting');
  return repo.streamOutgoingRequests();
});

final unreadRequestsProvider = Provider.autoDispose<int>((ref) {
  final incoming = ref.watch(incomingRequestsProvider);
  final value = incoming.asData?.value;
  final count = value == null
      ? 0
      : value.where((r) => r['status'] == 'pending' && r['readAt'] == null).length;
  DebugConfig.log(DebugConfig.repositoryResult, 'unreadRequestsProvider: count=$count');
  return count;
});
