part of 'chat_repository_impl.dart';

mixin GroupChatMixin {
  FirebaseFirestore get firestore;
  FirebaseAuth get auth;
  AppDatabase get db;
  Future<void> removeChatCache(String chatId);
  Future<void> updateChatCache(String chatId, {DateTime? lastMessageAt, bool? hasUnread, String? otherNickname, String? otherAvatarUrl, String? lastMessage, String? lastMessageSender, String? lastMessageType, int? unreadCount, String? groupName, String? groupAvatarUrl});

  String get _currentUid {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('auth_required', 'Δεν υπάρχει χρήστης / No user');
    return user.uid;
  }

  Future<void> _requirePermission(String chatId, GroupPermission permission) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw AppException.auth('permission', 'Δεν υπάρχει χρήστης / No user');
    final chatDoc = await firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) throw AppException.firestore('permission', 'Η συνομιλία δεν βρέθηκε / Chat not found');
    final data = chatDoc.data()!;
    final roles = Map<String, String>.from(data['participantRoles'] ?? {});
    final overrides = Map<String, Map<String, bool>>.from(
      (data['permissionOverrides'] as Map?)?.map(
        (k, v) => MapEntry(k, Map<String, bool>.from(v as Map)),
      ) ?? {},
    );
    if (!_hasPermission(uid, roles, overrides, permission)) {
      throw AppException.auth(permission.name, 'Δεν έχεις δικαίωμα για αυτή την ενέργεια / You do not have permission for this action');
    }
  }

  bool _hasPermission(String uid, Map<String, String> roles, Map<String, Map<String, bool>> overrides, GroupPermission p) {
    return GroupPermissionsInfo(roles: roles, overrides: overrides).hasPermission(uid, p);
  }

  void _enforceParticipantLimit(int currentCount, int maxAllowed) {
    if (currentCount > maxAllowed) {
      throw AppException.auth('max_participants',
          'Το μέγιστο όριο συμμετεχόντων είναι $maxAllowed / Maximum participant limit is $maxAllowed');
    }
  }

  AppException _cfErrorToAppException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'functions/failed-precondition':
        return AppException.auth('add_participant',
            'Το άτομο έχει αποκλειστεί από συμμετέχοντα / Blocked by a participant');
      case 'functions/not-found':
        return AppException.firestore('add_participant',
            'Η συνομιλία δεν βρέθηκε / Chat not found');
      case 'functions/already-exists':
        return AppException.auth('add_participant',
            'Το άτομο είναι ήδη στην ομάδα / Already in group');
      case 'functions/resource-exhausted':
        return AppException.auth('add_participant',
            'Η ομάδα είναι γεμάτη / Group is full');
      case 'functions/permission-denied':
        return AppException.auth('add_participant',
            'Δεν έχεις δικαίωμα για αυτή την ενέργεια / You do not have permission for this action');
      case 'functions/unauthenticated':
        return AppException.auth('add_participant',
            'Απαιτείται σύνδεση / Authentication required');
      default:
        return AppException.firestore('add_participant',
            'Αποτυχία προσθήκης / Failed to add participant');
    }
  }

  String _defaultGroupName(Map<String, String> nicknames) {
    final names = nicknames.values.toList();
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3} ακόμα';
  }

  Future<void> _sendSystemMessage(String chatId, String action, String actorUid, [List<String>? targets]) async {
    if (actorUid.isEmpty) return;
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        DebugConfig.warn('_sendSystemMessage: chat doc not found $chatId');
        return;
      }
      final data = chatDoc.data()!;
      final groupName = data['groupName'] as String?;
      final nicknames = (data['participantNicknames'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String? ?? k)) ??
          <String, String>{};

      final actorNickname = nicknames[actorUid] ?? actorUid;
      final targetNicknames =
          targets?.map((t) => nicknames[t] ?? t).toList() ?? [];

      final formatted = SystemMessageFormatter.format(
        action: action,
        actorNickname: actorNickname,
        targetNicknames: targetNicknames,
        groupName: groupName,
      );

      await firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': actorUid,
        'content': formatted.el,
        'contentEn': formatted.en,
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
      DebugConfig.log(DebugConfig.chatStream,
          '_sendSystemMessage: action=$action actor=$actorNickname chat=$chatId');
    } catch (e) {
      DebugConfig.warn('_sendSystemMessage failed', data: e);
    }
  }

  Future<void> _logAudit(String chatId, String action, String actorUid, {String? targetUid, Map<String, dynamic>? details}) async {
    try {
      await firestore.collection('chats').doc(chatId).collection('audit_log').add({
        'action': action,
        'actorUid': actorUid,
        // ignore: use_null_aware_elements
        if (targetUid != null) 'targetUid': targetUid,
        // ignore: use_null_aware_elements
        if (details != null) 'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
      DebugConfig.log(DebugConfig.repositoryResult, '_logAudit: $action in $chatId by $actorUid');
    } catch (e) {
      DebugConfig.warn('_logAudit failed', data: e);
    }
  }

  Future<void> _syncGroupChatToCache(String chatId, Map<String, dynamic> data) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    var rows = await (db.select(db.chatCacheTable)
      ..where((t) => t.chatId.equals(chatId))
    ).get();

    if (rows.length > 1) {
      await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      DebugConfig.log(DebugConfig.databaseLocal, '_syncGroupChatToCache: cleaned ${rows.length} duplicates chatId=$chatId');
      rows = [];
    }

    final groupName = data['groupName'] as String?;
    final groupAvatarUrl = data['groupAvatarUrl'] as String?;
    final groupCreatedBy = data['createdBy'] as String?;
    final participants = List<String>.from(data['participants'] ?? []);
    final nicknamesRaw = data['participantNicknames'] as Map<String, dynamic>?;
    DebugConfig.log(DebugConfig.repositoryResult,
        '_syncGroupChatToCache: chat=$chatId groupName=$groupName '
        'participants=${participants.length} '
        'hasParticipantNicknames=${data.containsKey('participantNicknames')} '
        'nicknameEntries=${nicknamesRaw?.length ?? 0} '
        'createdBy=$groupCreatedBy');
    final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
    final lastMessageBy = data['lastMessageBy'] as String?;
    final lastMessageType = data['lastMessageType'] as String? ?? 'text';
    final encryptedLastMessage = data['lastMessage'] as String?;
    final lastRead = data['lastReadTimestamps']?[uid]?.toDate() ?? DateTime(2020);

    int unreadCount = 0;
    if (lastMessageBy != null && lastMessageBy != uid) {
      try {
        final allCount = await firestore
            .collection('chats').doc(chatId).collection('messages')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(lastRead))
            .count().get();
        final ownCount = await firestore
            .collection('chats').doc(chatId).collection('messages')
            .where('senderId', isEqualTo: uid)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(lastRead))
            .count().get();
        unreadCount = (allCount.count ?? 0) - (ownCount.count ?? 0);
      } catch (_) {
        unreadCount = rows.isNotEmpty ? rows.first.unreadCount + 1 : 1;
      }
    }

    final isUnread = unreadCount > 0;
    final lastMessageSender = lastMessageBy != null
        ? (lastMessageBy == uid ? 'me' : 'other')
        : null;

    String? decryptedLastMessage;
    if (encryptedLastMessage != null && lastMessageType != 'system') {
      try {
        final key = await EncryptionUtils.getKeyOrDerive(chatId);
        decryptedLastMessage = EncryptionUtils.decryptMessage(key, encryptedLastMessage);
      } catch (_) { /* system messages stay as-is */ }
    }

    final participantUidsStr = participants.isNotEmpty ? participants.join(',') : null;

    if (rows.isNotEmpty) {
      final existing = rows.first;
      await (db.update(db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
          .write(ChatCacheTableCompanion(
            lastMessageAt: Value(lastMessageAt ?? existing.lastMessageAt),
            lastMessage: decryptedLastMessage != null
                ? Value(decryptedLastMessage) : Value.absent(),
            lastMessageSender: lastMessageSender != null
                ? Value(lastMessageSender) : Value.absent(),
            lastMessageType: Value(lastMessageType),
            hasUnread: Value(isUnread),
            unreadCount: Value(unreadCount),
            groupName: Value(groupName),
            groupAvatarUrl: groupAvatarUrl != null ? Value(groupAvatarUrl) : Value.absent(),
            participantCount: Value(participants.length),
            participantUids: participantUidsStr != null ? Value(participantUidsStr) : const Value(null),
            isGroupChat: const Value(true),
            groupCreatedBy: groupCreatedBy != null ? Value(groupCreatedBy) : Value.absent(),
          ));
    } else {
      await db.into(db.chatCacheTable).insert(
        ChatCacheTableCompanion.insert(
          chatId: Value(chatId),
          ownerUid: Value(uid),
          otherUid: const Value(null),
          otherNickname: const Value(null),
          otherAvatarUrl: const Value(null),
          groupAvatarUrl: groupAvatarUrl != null ? Value(groupAvatarUrl) : const Value(null),
          lastMessageAt: Value(lastMessageAt ?? DateTime.now()),
          hasUnread: Value(isUnread),
          lastMessage: decryptedLastMessage != null
              ? Value(decryptedLastMessage) : const Value(null),
          lastMessageSender: lastMessageSender != null
              ? Value(lastMessageSender) : const Value(null),
          lastMessageType: Value(lastMessageType),
          unreadCount: Value(unreadCount),
          groupName: Value(groupName),
          participantCount: Value(participants.length),
          participantUids: participantUidsStr != null ? Value(participantUidsStr) : const Value(null),
          isGroupChat: const Value(true),
          groupCreatedBy: groupCreatedBy != null ? Value(groupCreatedBy) : const Value(null),
        ),
      );
    }
  }

  Future<void> _maybeTransferCreatorOnLeave(String chatId, String departingUid) async {
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      final roles = Map<String, String>.from(chatDoc.data()?['participantRoles'] ?? {});
      if (roles[departingUid] != 'creator') return;
      final activeParticipants = List<String>.from(chatDoc.data()?['participants'] ?? [])
          .where((p) => p != departingUid).toList();
      if (activeParticipants.isEmpty) return;
      String newCreator = activeParticipants.first;
      for (final p in activeParticipants) {
        if (roles[p] == 'admin') { newCreator = p; break; }
      }
      await firestore.collection('chats').doc(chatId).update({
        'participantRoles.$newCreator': 'creator',
        'participantRoles.$departingUid': FieldValue.delete(),
      });
      DebugConfig.log(DebugConfig.repositoryResult, '_maybeTransferCreatorOnLeave: $chatId -> $newCreator');
    } catch (e) {
      DebugConfig.warn('_maybeTransferCreatorOnLeave failed', data: e);
    }
  }

  // ── Group Chat Public Methods ──────────────────────────────

  Future<String> createGroupChat(List<String> participantUids, {String? groupName, bool isPublic = false, String? description, List<String>? tags, String? city}) async {
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('create_group_chat', 'Δεν υπάρχει συνδεδεμένος χρήστης / No authenticated user');
    final uid = user.uid;

    if (participantUids.isEmpty) {
      throw AppException.auth('create_group_chat',
          'Χρειάζεται τουλάχιστον 1 άτομο / At least 1 other participant required');
    }
    if (participantUids.length > 9) {
      throw AppException.auth('create_group_chat',
          'Μέγιστο 10 άτομα συνολικά / Maximum 10 participants total');
    }
    if (participantUids.contains(uid)) {
      throw AppException.auth('create_group_chat',
          'Δεν μπορείς να προσθέσεις τον εαυτό σου / Cannot add yourself');
    }
    if (participantUids.toSet().length != participantUids.length) {
      throw AppException.auth('create_group_chat',
          'Υπάρχουν διπλότυπα άτομα / Duplicate participants');
    }

    DebugConfig.log(DebugConfig.repositoryCall, 'createGroupChat: by $uid with ${participantUids.length} others');

    final myProfile = await firestore
        .collection('users').doc(uid).collection('public').doc('profile').get();
    final myNickname = myProfile.data()?['nickname'] as String? ?? uid;
    final myAvatarUrl = myProfile.data()?['avatarUrl'] as String?;

    final profileFutures = participantUids.map((pUid) async {
      final doc = await firestore
          .collection('users').doc(pUid).collection('public').doc('profile').get();
      final nickname = doc.data()?['nickname'] as String? ?? pUid;
      final avatarUrl = doc.data()?['avatarUrl'] as String?;
      return (uid: pUid, nickname: nickname, avatarUrl: avatarUrl);
    });
    final profileResults = await Future.wait(profileFutures);
    final nicknames = {uid: myNickname, for (final r in profileResults) r.uid: r.nickname};
    final avatarUrls = <String, String>{
      uid: ?myAvatarUrl,
      for (final r in profileResults) if (r.avatarUrl != null) r.uid: r.avatarUrl!,
    };

    final chatId = firestore.collection('chats').doc().id;
    final allUids = [uid, ...participantUids];

    _enforceParticipantLimit(allUids.length, 10);

    try {
      await firestore.collection('chats').doc(chatId).set({
        'participants': allUids,
        'participantNicknames': nicknames,
        'participantAvatarUrls': avatarUrls,
        'participantRoles': {
          uid: 'creator',
          for (final pUid in participantUids) pUid: 'member',
        },
        'permissionOverrides': {},
        'participantJoinedAt': {for (final pUid in allUids) pUid: FieldValue.serverTimestamp()},
        'participantInvitedBy': {for (final pUid in participantUids) pUid: uid},
        'participantIsActive': {for (final pUid in allUids) pUid: true},
        'maxParticipants': 10,
        'isGroupChat': true,
        'groupName': groupName ?? _defaultGroupName(nicknames),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'createdBy': uid,
        if (isPublic) 'isPublic': true,
      });

      final key = EncryptionUtils.deriveKey(chatId);
      await EncryptionUtils.storeKey(chatId, key);

      if (isPublic) {
        try {
          final groupSearchRepo = FirestoreGroupSearchRepository(firestore: firestore);
          await groupSearchRepo.createPublicProfile(chatId, GroupPublicProfile(
            chatId: chatId,
            groupName: groupName ?? _defaultGroupName(nicknames),
            memberCount: allUids.length,
            description: description,
            tags: tags ?? [],
            city: city,
            isPublic: true,
            createdBy: uid,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
          DebugConfig.log(DebugConfig.repositoryResult, 'createGroupChat: public profile created for $chatId');
        } catch (e, s) {
          DebugConfig.error('createGroupChat: failed to create public profile', data: e, exception: s);
        }
      }

      await _sendSystemMessage(chatId, 'group_created', uid);
      await _logAudit(chatId, 'group_created', uid, details: {'participantUids': allUids});
      await db.logConsent(uid, 'group_created', 'group');

      DebugConfig.log(DebugConfig.repositoryResult, 'createGroupChat: $chatId with ${allUids.length} participants');
    } catch (e, s) {
      DebugConfig.error('createGroupChat failed', data: e, exception: s);
      if (e is AppException) rethrow;
      throw AppException.firestore('create_group_chat', 'Αποτυχία δημιουργίας ομάδας / Failed to create group');
    }
    return chatId;
  }

  Future<void> addParticipant(String chatId, String newUid) async {
    final uid = _currentUid;
    DebugConfig.log(DebugConfig.repositoryCall, 'addParticipant: $newUid to $chatId by $uid');

    await _requirePermission(chatId, GroupPermission.inviteMembers);

    if (newUid == uid) {
      throw AppException.auth('add_participant',
          'Δεν μπορείς να προσθέσεις τον εαυτό σου / Cannot add yourself');
    }

    try {
      await FirebaseFunctions.instance
          .httpsCallable('addGroupParticipant')
          .call({'chatId': chatId, 'newUid': newUid});

      await _sendSystemMessage(chatId, 'participant_added', uid, [newUid]);
      await _logAudit(chatId, 'participant_added', uid, targetUid: newUid);
      await db.logConsent(uid, 'group_member_added', 'group');
      await _updatePublicProfileMemberCount(chatId);

      DebugConfig.log(DebugConfig.repositoryResult, 'addParticipant: $newUid added to $chatId');
    } on FirebaseFunctionsException catch (e) {
      DebugConfig.error('addParticipant failed', data: e);
      throw _cfErrorToAppException(e);
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('addParticipant failed', data: e, exception: s);
      throw AppException.firestore('add_participant', 'Αποτυχία προσθήκης / Failed to add participant');
    }
  }

  Future<void> removeParticipant(String chatId, String targetUid) async {
    final uid = _currentUid;
    final isSelf = targetUid == uid;
    DebugConfig.log(DebugConfig.repositoryCall, 'removeParticipant: $targetUid from $chatId by $uid (self=$isSelf)');

    if (!isSelf) {
      await _requirePermission(chatId, GroupPermission.removeMembers);
    }

    try {
      await firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayRemove([targetUid]),
        'participantIsActive.$targetUid': false,
      });

      if (isSelf) {
        await _maybeTransferCreatorOnLeave(chatId, uid);
      } else {
        await _maybeTransferCreatorOnLeave(chatId, targetUid);
      }

      await _sendSystemMessage(chatId, isSelf ? 'participant_left' : 'participant_removed', uid, [targetUid]);
      await _logAudit(chatId, isSelf ? 'participant_left' : 'participant_removed', uid, targetUid: targetUid);
      if (isSelf) {
        await EncryptionUtils.deleteKey(chatId);
        await db.logConsent(uid, 'group_left', 'group');
      }
      await _updatePublicProfileMemberCount(chatId);
      if (isSelf) {
        await removeChatCache(chatId);
      }

      DebugConfig.log(DebugConfig.repositoryResult, 'removeParticipant: done $chatId');
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('removeParticipant failed', data: e, exception: s);
      throw AppException.firestore('remove_participant', 'Αποτυχία αφαίρεσης / Failed to remove participant');
    }
  }

  Future<void> updateGroupName(String chatId, String name) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'updateGroupName: $chatId -> "$name"');
    await _requirePermission(chatId, GroupPermission.changeGroupName);
    if (name.trim().isEmpty) {
      throw AppException.auth('group_name',
          'Το όνομα δεν μπορεί να είναι κενό / Name cannot be empty');
    }

    try {
      await firestore.collection('chats').doc(chatId).update({'groupName': name.trim()});
      await _syncPublicProfileField(chatId, {'groupName': name.trim()});
      await updateChatCache(chatId, groupName: name.trim());
      await _sendSystemMessage(chatId, 'name_changed', _currentUid, [name.trim()]);
      DebugConfig.log(DebugConfig.repositoryResult, 'updateGroupName: done $chatId');
    } catch (e, s) {
      DebugConfig.error('updateGroupName failed', data: e, exception: s);
      throw AppException.firestore('update_group_name', 'Αποτυχία αλλαγής ονόματος / Failed to update name');
    }
  }

  Future<void> updateParticipantRole(String chatId, String targetUid, String newRole) async {
    final uid = _currentUid;
    DebugConfig.log(DebugConfig.repositoryCall, 'updateParticipantRole: $targetUid -> $newRole in $chatId by $uid');
    await _requirePermission(chatId, GroupPermission.manageAdmins);

    if (targetUid == uid) {
      throw AppException.auth('update_role',
          'Δεν μπορείς να αλλάξεις τον δικό σου ρόλο / Cannot change your own role');
    }
    if (!['member', 'admin'].contains(newRole)) {
      throw AppException.auth('update_role',
          'Μη έγκυρος ρόλος / Invalid role');
    }

    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      final roles = Map<String, String>.from(chatDoc.data()?['participantRoles'] ?? {});
      if (roles[targetUid] == 'creator') {
        throw AppException.auth('update_role',
            'Δεν μπορείς να αλλάξεις τον ρόλο του δημιουργού / Cannot change creator role');
      }

      final oldRole = roles[targetUid];
      await firestore.collection('chats').doc(chatId).update({
        'participantRoles.$targetUid': newRole,
        if (newRole == 'member') 'permissionOverrides.$targetUid': {},
      });
      await _logAudit(chatId, 'role_changed', uid,
          targetUid: targetUid, details: {'oldRole': oldRole, 'newRole': newRole});
      await _sendSystemMessage(chatId, 'role_changed', uid, [targetUid, newRole]);
      DebugConfig.log(DebugConfig.repositoryResult, 'updateParticipantRole: done $chatId');
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('updateParticipantRole failed', data: e, exception: s);
      throw AppException.firestore('update_role', 'Αποτυχία αλλαγής ρόλου / Failed to update role');
    }
  }

  Future<void> updatePermissionOverride(String chatId, String targetUid, GroupPermission permission, bool value) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'updatePermissionOverride: $targetUid $permission=$value in $chatId');
    await _requirePermission(chatId, GroupPermission.managePermissions);

    try {
      await firestore.collection('chats').doc(chatId).update({
        'permissionOverrides.$targetUid.${permission.name}': value,
      });
      await _logAudit(chatId, 'permission_changed', _currentUid,
          targetUid: targetUid, details: {'permission': permission.name, 'newValue': value});
      await _sendSystemMessage(chatId, 'permission_changed', _currentUid,
          [targetUid, permission.name, value ? 'granted' : 'revoked']);
      DebugConfig.log(DebugConfig.repositoryResult, 'updatePermissionOverride: done $chatId');
    } catch (e, s) {
      DebugConfig.error('updatePermissionOverride failed', data: e, exception: s);
      throw AppException.firestore('update_permission', 'Αποτυχία αλλαγής δικαιώματος / Failed to update permission');
    }
  }

  Future<void> deletePermissionOverrides(String chatId, String targetUid) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deletePermissionOverrides: $targetUid in $chatId');
    await _requirePermission(chatId, GroupPermission.managePermissions);

    try {
      await firestore.collection('chats').doc(chatId).update({
        'permissionOverrides.$targetUid': FieldValue.delete(),
      });
      await _logAudit(chatId, 'permission_overrides_reset', _currentUid,
          targetUid: targetUid);
      await _sendSystemMessage(chatId, 'permission_overrides_reset', _currentUid, [targetUid]);
      DebugConfig.log(DebugConfig.repositoryResult, 'deletePermissionOverrides: done $chatId');
    } catch (e, s) {
      DebugConfig.error('deletePermissionOverrides failed', data: e, exception: s);
      throw AppException.firestore('delete_permission_overrides',
          'Αποτυχία διαγραφής overrides / Failed to reset permissions');
    }
  }

  Future<void> deleteGroup(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteGroup: $chatId');
    final uid = _currentUid;
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;
      final data = chatDoc.data()!;
      final isGroup = data['isGroupChat'] == true;
      if (!isGroup) {
        throw AppException.auth('delete_group',
            'Δεν είναι ομαδική συνομιλία / Not a group chat');
      }
      await _requirePermission(chatId, GroupPermission.managePermissions);
      await _sendSystemMessage(chatId, 'group_deleted', uid);
      await _logAudit(chatId, 'group_deleted', uid);

      if (data['isPublic'] == true) {
        try {
          await FirestoreGroupSearchRepository(firestore: firestore).deletePublicProfile(chatId);
        } catch (_) {}
      }

      final messages = await firestore
          .collection('chats').doc(chatId).collection('messages').get();
      final batch = firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(firestore.collection('chats').doc(chatId));
      await batch.commit();
      await (db.delete(db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
      DebugConfig.log(DebugConfig.repositoryResult, 'deleteGroup: done $chatId');
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('deleteGroup failed', data: e, exception: s);
      throw AppException.firestore('delete_group',
          'Αποτυχία διαγραφής ομάδας / Failed to delete group');
    }
  }

  Future<void> updateMaxParticipants(String chatId, int newMax) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'updateMaxParticipants: $chatId -> $newMax');

    final uid = _currentUid;
    final chatSnap = await firestore.collection('chats').doc(chatId).get();
    final roles = Map<String, String>.from(chatSnap.data()?['participantRoles'] as Map? ?? {});
    final role = roles[uid];
    if (role != 'creator' && role != 'admin') {
      throw AppException.auth('permission_denied',
          'Μόνο ο δημιουργός ή ο διαχειριστής μπορεί να αλλάξει το όριο / Only creator or admin can change the limit');
    }

    if (newMax < 2 || newMax > 100) {
      throw AppException.auth('max_participants',
          'Το όριο πρέπει να είναι 2-100 / Limit must be 2-100');
    }

    try {
      final currentCount = (chatSnap.data()?['participants'] as List?)?.length ?? 0;
      final oldMax = chatSnap.data()?['maxParticipants'] as int? ?? 10;
      if (newMax < currentCount) {
        throw AppException.auth('max_participants',
            'Το όριο δεν μπορεί να είναι μικρότερο από τα τρέχοντα μέλη / Cannot be less than current members');
      }

      await firestore.collection('chats').doc(chatId).update({'maxParticipants': newMax});
      await _logAudit(chatId, 'max_participants_changed', _currentUid,
          details: {'oldMax': oldMax, 'newMax': newMax});
      await _sendSystemMessage(chatId, 'max_participants_changed', _currentUid, [newMax.toString()]);
      DebugConfig.log(DebugConfig.repositoryResult, 'updateMaxParticipants: done $chatId');
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('updateMaxParticipants failed', data: e, exception: s);
      throw AppException.firestore('update_max', 'Αποτυχία αλλαγής ορίου / Failed to update limit');
    }
  }

  Future<List<String>> getParticipantUids(String chatId) async {
    try {
      final doc = await firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(doc.data()?['participants'] ?? []);
      final activeMap = (doc.data()?['participantIsActive'] as Map?) ?? {};
      return participants.where((p) => activeMap[p] != false).toList();
    } catch (e, s) {
      DebugConfig.error('getParticipantUids failed', data: e, exception: s);
      throw AppException.firestore('get_participants', 'Αποτυχία ανάγνωσης συμμετεχόντων / Failed to read participants');
    }
  }

  Stream<List<String>> participantUidsStream(String chatId) {
    DebugConfig.log(DebugConfig.chatStream, 'participantUidsStream: starting $chatId');
    return firestore.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists) return <String>[];
      final participants = List<String>.from(snap.data()?['participants'] ?? []);
      final activeMap = (snap.data()?['participantIsActive'] as Map?) ?? {};
      return participants.where((p) => activeMap[p] != false).toList();
    });
  }

  Future<bool> hasPermission(String chatId, GroupPermission permission) async {
    try {
      final info = await getPermissionsInfo(chatId);
      final uid = auth.currentUser?.uid;
      if (uid == null) return false;
      return info.hasPermission(uid, permission);
    } catch (e) {
      DebugConfig.warn('hasPermission failed', data: e);
      return false;
    }
  }

  Future<GroupPermissionsInfo> getPermissionsInfo(String chatId) async {
    final doc = await firestore.collection('chats').doc(chatId).get();
    final roles = Map<String, String>.from(doc.data()?['participantRoles'] ?? {});
    final overrides = Map<String, Map<String, bool>>.from(
      (doc.data()?['permissionOverrides'] as Map?)?.map(
        (k, v) => MapEntry(k, Map<String, bool>.from(v as Map)),
      ) ?? {},
    );
    return GroupPermissionsInfo(roles: roles, overrides: overrides);
  }

  // ── Group Avatar ───────────────────────────────────────────

  Future<void> updateGroupAvatar(String chatId, dynamic image) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'updateGroupAvatar: $chatId');
    await _requirePermission(chatId, GroupPermission.changeGroupAvatar);
    try {
      final uid = _currentUid;
      final storageRef = FirebaseStorage.instance
          .ref().child('group_avatars').child(chatId).child('avatar.jpg');
      // Το image αναμένεται να είναι XFile (από image_picker)
      final task = await storageRef.putData(
        await (image as dynamic).readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      await firestore.collection('chats').doc(chatId).update({'groupAvatarUrl': url});
      await _syncPublicProfileField(chatId, {'groupAvatarUrl': url});
      await _logAudit(chatId, 'avatar_changed', uid);
      await _sendSystemMessage(chatId, 'avatar_changed', uid);
      await updateChatCache(chatId, groupAvatarUrl: url);
      DebugConfig.log(DebugConfig.repositoryResult, 'updateGroupAvatar: done $chatId');
    } catch (e, s) {
      DebugConfig.error('updateGroupAvatar failed', data: e, exception: s);
      throw AppException.firestore('update_avatar', 'Αποτυχία αλλαγής εικόνας / Failed to update avatar');
    }
  }

  Future<void> removeGroupAvatar(String chatId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'removeGroupAvatar: $chatId');
    await _requirePermission(chatId, GroupPermission.changeGroupAvatar);
    try {
      await FirebaseStorage.instance
          .ref().child('group_avatars').child(chatId).child('avatar.jpg').delete();
      await firestore.collection('chats').doc(chatId).update({'groupAvatarUrl': FieldValue.delete()});
      await _syncPublicProfileField(chatId, {'groupAvatarUrl': FieldValue.delete()});
      await _sendSystemMessage(chatId, 'avatar_removed', _currentUid);
      await updateChatCache(chatId, groupAvatarUrl: '');
      DebugConfig.log(DebugConfig.repositoryResult, 'removeGroupAvatar: done $chatId');
    } catch (e) {
      DebugConfig.warn('removeGroupAvatar failed (non-fatal)', data: e);
    }
  }

  // ── Public Group Join ───────────────────────────────────────

  Future<void> joinPublicGroup(String chatId) async {
    final uid = _currentUid;
    DebugConfig.log(DebugConfig.repositoryCall, 'joinPublicGroup: $chatId by $uid');

    try {
      await firestore.runTransaction((transaction) async {
        final chatRef = firestore.collection('chats').doc(chatId);
        final snap = await transaction.get(chatRef);
        if (!snap.exists) {
          throw AppException.firestore('join_public',
              'Η ομάδα δεν βρέθηκε / Group not found');
        }

        final data = snap.data()!;
        if (data['isPublic'] != true) {
          throw AppException.auth('join_public',
              'Η ομάδα δεν είναι δημόσια / Group is not public');
        }

        final participants = List<String>.from(data['participants'] ?? []);
        final maxP = data['maxParticipants'] as int? ?? 10;

        if (participants.contains(uid)) {
          throw AppException.auth('join_public',
              'Είσαι ήδη μέλος / Already a member');
        }
        if (participants.length >= maxP) {
          throw AppException.auth('join_public',
              'Η ομάδα είναι γεμάτη / Group is full');
        }

        _enforceParticipantLimit(participants.length + 1, maxP);

        final newDoc = await firestore
            .collection('users').doc(uid).collection('public').doc('profile').get();
        final newNickname = newDoc.data()?['nickname'] as String? ?? uid;

        transaction.update(chatRef, {
          'participants': FieldValue.arrayUnion([uid]),
          'participantNicknames.$uid': newNickname,
          'participantRoles.$uid': 'member',
          'participantJoinedAt.$uid': FieldValue.serverTimestamp(),
          'participantIsActive.$uid': true,
        });
      });

      await _sendSystemMessage(chatId, 'participant_added', uid, [uid]);
      await _logAudit(chatId, 'public_join', uid);
      await db.logConsent(uid, 'group_joined', 'group');
      await _updatePublicProfileMemberCount(chatId);

      DebugConfig.log(DebugConfig.repositoryResult, 'joinPublicGroup: done $chatId');
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('joinPublicGroup failed', data: e, exception: s);
      throw AppException.firestore('join_public', 'Αποτυχία συμμετοχής / Failed to join group');
    }
  }

  // ── Public Profile Sync ─────────────────────────────────────

  Future<void> _updatePublicProfileMemberCount(String chatId) async {
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (chatDoc.data()?['isPublic'] != true) return;
      final count = (chatDoc.data()?['participants'] as List?)?.length ?? 0;
      await firestore.collection('groups').doc(chatId).update({'memberCount': count});
      DebugConfig.log(DebugConfig.firestoreWrite, '_updatePublicProfileMemberCount: $chatId -> $count');
    } on FirebaseException catch (e) {
      if (e.code != 'NOT_FOUND') {
        DebugConfig.warn('_updatePublicProfileMemberCount failed for $chatId', data: e);
      }
    } catch (e) {
      DebugConfig.warn('_updatePublicProfileMemberCount failed for $chatId', data: e);
    }
  }

  Future<void> _syncPublicProfileField(String chatId, Map<String, dynamic> fields) async {
    try {
      await firestore.collection('groups').doc(chatId).update(fields);
      DebugConfig.log(DebugConfig.firestoreWrite, '_syncPublicProfileField: $chatId');
    } on FirebaseException catch (e) {
      if (e.code != 'NOT_FOUND') {
        DebugConfig.warn('_syncPublicProfileField failed for $chatId', data: e);
      }
    } catch (e) {
      DebugConfig.warn('_syncPublicProfileField failed for $chatId', data: e);
    }
  }

  // ── Invite Links ───────────────────────────────────────────

  Future<String> createInviteLink(String chatId, {Duration expiresIn = const Duration(days: 7), int? maxUses}) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'createInviteLink: $chatId');
    await _requirePermission(chatId, GroupPermission.inviteMembers);
    final uid = _currentUid;

    try {
      final inviteRef = firestore
          .collection('chats').doc(chatId).collection('invites').doc();
      final token = const Uuid().v4().replaceAll('-', '');
      await inviteRef.set({
        'token': token,
        'createdBy': uid,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(expiresIn)),
        'maxUses': maxUses ?? 10,
        'usedBy': [],
        'useCount': 0,
        'isRevoked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      DebugConfig.log(DebugConfig.repositoryResult, 'createInviteLink: $chatId token=$token');
      return token;
    } catch (e, s) {
      DebugConfig.error('createInviteLink failed', data: e, exception: s);
      throw AppException.firestore('create_invite', 'Αποτυχία δημιουργίας συνδέσμου / Failed to create invite link');
    }
  }

  Future<String?> redeemInviteLink(String token) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'redeemInviteLink: token=$token');
    final user = auth.currentUser;
    if (user == null) throw AppException.auth('redeem_invite', 'Δεν υπάρχει χρήστης / No user');

    try {
      final inviteSnap = await firestore
          .collectionGroup('invites')
          .where('token', isEqualTo: token)
          .where('isRevoked', isEqualTo: false)
          .limit(1)
          .get();

      if (inviteSnap.docs.isEmpty) {
        DebugConfig.warn('redeemInviteLink: invalid/expired token=$token');
        return null;
      }

      final inviteDoc = inviteSnap.docs.first;
      final data = inviteDoc.data();
      final chatId = inviteDoc.reference.parent.parent!.id;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final maxUses = data['maxUses'] as int?;
      final useCount = data['useCount'] as int? ?? 0;

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        DebugConfig.warn('redeemInviteLink: token expired token=$token');
        return null;
      }
      if (maxUses != null && useCount >= maxUses) {
        DebugConfig.warn('redeemInviteLink: max uses reached token=$token');
        return null;
      }

      await inviteDoc.reference.update({
        'usedBy': FieldValue.arrayUnion([user.uid]),
        'useCount': FieldValue.increment(1),
      });

      await addParticipant(chatId, user.uid);
      DebugConfig.log(DebugConfig.repositoryResult, 'redeemInviteLink: joined $chatId via token=$token');
      return chatId;
    } catch (e, s) {
      if (e is AppException) rethrow;
      DebugConfig.error('redeemInviteLink failed', data: e, exception: s);
      return null;
    }
  }

  Future<InviteInfo?> getInviteInfo(String token) async {
    try {
      final inviteSnap = await firestore
          .collectionGroup('invites')
          .where('token', isEqualTo: token)
          .limit(1)
          .get();
      if (inviteSnap.docs.isEmpty) return null;

      final doc = inviteSnap.docs.first;
      final data = doc.data();
      final chatId = doc.reference.parent.parent!.id;
      String? groupName;
      int? memberCount;
      try {
        final chatDoc = await firestore.collection('chats').doc(chatId).get();
        groupName = chatDoc.data()?['groupName'] as String?;
        memberCount = (chatDoc.data()?['participants'] as List?)?.length;
      } catch (_) { /* non-fatal */ }

      return InviteInfo(
        inviteId: doc.id,
        token: data['token'] as String? ?? token,
        createdBy: data['createdBy'] as String? ?? '',
        expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
        maxUses: data['maxUses'] as int?,
        useCount: data['useCount'] as int? ?? 0,
        isRevoked: data['isRevoked'] as bool? ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        groupName: groupName,
        memberCount: memberCount,
      );
    } catch (e) {
      DebugConfig.warn('getInviteInfo failed', data: e);
      return null;
    }
  }

  Future<void> revokeInvite(String chatId, String inviteId) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'revokeInvite: $chatId/$inviteId');
    await _requirePermission(chatId, GroupPermission.inviteMembers);
    try {
      await firestore
          .collection('chats').doc(chatId).collection('invites').doc(inviteId)
          .update({'isRevoked': true});
      DebugConfig.log(DebugConfig.repositoryResult, 'revokeInvite: done');
    } catch (e, s) {
      DebugConfig.error('revokeInvite failed', data: e, exception: s);
      throw AppException.firestore('revoke_invite', 'Αποτυχία ανάκλησης / Failed to revoke invite');
    }
  }

  Future<List<InviteInfo>> getActiveInvites(String chatId) async {
    try {
      final snap = await firestore
          .collection('chats').doc(chatId).collection('invites')
          .where('isRevoked', isEqualTo: false)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return InviteInfo(
          inviteId: doc.id,
          token: data['token'] as String? ?? '',
          createdBy: data['createdBy'] as String? ?? '',
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
          maxUses: data['maxUses'] as int?,
          useCount: data['useCount'] as int? ?? 0,
          isRevoked: data['isRevoked'] as bool? ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e, s) {
      DebugConfig.error('getActiveInvites failed', data: e, exception: s);
      throw AppException.firestore('get_invites', 'Αποτυχία ανάγνωσης προσκλήσεων / Failed to read invites');
    }
  }
}
