import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/debug/debug_config.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  DebugConfig.log(DebugConfig.networkConnectivity,
      'connectivityProvider: initializing stream');
  return Connectivity().onConnectivityChanged.map((result) {
    final online = !result.contains(ConnectivityResult.none);
    DebugConfig.log(DebugConfig.networkConnectivity,
        'connectivityProvider: ${online ? "ONLINE" : "OFFLINE"} ($result)');
    return online;
  });
});
