import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/connectivity_guard.dart';
import '../../../data/local/database.dart';
import '../../../repositories/chat_repository.dart';
import '../../../repositories/chat_repository_impl.dart';
import '../../../repositories/group_search_repository.dart';
import 'package:video_player/video_player.dart';

final _chatDocSnapCaches = <String, DocumentSnapshot?>{};

final chatDocProvider = StreamProvider.autoDispose.family<DocumentSnapshot?, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'chatDocProvider created for chat: $chatId');
  ref.onDispose(() {
    DebugConfig.log(DebugConfig.providerDispose, 'chatDocProvider disposed for chat: $chatId');
    _chatDocSnapCaches.remove(chatId);
    _participantUidCaches.remove(chatId);
  });
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.chatDocStream(chatId).map((snap) {
    if (snap == null) return null;
    final previous = _chatDocSnapCaches[chatId];
    DebugConfig.log(DebugConfig.firestoreStream,
        'chatDocProvider emit: $chatId exists=${snap.exists} pending=${snap.metadata.hasPendingWrites}');
    if (previous != null && snap.metadata.hasPendingWrites) {
      DebugConfig.log(DebugConfig.firestoreStream,
          'chatDocProvider suppressed (pending): $chatId');
      return previous;
    }
    if (previous != null && snap.exists && previous.exists) {
      final prevData = previous.data();
      final currData = snap.data();
      if (const DeepCollectionEquality().equals(prevData, currData)) {
        DebugConfig.log(DebugConfig.firestoreStream,
            'chatDocProvider suppressed: $chatId data unchanged');
        return previous;
      }
    }
    _chatDocSnapCaches[chatId] = snap;
    return snap;
  });
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'chatRepositoryProvider created');
  return ChatRepositoryImpl();
});

final chatsProvider = StreamProvider<List<ChatCacheTableData>>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'chatsProvider created (StreamProvider)');
  final chatRepo = ref.watch(chatRepositoryProvider);
  final stream = chatRepo.streamChats();
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'chatsProvider disposed'));
  return stream;
});

final messagesProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'messagesProvider created for chat: $chatId');
  final chatRepo = ref.watch(chatRepositoryProvider);
  ref.onDispose(() {
    DebugConfig.log(DebugConfig.providerDispose, 'messagesProvider disposed for chat: $chatId');
    chatRepo.clearMessageCaches(chatId);
  });
  final stream = chatRepo.messagesStream(chatId).map((messages) {
    DebugConfig.log(DebugConfig.chatStream, 'messagesProvider emitted ${messages.length} messages for chat=$chatId');
    return messages;
  });
  return stream;
});

// --- ΝΕΟ: pagination για παλιότερα μηνύματα (companion του _kLiveMessageWindow=50 στο repository) ---
class OlderMessagesState {
  final List<Map<String, dynamic>> messages; // ascending, ΠΡΙΝ τα live-window μηνύματα
  final bool isLoading;
  final bool hasMore;

