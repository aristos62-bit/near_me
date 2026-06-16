import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/report_repository.dart';
import '../../../repositories/report_repository_impl.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'reportRepositoryProvider created');
  return ReportRepositoryImpl();
});
