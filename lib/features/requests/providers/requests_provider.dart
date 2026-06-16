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