  const OlderMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  OlderMessagesState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    bool? hasMore,
  }) {
    return OlderMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// Απλός Notifier (όχι family, όχι autoDispose) — ίδιο pattern με ChatActionsNotifier
// παρακάτω σε αυτό το αρχείο. Κρατάει state ανά chatId σε ένα Map, ώστε να
// αποφύγουμε τις (μη υποστηριζόμενες πλέον στο Riverpod 3) family-notifier classes.
class OlderMessagesByChat extends Notifier<Map<String, OlderMessagesState>> {
  @override
  Map<String, OlderMessagesState> build() {
    DebugConfig.log(DebugConfig.providerCreate, 'OlderMessagesByChat built');
    return const {};
  }

  OlderMessagesState stateFor(String chatId) =>
      state[chatId] ?? const OlderMessagesState();

  /// Φορτώνει την επόμενη "σελίδα" παλιότερων μηνυμάτων, πριν το [beforeTimestamp].
  Future<void> loadMore(String chatId, DateTime beforeTimestamp) async {
    final current = stateFor(chatId);
    if (current.isLoading || !current.hasMore) return;
    if (!await ConnectivityGuard.isOnline()) return;

    DebugConfig.log(DebugConfig.repositoryCall, 'OlderMessagesByChat: loadMore chat=$chatId before=$beforeTimestamp');
    state = {...state, chatId: current.copyWith(isLoading: true)};
    try {
      final repo = ref.read(chatRepositoryProvider);
      final older = await repo.fetchOlderMessages(chatId, beforeTimestamp: beforeTimestamp, limit: 50);
      final base = stateFor(chatId);
      final updated = base.copyWith(
        messages: [...older, ...base.messages],
        isLoading: false,
        hasMore: older.length >= 50,
      );
      state = {...state, chatId: updated};
      DebugConfig.log(DebugConfig.repositoryResult,
          'OlderMessagesByChat: loaded ${older.length} older msgs, hasMore=${updated.hasMore} chat=$chatId');
    } catch (e, s) {
      DebugConfig.error('OlderMessagesByChat: loadMore failed', data: e, exception: s);
      state = {...state, chatId: stateFor(chatId).copyWith(isLoading: false)};
    }
  }
}

final olderMessagesByChatProvider =
NotifierProvider<OlderMessagesByChat, Map<String, OlderMessagesState>>(
  OlderMessagesByChat.new,
);

/// Ενώνει τα παλιότερα (paginated) μηνύματα με το live window (τελευταία 50)
/// σε μία λίστα, αύξουσα κατά timestamp, χωρίς διπλότυπα.
final combinedMessagesProvider = Provider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, chatId) {
  final live = ref.watch(messagesProvider(chatId)).value ?? const <Map<String, dynamic>>[];
  final older = ref.watch(olderMessagesByChatProvider.select((m) => m[chatId]?.messages ?? const <Map<String, dynamic>>[]));
  if (older.isEmpty) return live;
  final liveIds = live.map((m) => m['id']).toSet();
  return [
    ...older.where((m) => !liveIds.contains(m['id'])),
    ...live,
  ];
});
// --- ΤΕΛΟΣ ΝΕΟΥ ΚΩΔΙΚΑ ---

final _participantUidCaches = <String, List<String>>{};

final participantUidsProvider = Provider.family<List<String>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'participantUidsProvider created (derived) for chat: $chatId');
  final chatDocAsync = ref.watch(chatDocProvider(chatId));
  final snap = chatDocAsync.asData?.value;
  if (snap == null || !snap.exists) return [];
  final data = snap.data() as Map<String, dynamic>?;
  if (data == null) return [];
  final participants = List<String>.from(data['participants'] ?? []);
  final activeMap = (data['participantIsActive'] as Map?) ?? {};
  final result = participants.where((p) => activeMap[p] != false).toList();
  final cached = _participantUidCaches[chatId];
  if (cached != null && const DeepCollectionEquality().equals(cached, result)) {
    DebugConfig.log(DebugConfig.providerCreate,
        'participantUidsProvider cache hit: $chatId');
    return cached;
  }
  _participantUidCaches[chatId] = result;
  return result;
});

final groupPermissionsProvider = FutureProvider.family<GroupPermissionsInfo, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'groupPermissionsProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'groupPermissionsProvider disposed for chat: $chatId'));
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getPermissionsInfo(chatId);
});

final activeInvitesProvider = FutureProvider.autoDispose.family<List<InviteInfo>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'activeInvitesProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'activeInvitesProvider disposed for chat: $chatId'));
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getActiveInvites(chatId);
});

final groupSearchRepositoryProvider = Provider<GroupSearchRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'groupSearchRepositoryProvider created');
  return FirestoreGroupSearchRepository();
});

enum ChatActionStatus { idle, loading, success, error }

class ChatActionState {
  final ChatActionStatus status;
  final String? errorMessage;
  final String? createdChatId;
  const ChatActionState({
    this.status = ChatActionStatus.idle,
    this.errorMessage,
    this.createdChatId,
  });
}

class ChatActionsNotifier extends Notifier<ChatActionState> {
  @override
  ChatActionState build() {
    DebugConfig.log(DebugConfig.providerCreate, 'ChatActionsNotifier built');
    return const ChatActionState();
  }

  ChatRepository get _chatRepo => ref.read(chatRepositoryProvider);

  Future<bool> _checkOnline() async {
    if (!await ConnectivityGuard.isOnline()) {
      state = const ChatActionState(
          status: ChatActionStatus.error, errorMessage: 'network/no-connectivity');
      return false;
    }
    return true;
  }

