import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// SPoT — mock του connectivity_plus MethodChannel για unit/widget tests.
///
/// Τα notifiers καλούν `ConnectivityGuard.isOnline()` (static, χωρίς DI),
/// που σε VM πετάει MissingPluginException. Με αυτό το helper η συνδεσιμότητα
/// ελέγχεται ντετερμινιστικά. Προηγούμενο τεχνικής: clipboard mock στο
/// `text_message_bubble_invite_copy_test.dart`.
const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

Future<void> mockConnectivityOnline() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['wifi'];
    return null;
  });
}

Future<void> mockConnectivityOffline() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['none'];
    return null;
  });
}

void resetConnectivityMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
}
