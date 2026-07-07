import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../debug/debug_config.dart';
import '../router/app_router.dart';

@pragma('vm:entry-point')
class FcmService {
  static bool isLocked = false;
  static String? _pendingFcmPath;

  static bool get hasPendingNavigation => _pendingFcmPath != null;

  /// Chat ID που βλέπει ο χρήστης αυτή τη στιγμή.
  /// Ενημερώνεται από `ChatScreen.initState` / `dispose`.
  static String? activeChatId;

  static final _foregroundCtrl = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get foregroundStream => _foregroundCtrl.stream;

  static Future<void> init() async {
    DebugConfig.log(DebugConfig.chatFcm, 'FcmService.init');

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    DebugConfig.log(DebugConfig.chatFcm,
      'Permission: ${settings.authorizationStatus}');

    setBadge(0);

    await _trySaveToken(messaging);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        DebugConfig.log(DebugConfig.chatFcm,
            'Auth state → user available, saving token');
        _trySaveToken(messaging);
      }
    });

    messaging.onTokenRefresh.listen((_) {
      DebugConfig.log(DebugConfig.chatFcm, 'Token refresh');
      _trySaveToken(messaging);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      final data = initial.data;
      if (data['type'] == 'request') {
        final rid = data['requestId'];
        _pendingFcmPath = (rid != null && rid is String) ? '/requests/$rid' : '/requests';
        DebugConfig.log(DebugConfig.requestFcm, 'Pending nav set: $_pendingFcmPath');
      } else {
        final cid = data['chatId'];
        if (cid != null && cid is String) {
          _pendingFcmPath = '/chat/$cid';
          DebugConfig.log(DebugConfig.chatFcm, 'Pending nav set: /chat/$cid');
        }
      }
    }

    FirebaseMessaging.onBackgroundMessage(_onBackgroundHandler);
  }

  static void setBadge(int count) {
    try {
      SystemChannels.platform.invokeMethod<void>(
        'SystemChrome.setApplicationBadge', count,
      );
      DebugConfig.log(DebugConfig.chatFcm, 'Badge set to $count');
    } catch (_) {
      DebugConfig.warn('Badge set failed for count=$count');
    }
  }

  static Future<void> _trySaveToken(FirebaseMessaging messaging) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await messaging.getToken();
    if (token == null) return;

    DebugConfig.log(DebugConfig.chatFcm, 'Save token for ${user.uid}');

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await FirebaseFirestore.instance
            .doc('users/${user.uid}/fcm_tokens/$token')
            .set({
          'token': token,
          'platform': _platform,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      } catch (e) {
        DebugConfig.warn('FCM save token attempt $attempt failed', data: e);
        if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
      }
    }
    DebugConfig.error('FCM save token failed after 2 attempts');
  }

  static String get _platform {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  static void _onForegroundMessage(RemoteMessage msg) {
    final isRequest = msg.data['type'] == 'request';
    DebugConfig.log(
      isRequest ? DebugConfig.requestFcm : DebugConfig.chatFcm,
      'Foreground: ${msg.notification?.title} | ${msg.data}',
    );
    _foregroundCtrl.add(msg);
  }

  static void _onMessageOpened(RemoteMessage msg) {
    final data = msg.data;
    String? path;
    if (data['type'] == 'request') {
      final rid = data['requestId'];
      path = (rid != null && rid is String) ? '/requests/$rid' : '/requests';
    } else {
      final cid = data['chatId'];
      if (cid != null && cid is String) path = '/chat/$cid';
    }
    if (path == null) return;

    DebugConfig.log(DebugConfig.chatFcm,
        'FCM _onMessageOpened: path=$path isLocked=$isLocked');
    if (isLocked) {
      _pendingFcmPath = path;
      return;
    }
    AppRouter.router.push(path);
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundHandler(RemoteMessage msg) async {
    final isRequest = msg.data['type'] == 'request';
    DebugConfig.log(
      isRequest ? DebugConfig.requestFcm : DebugConfig.chatFcm,
      'Background: ${msg.messageId} | type=${msg.data['type']}',
    );
  }

  static void tryExecutePendingNav() {
    if (_pendingFcmPath == null) return;
    DebugConfig.log(DebugConfig.chatFcm,
        'FCM executing pending nav=$_pendingFcmPath');
    final path = _pendingFcmPath!;
    _pendingFcmPath = null;
    AppRouter.router.push(path);
  }

  static void clearPendingNav() {
    if (_pendingFcmPath != null) {
      DebugConfig.log(DebugConfig.chatFcm,
          'FCM clearing pending nav=$_pendingFcmPath');
      _pendingFcmPath = null;
    }
  }

  /// Ελέγχει αν το foreground notification πρέπει να κατασταλεί.
  /// Επιστρέφει true μόνο για chat_message όταν ο χρήστης είναι ήδη
  /// στο συγκεκριμένο chat (Single Point of Truth).
  static bool shouldSuppressForeground(RemoteMessage msg) {
    final type = msg.data['type'] as String?;
    if (type != 'chat_message') return false;

    final chatId = msg.data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) {
      DebugConfig.warn(
          'shouldSuppressForeground: chatId missing for type=$type');
      return false;
    }

    final inChat = chatId == activeChatId;

    DebugConfig.log(DebugConfig.chatFcm, inChat
        ? 'suppressed: user in chat $chatId'
        : 'showing: user at "$activeChatId", not chat $chatId');

    return inChat;
  }

  static Future<void> clearTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users/${user.uid}/fcm_tokens')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) { batch.delete(doc.reference); }
      await batch.commit();
      DebugConfig.log(DebugConfig.chatFcm,
        'Cleared ${snap.docs.length} tokens');
    } catch (e) {
      DebugConfig.error('FCM clear tokens failed', exception: e);
    }
  }
}
