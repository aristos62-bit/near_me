import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:go_router/go_router.dart';
import '../config/feature_flags.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';
import '../utils/app_messenger.dart';
import '../utils/error_messages.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../../../shared/utils/image_utils.dart';
import '../../../shared/widgets/chat_recipient_picker.dart';
import '../../../shared/widgets/incoming_share_sheet.dart';
import '../../data/local/database.dart';
import '../../features/settings/providers/app_settings_provider.dart';

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

      final chats = (await _loadChats(ref)).where((c) => c.chatId != null).toList();
      if (!context.mounted) return;
      if (chats.isEmpty) {
        AppMessenger.showInfo(context,
            ErrorMessages.get('chat/no-chats-forward', greek));
        return;
      }

      final isMedia = payload.type != 'text' && payload.type != 'url';
      if (isMedia) {
        final path = payload.content;
        final file = File(path);
        if (!file.existsSync()) {
          _deleteTmp(path);
          AppMessenger.showError(context,
              ErrorMessages.get('share/media-load-failed', greek));
          return;
        }

        final videoThumb = (payload.type == 'video')
            ? await _generateVideoThumb(path)
            : null;
        if (!context.mounted) {
          _deleteTmp(path);
          return;
        }

        final confirmed = await showIncomingShareSheet(context,
            type: payload.type, content: path, filePath: path,
            thumbnailBytes: videoThumb);
        if (confirmed != true || !context.mounted) {
          _deleteTmp(path);
          return;
        }

        final targetChatId = await showChatRecipientPicker(context, chats,
            blurEnabled: _blurEnabled(ref));
        if (targetChatId == null || !context.mounted) {
          _deleteTmp(path);
          return;
        }

        // Ανέβασμα με οπτική πρόοδο: ο χρήστης πάει στη συνομιλία και βλέπει
        // spinner στο input bar όσο τρέχει το upload (όλα τα media types).
        ref.read(incomingShareUploadProvider.notifier).begin(targetChatId);
        if (context.mounted) {
          context.go('/chat/$targetChatId');
        }
        final ok = await _sendMedia(ref, targetChatId, payload,
            thumbnailBytes: videoThumb);
        ref.read(incomingShareUploadProvider.notifier).end();
        _deleteTmp(path);
        if (!context.mounted) return;
        if (!ok) {
          final state = ref.read(chatActionsProvider);
          AppMessenger.showError(context, ErrorMessages.get(
              state.errorMessage ?? 'chat/forward-failed', greek));
          return;
        }
        // success: το μήνυμα εμφανίζεται ήδη στη συνομιλία (χωρίς toast).
        return;
      }

      final confirmed = await showIncomingShareSheet(context,
          type: payload.type, content: payload.content);
      if (confirmed != true || !context.mounted) return;

      final targetChatId = await showChatRecipientPicker(context, chats,
          blurEnabled: _blurEnabled(ref));
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

  /// Δημιουργεί το thumbnail ενός τοπικού video (fail-open → null). Το
  /// αποτέλεσμα χρησιμοποιείται για preview στο sheet και reuse στο send.
  static Future<Uint8List?> _generateVideoThumb(String path) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 70,
      );
    } catch (e) {
      DebugConfig.warn('IncomingShare: thumbnail generation failed', data: e);
      return null;
    }
  }

  /// Αποστέλλει το shared media μέσω του κατάλληλου μονοπατιού του
  /// sendMediaMessage. Το native στέλνει `image` για κάθε εικόνα/GIF·
  /// αν το αρχείο τελειώνει σε .gif προωθείται ως πραγματικό GIF
  /// (raw bytes, χωρίς stripExif για να μη σπάσει το animation).
  /// Επιστρέφει false σε σφάλμα (ο provider κρατά το errorMessage για προβολή).
  static Future<bool> _sendMedia(
      WidgetRef ref, String chatId, IncomingSharePayload payload,
      {Uint8List? thumbnailBytes}) async {
    final path = payload.content;
    try {
      switch (payload.type) {
        case 'video':
          return await ref.read(chatActionsProvider.notifier)
              .sendMediaMessage(chatId,
              content: '', type: 'video',
              videoPath: path,
              thumbnailBytes: thumbnailBytes);
        case 'image':
          final bytes = await File(path).readAsBytes();
          final isGif = path.toLowerCase().endsWith('.gif');
          return await ref.read(chatActionsProvider.notifier)
              .sendMediaMessage(chatId,
              content: '',
              type: isGif ? 'gif' : 'image',
              imageBytes: isGif ? bytes : await ImageUtils.stripExif(bytes));
        case 'audio':
          final bytes = await File(path).readAsBytes();
          return await ref.read(chatActionsProvider.notifier)
              .sendMediaMessage(chatId,
              content: '', type: 'audio',
              audioBytes: bytes);
        default:
          return false;
      }
    } catch (e) {
      DebugConfig.error('IncomingShare: media send failed', data: e);
      return false;
    }
  }

  /// Best-effort διαγραφή του temp media μετά τη χρήση (απόρριψη, dismiss,
  /// send επιτυχές ή όχι) ώστε να μην αφήνουμε orphan αρχεία στο cache.
  static void _deleteTmp(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      DebugConfig.warn('IncomingShare: temp cleanup failed', data: e);
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

  static bool _blurEnabled(WidgetRef ref) {
    return ref.read(appSettingsProvider
        .select((a) => a.value?.blurExplicitEnabled ?? FeatureFlags.blurExplicitByDefault));
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

/// Mini provider: κρατάει το chatId όπου τρέχει το media upload του
/// IncomingShare, ώστε ο ChatInputBar της συνομιλίας να δείξει spinner
/// (ίδια συμπεριφορά με το κανονικό send media). Μηδενίζεται πάντα στο τέλος.
final incomingShareUploadProvider =
    NotifierProvider<IncomingShareUploadNotifier, String?>(
  IncomingShareUploadNotifier.new,
);

class IncomingShareUploadNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void begin(String chatId) => state = chatId;

  void end() => state = null;
}
