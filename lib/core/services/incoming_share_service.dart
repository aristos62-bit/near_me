import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/feature_flags.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';
import '../utils/app_messenger.dart';
import '../utils/error_messages.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../../../shared/widgets/chat_recipient_picker.dart';
import '../../../shared/widgets/incoming_share_sheet.dart';
import '../../data/local/database.dart';

/// Διαχείριση εισερχόμενου sharing (OS share sheet → εφαρμογή).
///
/// Event-driven, όχι stream: το payload κρατιέται σε static field (consume-once)
/// και εμφανίζεται μόνο όταν το καλέσει το NearMeApp (μετά unlock). Κανένα
/// provider δεν γίνεται watch → μηδέν rebuilds.
class IncomingShareService {
  IncomingShareService._();

  static const _channel = MethodChannel('near_me/incoming_share');

  /// Ανώτατο μήκος shared text που προωθείται (προστασία από υπερβολικά μεγάλα
  /// payloads από εξωτερικές εφαρμογές).
  static const _maxContentChars = 4000;

  static IncomingSharePayload? _pendingShare;
  static bool _isShowingSheet = false;

  /// Καλείται από το NearMeApp (main.dart) όταν γίνει διαθέσιμο ένα warm share
  /// ενώ το app είναι ήδη ανοιχτό & ξεκλείδωτο — ώστε το sheet να εμφανιστεί
  /// άμεσα. Σε cold start το εμφανίζει το main.dart μετά το unlock/resume.
  static void Function()? onPending;

  static bool get hasPendingShare => _pendingShare != null;

  /// Καλείται μετά το Firebase init (μαζί με το FcmService.init()).
  /// Στήνει τον warm-start handler και κάνει poll το cold-start pending.
  static Future<void> init() async {
    if (!FeatureFlags.incomingShareEnabled) return;
    DebugConfig.log(DebugConfig.chatShare, 'IncomingShare: init');
    _channel.setMethodCallHandler(_onNativeCall);
    await pollPending();
  }

  /// Cold-start poll: ζητάει το buffered intent από το native.
  /// Σε μη-Android πλατφόρμες MissingPluginException → graceful no-op.
  static Future<void> pollPending() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getPendingShare');
      if (raw != null) _queueFromNative(raw);
    } catch (e) {
      DebugConfig.warn('IncomingShare: pollPending unavailable', data: e);
    }
  }

  /// Warm-start push από το native (app ήδη ανοιχτό).
  static Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == 'onShareReceived') {
      _queueFromNative(call.arguments);
      onPending?.call();
    }
  }

  static void _queueFromNative(dynamic raw) {
    final payload = _fromNative(raw);
    if (payload == null) return;
    _pendingShare = payload;
    DebugConfig.log(DebugConfig.chatShare,
        'IncomingShare: queued type=${payload.type} len=${payload.content.length}');
  }

  static IncomingSharePayload? _fromNative(dynamic raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type != 'text' &&
        type != 'url' &&
        type != 'image' &&
        type != 'video' &&
        type != 'audio') {
      return null;
    }
    var content = raw['content'];
    if (content is! String || content.isEmpty) return null;
    if (content.length > _maxContentChars) {
      content = content.substring(0, _maxContentChars);
    }
    return IncomingSharePayload(
      type: type,
      content: content,
      uri: raw['uri'] as String?,
    );
  }

  /// Εκτελεί το pending share (αν υπάρχει): gate → preview sheet → picker → send.
  /// Consume-once + reentrancy guard (ποτέ 2 sheets μαζί).
  static Future<void> tryExecutePending(WidgetRef ref, BuildContext context) async {
    final payload = _pendingShare;
    if (payload == null || _isShowingSheet) return;
    _pendingShare = null;
    _isShowingSheet = true;
    DebugConfig.log(DebugConfig.chatShare, 'IncomingShare: executing type=${payload.type}');
    try {
      final greek = L10n.isGreek(context);

      if (!AuthRepository.canUserCommunicate(FirebaseAuth.instance.currentUser)) {
        AppMessenger.showInfo(context,
            ErrorMessages.get('share/needs-verification', greek));
        return;
      }

      final isMedia = payload.type != 'text' && payload.type != 'url';
      if (isMedia) {
        AppMessenger.showInfo(context,
            ErrorMessages.get('share/media-not-supported', greek));
        return;
      }

      final chats = (await _loadChats(ref)).where((c) => c.chatId != null).toList();
      if (!context.mounted) return;
      if (chats.isEmpty) {
        AppMessenger.showInfo(context,
            ErrorMessages.get('chat/no-chats-forward', greek));
        return;
      }

      final confirmed = await showIncomingShareSheet(context,
          type: payload.type, content: payload.content);
      if (confirmed != true || !context.mounted) return;

      final targetChatId = await showChatRecipientPicker(context, chats);
      if (targetChatId == null || !context.mounted) return;

      final ok = await ref.read(chatActionsProvider.notifier)
          .sendMessage(targetChatId, payload.content);
      if (!context.mounted) return;
      if (!ok) {
        final state = ref.read(chatActionsProvider);
        AppMessenger.showError(context, ErrorMessages.get(
            state.errorMessage ?? 'chat/forward-failed', greek));
        return;
      }
      AppMessenger.showSuccess(context,
          ErrorMessages.get('chat/forwarded', greek));
    } finally {
      _isShowingSheet = false;
    }
  }

  /// Επιστρέφει τις συνομιλίες. Σε cold start το chatsProvider μπορεί να μην έχει
  /// φορτώσει ακόμα → περιμένει μέχρι το πρώτο AsyncData (max 8s). Σε warm start
  /// επιστρέφει αμέσως. Timeout/error → fallback στα ήδη φορτωμένα (ίσως κενά).
  static Future<List<ChatCacheTableData>> _loadChats(WidgetRef ref) async {
    try {
      return await ref.read(chatsProvider.future)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return ref.read(chatsProvider).asData?.value ?? const <ChatCacheTableData>[];
    }
  }
}

/// Απλό value object του εισερχόμενου payload (μόνο στη μνήμη, ποτέ στο disk).
class IncomingSharePayload {
  final String type; // 'text' | 'url' | 'image'
  final String content;
  final String? uri; // phase 2: εικόνες

  const IncomingSharePayload({
    required this.type,
    required this.content,
    this.uri,
  });
}