  /// Πύλη ρυθμού πριν από κάθε αποστολή μηνύματος (text/media/forward/share).
  /// Fail-open: αν η ίδια η CF αποτύχει (δίκτυο, cold start), επιτρέπουμε την
  /// αποστολή — ίδιο best-effort σκεπτικό με το search _checkRateLimit().
  /// ΕΠΙΣΤΡΕΦΕΙ ΜΟΝΟ bool — ΔΕΝ αλλάζει state (ο caller θέτει το error), ώστε
  /// να αποφευχθεί διπλό state-write σε διαφορετικά επίπεδα.
  Future<bool> _checkMessageRateLimit() async {
    try {
      if (!await ConnectivityGuard.isOnline()) {
        DebugConfig.log(DebugConfig.networkConnectivity,
            'ChatActions._checkMessageRateLimit: no connectivity — skip CF, fail-open');
        return true;
      }
    } catch (_) {}
    final cfSw = Stopwatch()..start();
    try {
      DebugConfig.log(DebugConfig.cloudFunctions,
          'ChatActions: calling checkMessageRateLimit');
      final cfCall = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('checkMessageRateLimit')
          .call();
      // Κατανάλωση όψιμου σφάλματος του "εγκαταλελειμμένου" future μετά το
      // timeout (ίδιο pattern με το _withAuthTimeout / search).
      unawaited(cfCall.then<void>((_) {},
          onError: (Object e) => DebugConfig.warn(
              'checkMessageRateLimit: late completion after timeout',
              data: e)));
      await cfCall.timeout(const Duration(seconds: 4));
      DebugConfig.log(DebugConfig.rateLimit,
          'ChatActions: message rate limit OK (${cfSw.elapsedMilliseconds}ms)');
      return true;
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.replaceFirst('functions/', '');
      if (code == 'resource-exhausted') {
        DebugConfig.log(DebugConfig.rateLimit,
            'ChatActions: message rate limited (${cfSw.elapsedMilliseconds}ms)');
        return false;
      }
      DebugConfig.warn(
          'ChatActions: message rate limit check failed (fail-open, ${cfSw.elapsedMilliseconds}ms)',
          data: e);
      return true;
    } catch (e) {
      DebugConfig.warn(
          'ChatActions: message rate limit check failed (fail-open, ${cfSw.elapsedMilliseconds}ms)',
          data: e);
      return true;
    }
  }

