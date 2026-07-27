import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';
import 'app_messenger.dart';
import 'error_messages.dart';

class ConnectivityGuard {
  ConnectivityGuard._();

  /// Χωρίς context — επιστρέφει true αν online.
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Με context — αν offline, εμφανίζει μήνυμα και επιστρέφει false.
  static Future<bool> ensure(BuildContext context) async {
    if (await isOnline()) return true;
    DebugConfig.log(DebugConfig.networkConnectivity,
        'ConnectivityGuard: OFFLINE — blocking action');
    if (context.mounted) {
      final isGreek = L10n.isGreek(context);
      AppMessenger.showError(
        context,
        ErrorMessages.get('network/no-connectivity', isGreek),
      );
    }
    return false;
  }
}