  Future<String?> createChat(String otherUid) async {
    if (!await _checkOnline()) return null;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createChat with $otherUid');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.createChat(otherUid);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: createChat success chatId=$chatId');
      state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
      ref.invalidate(chatsProvider);
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return null;
    }
  }

  Future<bool> sendMessage(String chatId, String content, {Map<String, dynamic>? replyTo}) async {
    if (!await _checkOnline()) return false;
    if (!await _checkMessageRateLimit()) {
      state = const ChatActionState(
          status: ChatActionStatus.error, errorMessage: 'chat/message-rate-limited');
      return false;
    }
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: sendMessage chat=$chatId replyTo=${replyTo?['messageId']}');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.sendMessage(chatId, content, replyTo: replyTo);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: sendMessage success');
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: sendMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> sendMediaMessage(String chatId, {
    required String content,
    required String type,
    Map<String, dynamic>? replyTo,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
    String? videoPath,
    Uint8List? thumbnailBytes,
    String? forwardThumbnailUrl,
    int? duration,
  }) async {
    if (!await _checkOnline()) return false;
    if (!await _checkMessageRateLimit()) {
      state = const ChatActionState(
          status: ChatActionStatus.error, errorMessage: 'chat/message-rate-limited');
      return false;
    }
    DebugConfig.log(DebugConfig.repositoryCall,
        'ChatActions: sendMediaMessage chat=$chatId type=$type replyTo=${replyTo?['messageId']}');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.sendMediaMessage(chatId, content: content, type: type, replyTo: replyTo, imageBytes: imageBytes, audioBytes: audioBytes, videoPath: videoPath, thumbnailBytes: thumbnailBytes, forwardThumbnailUrl: forwardThumbnailUrl, duration: duration);
      DebugConfig.log(DebugConfig.repositoryResult,
          'ChatActions: sendMediaMessage success');
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: sendMediaMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error,
          errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<void> markAsRead(String chatId, {bool isGroupChat = false}) async {
    try {
      await _chatRepo.markAsRead(chatId, isGroupChat: isGroupChat);
    } catch (e) {
      DebugConfig.warn('ChatActions: markAsRead failed', data: e);
    }
  }

  Future<void> deleteChat(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deleteChat chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deleteChat(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) {
      DebugConfig.error('ChatActions: deleteChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> approveDeleteChat(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: approveDeleteChat chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.approveDeleteChat(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) {
      DebugConfig.error('ChatActions: approveDeleteChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> rejectDeleteChat(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: rejectDeleteChat chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.rejectDeleteChat(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: rejectDeleteChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> cancelDeleteRequest(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: cancelDeleteRequest chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.cancelDeleteRequest(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: cancelDeleteRequest failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> deleteChatForMe(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deleteChatForMe chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deleteChatForMe(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) {
      DebugConfig.error('ChatActions: deleteChatForMe failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> deleteGroup(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deleteGroup chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deleteGroup(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) {
      DebugConfig.error('ChatActions: deleteGroup failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<bool> updateMessageExpiry(String chatId, String value) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateMessageExpiry chat=$chatId value=$value');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateMessageExpiry(chatId, value);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateMessageExpiry failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<void> clearMessages(String chatId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: clearMessages chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.clearMessages(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: clearMessages failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> reactToMessage(String chatId, String messageId, String emoji) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.chatReactions, 'ChatActions: reactToMessage chat=$chatId msg=$messageId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.addReaction(chatId, messageId, emoji);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: reactToMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<void> removeReaction(String chatId, String messageId) async {
    if (!await _checkOnline()) return;
    DebugConfig.log(DebugConfig.chatReactions, 'ChatActions: removeReaction chat=$chatId msg=$messageId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeReaction(chatId, messageId);
      state = const ChatActionState(status: ChatActionStatus.success);
    } catch (e, s) {
      DebugConfig.error('ChatActions: removeReaction failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
    }
  }

  Future<bool> editMessage(String chatId, String messageId, String newContent) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: editMessage chat=$chatId msg=$messageId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.editMessage(chatId, messageId, newContent);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: editMessage success');
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(messagesProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: editMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> deleteMessage(String chatId, String messageId) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deleteMessage chat=$chatId msg=$messageId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deleteMessage(chatId, messageId);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: deleteMessage success');
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(messagesProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: deleteMessage failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  void reset() => state = const ChatActionState();

  // --- Group Chat Actions ---

  Future<String?> createGroupChat(List<String> participantUids, {String? groupName, bool isPublic = false, String? description, List<String>? tags, String? city}) async {
    if (!await _checkOnline()) return null;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createGroupChat (public=$isPublic)');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.createGroupChat(participantUids, groupName: groupName, isPublic: isPublic, description: description, tags: tags, city: city);
      state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
      ref.invalidate(chatsProvider);
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createGroupChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return null;
    }
  }

  Future<bool> addParticipant(String chatId, String newUid) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: addParticipant chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.addParticipant(chatId, newUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(participantUidsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: addParticipant failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> removeParticipant(String chatId, String targetUid) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: removeParticipant chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeParticipant(chatId, targetUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(participantUidsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: removeParticipant failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> updateGroupName(String chatId, String name) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateGroupName chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateGroupName(chatId, name);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateGroupName failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> updateGroupAvatar(String chatId, dynamic image) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateGroupAvatar chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateGroupAvatar(chatId, image);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateGroupAvatar failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> removeGroupAvatar(String chatId) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: removeGroupAvatar chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeGroupAvatar(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: removeGroupAvatar failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> updateMaxParticipants(String chatId, int newMax) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateMaxParticipants chat=$chatId -> $newMax');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateMaxParticipants(chatId, newMax);
      state = const ChatActionState(status: ChatActionStatus.success);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateMaxParticipants failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> updateParticipantRole(String chatId, String uid, String newRole) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updateParticipantRole chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateParticipantRole(chatId, uid, newRole);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(groupPermissionsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updateParticipantRole failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> updatePermissionOverride(String chatId, String uid, GroupPermission permission, bool value) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: updatePermissionOverride chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updatePermissionOverride(chatId, uid, permission, value);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(groupPermissionsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: updatePermissionOverride failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<bool> deletePermissionOverrides(String chatId, String targetUid) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: deletePermissionOverrides chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.deletePermissionOverrides(chatId, targetUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(groupPermissionsProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: deletePermissionOverrides failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }

  Future<String?> createInviteLink(String chatId, {Duration expiresIn = const Duration(days: 7), int? maxUses}) async {
    if (!await _checkOnline()) return null;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: createInviteLink chat=$chatId');
    try {
      final token = await _chatRepo.createInviteLink(chatId, expiresIn: expiresIn, maxUses: maxUses);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: createInviteLink success token=$token');
      ref.invalidate(activeInvitesProvider(chatId));
      return token;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createInviteLink failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return null;
    }
  }

  Future<String?> redeemInviteLink(String token) async {
    if (!await _checkOnline()) return null;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: redeemInviteLink');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.redeemInviteLink(token);
      if (chatId != null) {
        state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
        ref.invalidate(chatsProvider);
      } else {
        state = const ChatActionState(status: ChatActionStatus.success);
      }
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: redeemInviteLink failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return null;
    }
  }

  Future<InviteInfo?> getInviteInfo(String token) async {
    if (!await _checkOnline()) return null;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: getInviteInfo');
    try {
      final info = await _chatRepo.getInviteInfo(token);
      DebugConfig.log(DebugConfig.repositoryResult, 'ChatActions: getInviteInfo -> ${info?.groupName}');
      return info;
    } catch (e, s) {
      DebugConfig.error('ChatActions: getInviteInfo failed', data: e, exception: s);
      return null;
    }
  }

  Future<bool> revokeInvite(String chatId, String inviteId) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: revokeInvite chat=$chatId');
    try {
      await _chatRepo.revokeInvite(chatId, inviteId);
      ref.invalidate(activeInvitesProvider(chatId));
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: revokeInvite failed', data: e, exception: s);
      return false;
    }
  }

  Future<bool> joinPublicGroup(String chatId) async {
    if (!await _checkOnline()) return false;
    DebugConfig.log(DebugConfig.repositoryCall, 'ChatActions: joinPublicGroup chat=$chatId');
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.joinPublicGroup(chatId);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
      return true;
    } catch (e, s) {
      DebugConfig.error('ChatActions: joinPublicGroup failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: AppException.toFriendlyMessage(e, domain: 'chat'));
      return false;
    }
  }
}

final chatActionsProvider = NotifierProvider<ChatActionsNotifier, ChatActionState>(
  ChatActionsNotifier.new,
);

class ReplyToMessageNotifier extends Notifier<Map<String, Map<String, dynamic>?>> {
  @override
  Map<String, Map<String, dynamic>?> build() {
    DebugConfig.log(DebugConfig.providerCreate, 'ReplyToMessageNotifier built');
    return const {};
  }

  void setReply(String chatId, Map<String, dynamic>? msg) {
    final next = Map<String, Map<String, dynamic>?>.from(state);
    next[chatId] = msg;
    state = next;
    DebugConfig.log(DebugConfig.chatReply, 'reply set for chat=$chatId msg=${msg?['id']}');
  }

  void clear(String chatId) {
    if (!state.containsKey(chatId)) return;
    final next = Map<String, Map<String, dynamic>?>.from(state);
    next.remove(chatId);
    state = next;
    DebugConfig.log(DebugConfig.chatReply, 'reply cleared for chat=$chatId');
  }
}

final replyToMessageProvider = NotifierProvider<ReplyToMessageNotifier, Map<String, Map<String, dynamic>?>>(
  ReplyToMessageNotifier.new,
);

class PendingPrivateReply {
  final String targetChatId;
  final Map<String, dynamic> quotedMessage;
  final String? senderNicknameHint;
  const PendingPrivateReply({
    required this.targetChatId,
    required this.quotedMessage,
    this.senderNicknameHint,
  });
}

/// Κρατάει προσωρινά ένα quoted μήνυμα από ομαδικό chat μέχρι να ανοίξει/
/// δημιουργηθεί το προσωπικό chat και το καταναλώσει το δικό του ChatInputBar.
/// Global provider, αλλά αυτο-ασφαλισμένο: consumeFor() επιστρέφει κάτι μόνο
/// αν το targetChatId ταιριάζει, οπότε δεν υπάρχει κίνδυνος leak σε άσχετο chat.
class PendingPrivateReplyNotifier extends Notifier<PendingPrivateReply?> {
  @override
  PendingPrivateReply? build() => null;

  void set(String targetChatId, Map<String, dynamic> quotedMessage, {String? senderNicknameHint}) {
    DebugConfig.log(DebugConfig.chatReply,
        'pendingPrivateReply: set target=$targetChatId msgId=${quotedMessage['id']} '
            'senderNicknameHint=$senderNicknameHint');
    state = PendingPrivateReply(
      targetChatId: targetChatId,
      quotedMessage: quotedMessage,
      senderNicknameHint: senderNicknameHint,
    );
  }

  PendingPrivateReply? consumeFor(String chatId) {
    final current = state;
    if (current == null || current.targetChatId != chatId) return null;
    DebugConfig.log(DebugConfig.chatReply,
        'pendingPrivateReply: consumed for chat=$chatId msgId=${current.quotedMessage['id']}');
    state = null;
    return current;
  }
}

final pendingPrivateReplyProvider =
    NotifierProvider<PendingPrivateReplyNotifier, PendingPrivateReply?>(
  PendingPrivateReplyNotifier.new,
);

class EditingMessageNotifier extends Notifier<Map<String, Map<String, dynamic>?>> {
  @override
  Map<String, Map<String, dynamic>?> build() {
    DebugConfig.log(DebugConfig.providerCreate, 'EditingMessageNotifier built');
    return const {};
  }

  void setEdit(String chatId, Map<String, dynamic>? msg) {
    final next = Map<String, Map<String, dynamic>?>.from(state);
    next[chatId] = msg;
    state = next;
    DebugConfig.log(DebugConfig.chatReply, 'edit set for chat=$chatId msg=${msg?['id']}');
  }

  void clear(String chatId) {
    if (!state.containsKey(chatId)) return;
    final next = Map<String, Map<String, dynamic>?>.from(state);
    next.remove(chatId);
    state = next;
    DebugConfig.log(DebugConfig.chatReply, 'edit cleared for chat=$chatId');
  }
}

final editingMessageProvider = NotifierProvider<EditingMessageNotifier, Map<String, Map<String, dynamic>?>>(
  EditingMessageNotifier.new,
);

class VideoPlaybackInfo {
  final VideoPlayerController? controller;
  final String? loadingUrl;
  const VideoPlaybackInfo({this.controller, this.loadingUrl});
}

/// Κεντρική διαχείριση του ενεργού video player ανά chat. Το `ChatScreen`
/// ΔΕΝ ξαναδημιουργεί πια το ChatMessagesList σε play/fail (αυτό σκότωνε το
/// fix5 width-cache) — ο controller ζει εδώ και τα video bubbles τον
/// διαβάζουν μέσω `ref.watch`/`ref.listen` (Session 232).
class VideoPlaybackNotifier extends Notifier<Map<String, VideoPlaybackInfo>> {
  @override
  Map<String, VideoPlaybackInfo> build() {
    DebugConfig.log(DebugConfig.providerCreate, 'VideoPlaybackNotifier built');
    return const {};
  }

  Future<void> play(String chatId, String url) async {
    _disposeController(chatId);
    final loading = Map<String, VideoPlaybackInfo>.from(state);
    loading[chatId] = VideoPlaybackInfo(loadingUrl: url);
    state = loading;
    DebugConfig.log(DebugConfig.chatVideo,
        'VideoPlayback: loading chat=$chatId url=$url');

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setVolume(0.0);
      final next = Map<String, VideoPlaybackInfo>.from(state);
      next[chatId] = VideoPlaybackInfo(controller: controller);
      state = next;
      DebugConfig.log(DebugConfig.chatVideo,
          'VideoPlayback: ready chat=$chatId url=$url');
    } catch (e, s) {
      DebugConfig.error('VideoPlayback: init failed', data: e, exception: s);
      final next = Map<String, VideoPlaybackInfo>.from(state);
      next[chatId] = const VideoPlaybackInfo();
      state = next;
    }
  }

  void stop(String chatId) {
    if (!state.containsKey(chatId)) return;
    _disposeController(chatId);
    final next = Map<String, VideoPlaybackInfo>.from(state);
    next.remove(chatId);
    state = next;
    DebugConfig.log(DebugConfig.chatVideo, 'VideoPlayback: stop chat=$chatId');
  }

  void _disposeController(String chatId) {
    final current = state[chatId];
    if (current?.controller != null) {
      current!.controller!.pause();
      current.controller!.dispose();
      DebugConfig.log(DebugConfig.chatVideo,
          'VideoPlayback: disposed controller chat=$chatId');
    }
  }
}

final videoPlaybackProvider =
    NotifierProvider<VideoPlaybackNotifier, Map<String, VideoPlaybackInfo>>(
  VideoPlaybackNotifier.new,
);
