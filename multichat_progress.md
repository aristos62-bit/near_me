# MultiChat (Group Chat) — Πρόοδος Υλοποίησης

> Project: NearMe
> Spec: multichat.md — 31 βήματα σε 9 φάσεις
> Τελευταία ενημέρωση: 2026-07-10 (Φάση 8 ✅)

---

## Φάση 1: Foundation (Βήματα 1–3) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 1 | `feature_flags.dart: groupChatEnabled = true` | ✅ Done | Flag ενεργοποιημένο |
| 2 | `chat_cache_table.dart: +4 group columns` | ✅ Done | `isGroupChat`, `participantCount`, `participantUids`, `groupName` |
| 3 | `database.dart: migration v8 → v9` | ✅ Done | Schema v9, 4 νέες στήλες |

### Φάση 1 — Ολοκλήρωση

Ενεργοποιήθηκε το feature flag `groupChatEnabled` και προστέθηκαν 4 νέες στήλες στον τοπικό πίνακα ChatCacheTable (`isGroupChat`, `participantCount`, `participantUids`, `groupName`). Υλοποιήθηκε migration της βάσης από schema v8 σε v9, ώστε η local Drift cache να υποστηρίζει group chats. Δεν υπάρχουν ακόμα repositories ή services — μόνο η υποδομή.

---

## Φάση 2: Repository Layer (Βήματα 4–6) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 4 | `chat_repository.dart: +17 abstract methods` | ✅ Done | 25 abstract methods σύνολο (8 1-to-1 + 17 group) — δημιουργία, διαχείριση μελών, ρόλοι, permissions, invites, avatars |
| 5 | `group_chat_mixin.dart: mixin με όλη τη λογική` | ✅ Done | 736 γραμμές, `part of 'chat_repository_impl.dart'`, permissions, create/invite/avatar/audit/system messages |
| 6 | `chat_repository_impl.dart: with GroupChatMixin` | ✅ Done | 619 γραμμές, `with GroupChatMixin implements ChatRepository`, group-aware sync |

### Αρχιτεκτονικές Αποφάσεις — Φάση 2

- **GroupChatMixin** ως `part of` αντί ξεχωριστό αρχείο (πρόσβαση σε private members χωρίς renaming)
- **Αφαίρεση `on ChatRepositoryImpl`** από το mixin → abstract getters (`firestore`, `auth`, `db`, `removeChatCache`). Λύνει circular dependency (`recursive_interface_inheritance`)
- **`markAsRead`** χωρίς override στο mixin — group-branch ενσωματώθηκε απευθείας στο `ChatRepositoryImpl.markAsRead` (αποφυγή `super` call)
- Service classes (GroupPermissions, GroupInviteService, GroupAvatarService, GroupAuditLogService) — **inline** στο mixin, όχι ξεχωριστά αρχεία (απόκλιση από multichat.md SPoT)

### Φάση 2 — Ολοκλήρωση

Υλοποιήθηκε ολόκληρο το repository layer. Το abstract interface `ChatRepository` επεκτάθηκε με 17 νέες μεθόδους για group operations (permissions, invites, avatars, διαχείριση μελών). Το `GroupChatMixin` (736 γραμμές) υλοποιεί όλη τη λογική: δημιουργία group, προσθήκη/αφαίρεση μελών, έλεγχος permissions, transfer creator, invites, system messages, audit log. Το `ChatRepositoryImpl` ενσωματώνει το mixin και προσθέτει group-aware sync στον Drift cache. Διορθώθηκε bug στο `removeParticipant`: όταν admin αφαιρεί τον creator, γίνεται αυτόματο transfer της ιδιότητας σε άλλο admin.

---

## Φάση 3: Services (Βήματα 7–9) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 7 | `sendMessage(): @mentions extraction` | ✅ Done | Ενσωματωμένο στο `ChatRepositoryImpl.sendMessage` — ανίχνευση `@nickname`, κλήση MentionService |
| 8 | `mention_utils.dart: MentionService` | ✅ Done | 57 γραμμές, 3 static methods: `extractMentions`, `validateParticipants`, `formatForDisplay` |
| 9 | `group_search_repository.dart` | ✅ Done | 224 γραμμές — abstract `GroupSearchRepository` + `FirestoreGroupSearchRepository` με city/tag filtering |

### Φάση 3 — Ολοκλήρωση

Ολοκληρώθηκαν τα services για το Group Chat. Το `sendMessage()` επεκτάθηκε ώστε να εξάγει `@nickname` mentions από το περιεχόμενο του μηνύματος, να τα αντιστοιχίζει σε UIDs και να τα προσαρτά στο μήνυμα πριν την αποστολή. Δημιουργήθηκε το `MentionService` (mention_utils.dart) ως static utility class με extract, validate, και placeholder για UI formatting. Δημιουργήθηκε το repository αναζήτησης group (`group_search_repository.dart`) με abstract interface και Firestore implementation που υποστηρίζει φιλτράρισμα κατά city, tags, και query. **flutter analyze: 0 issues.**

---

## Φάση 4: Providers & State (Βήματα 10–11) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 10 | `chat_provider.dart`: group providers + notifier | ✅ Done | `participantUidsProvider` (StreamProvider), `groupPermissionsProvider` (FutureProvider), 12 group methods στο `ChatActionsNotifier` |
| 11 | `fcm_service.dart`: activeChatId → activeChatIds | ✅ Done | `activeChatId` (String?) → `activeChatIds` (Set<String>), `registerActiveChat`/`unregisterActiveChat`, `chat_screen.dart` updated |

### Φάση 4 — Ολοκλήρωση

Υλοποιήθηκαν οι providers για group state management. Το `chat_provider.dart` επεκτάθηκε με `participantUidsProvider` (real-time stream των UIDs μελών), `groupPermissionsProvider` (fetch δικαιωμάτων), και 12 group action methods στο `ChatActionsNotifier` (createGroupChat, addParticipant, removeParticipant, updateGroupName, updateGroupAvatar, removeGroupAvatar, updateParticipantRole, updatePermissionOverride, createInviteLink, redeemInviteLink, revokeInvite). Κάθε method έχει try/catch, DebugConfig logging, και invalidation σχετικών providers. Το `fcm_service.dart` αναβαθμίστηκε από μοναδικό `activeChatId` σε `activeChatIds` (Set) για υποστήριξη πολλαπλών group chats — προστέθηκαν `registerActiveChat`/`unregisterActiveChat` και το `chat_screen.dart` τα καλεί στο initState/dispose. Το `shouldSuppressForeground` χρησιμοποιεί `activeChatIds.contains(chatId)` αντί `== activeChatId`. **flutter analyze: 0 issues.**

---

## Φάση 5: Routing (Βήμα 12) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 12 | `app_router.dart: +6 routes` | ✅ Done | `/groups`, `/groups/create`, `/groups/:chatId`, `/groups/:chatId/info`, `/groups/:chatId/invite`, `/groups/search` με inline Scaffold placeholders |

### Φάση 5 — Ολοκλήρωση

Προστέθηκαν 6 νέες GoRouter routes στο `app_router.dart` με τη σωστή σειρά (sub-routes πριν parameterized) για να αποφευχθεί route hijack. Τα placeholders είναι inline Scaffolds ώστε να γίνεται compile χωρίς νέα files — στη Φάση 7 θα αντικατασταθούν με τα real screens. Ενημερώθηκε το `canCommunicate` redirect: `/groups` και `/groups/...` προστέθηκαν στα blocked paths για ανεπιβεβαίωτους χρήστες. **flutter analyze: 0 issues.**

## Φάση 6: Firestore (Βήματα 13–14) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 13 | Firestore security rules | ✅ Done | `isGroupChatRef`/`isGroupCreator`/`isGroupAdmin` helpers, audit_log/invites subcollections, collection group για groups+invites, top-level groups CRUD |
| 14 | Firestore composite indexes | ✅ Done | 4 indexes: groups(isPublic+city), groups(isPublic+tags), groups(isPublic+city+tags), invites(token+isRevoked) |

### Φάση 6 — Ολοκλήρωση

Ενημερώθηκαν τα Firestore security rules για υποστήριξη group chats. Το `/chats/{chatId}` accept πλέον `participants.size() >= 2` (group chats). Τα μηνύματα group chats εξαιρούνται από το block check. Προστέθηκαν subcollection rules για audit_log (read+create μόνο για participants) και invites (create/delete για participants, update επιτρέπει usedBy/useCount από non-participants για redeem link). Collection group rules για invites (lookup με token) και groups (public search). Top-level `/groups/{doc}` rules για CRUD public profiles (δημιουργός μόνο). Στο firestore.indexes.json προστέθηκαν 4 composite indexes για group search (isPublic+city, isPublic+tags, isPublic+city+tags) και invite lookup (token+isRevoked). **JSON: valid.**

## Φάση 7: UI Screens (Βήματα 15–22) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 15 | Group-aware chat_screen + widgets | ✅ Done | `chat_screen.dart` refactored (group AppBar, PopupMenu, _chatDocProvider), `message_bubble.dart` (sender labels/system/@mentions/seenBy), `chat_messages_list.dart` (scroll+markAsRead, isGroupChat), `chat_repository_impl.dart` messagesStream +seenBy +mentions +system skip decryption |
| 16 | Group-aware chat_list_screen | ✅ Done | `chat_list_screen.dart` — group tiles (Icons.group), preview χωρίς "Εσύ:" prefix, member count, FAB "Create Group" → `/groups/create` |
| 17 | CreateGroupScreen | ✅ Done | `create_group_screen.dart` — search users (Firestore collectionGroup('public') + client-side nickname filtering), select 1-9, optional groupName, create button |
| 18 | GroupInfoScreen | ✅ Done | `group_info_screen.dart` — participant list with roles (creator/admin/member), inline group name editor, invite management, leave group |
| 19 | GroupInviteScreen | ✅ Done | `group_invite_screen.dart` — λίστα active invites, create με dialog (days/maxUses), copy token στο clipboard, revoke |
| 20 | GroupSearchScreen | ✅ Done | `group_search_screen.dart` — αναζήτηση public groups (text), Join button (→ `joinPublicGroup`, skip permission check for public groups), AppBar icon στο chat_list_screen |
| 21 | GroupSettingsScreen | ✅ Done | `group_settings_screen.dart` — avatar upload/remove (ImagePicker), max participants edit (2-100), read-only permissions section |
| 22 | GroupCallScreen | ✅ Done | `group_call_screen.dart` — placeholder με 2 states (videoCallEnabled true/false), "Coming soon" / "Not available" |

### Φάση 7 — Ολοκλήρωση

Υλοποιήθηκαν όλες οι οθόνες του group chat. Το `chat_screen.dart` έγινε group-aware (AppBar με group name, PopupMenu με Group info / Call / Leave group, _chatDocProvider για real-time group data). Δημιουργήθηκαν widgets: `message_bubble.dart` (extracted, sender labels, system messages, @mentions, seenBy), `chat_messages_list.dart` (extracted scroll logic + markAsRead). Το `chat_list_screen.dart` εμφανίζει group tiles και FAB Create Group. Δημιουργήθηκαν CreateGroupScreen (search & select users), GroupInfoScreen (μέλη, ρόλοι, name editor), GroupInviteScreen (manage invite links), GroupSearchScreen (ανακάλυψη public groups), GroupSettingsScreen (avatar, max participants, permissions), και GroupCallScreen (placeholder για μελλοντική υλοποίηση). Προστέθηκε `joinPublicGroup` στο repository/mixin/provider για δημόσια συμμετοχή χωρίς permission check. **flutter analyze: 0 issues.**

## Φάση 8: Polish (Βήματα 23–25) ✅

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 23 | Error handling edge cases | ✅ Done | AppException handling, try-catch σε όλες τις group actions |
| 24 | Loading states & empty views | ✅ Done | LoadingView/EmptyView σε όλες τις οθόνες, consistent UX |
| 25 | Animations & UX polish | ✅ Done | AddParticipantScreen, GroupAuditLogScreen, JoinConfirmationScreen |

### Φάση 8 — Ολοκλήρωση

Ολοκληρώθηκε το polish του group chat UI. Προστέθηκαν νέες οθόνες: `add_participant_screen.dart` (αναζήτηση & προσθήκη μελών), `group_audit_log_screen.dart` (ιστορικό ενεργειών), `join_confirmation_screen.dart` (επιβεβαίωση συμμετοχής από invite link). Error handling edge cases, loading/empty states, και animations/UX polish σε όλες τις οθόνες. **flutter analyze: 0 issues.**

## Φάση 9: Build & Deploy (Βήματα 26–31) ❌

| Βήμα | Περιγραφή | Status | Λεπτομέρειες |
|------|-----------|--------|--------------|
| 26 | Build APK | ⏳ Pending |
| 27 | Install & verify | ⏳ Pending |
| 28 | Test group flows | ⏳ Pending |
| 29 | Fix issues | ⏳ Pending |
| 30 | Production build | ⏳ Pending |
| 31 | Release | ⏳ Pending |

---

## Σύνοψη

| Φάση | Βήματα | Status |
|------|--------|--------|
| 1. Foundation | 1–3 | ✅ |
| 2. Repository Layer | 4–6 | ✅ |
| 3. Services | 7–9 | ✅ |
| 4. Providers & State | 10–11 | ✅ |
| 5. Routing | 12 | ✅ |
| 6. Firestore | 13–14 | ✅ |
| 7. UI Screens | 15–22 | ✅ |
| 8. Polish | 23–25 | ✅ |
| 9. Build & Deploy | 26–31 | ❌ Εκκρεμεί |
| **Σύνολο** | **31** | **25/31 (81%)** |

**flutter analyze: 0 issues** — 168 errors διορθώθηκαν

## Αποκλίσεις από multichat.md

| Σημείο | multichat.md | Υλοποίηση | Αιτιολογία |
|--------|-------------|------------|------------|
| GroupChatMixin | `on ChatRepositoryImpl` | No `on` clause, abstract getters | Λύνει circular dependency (Dart recursive_interface_inheritance) |
| Service classes | Ξεχωριστά αρχεία | Inline στο mixin | SPoT στο mixin, μικρότερος αριθμός files |
| markAsRead | Override στο mixin | Group-branch στο ChatRepositoryImpl | `super` call αδύνατο χωρίς `on ChatRepositoryImpl` |
| GroupChatScreen | Ξεχωριστή οθόνη | `chat_screen.dart` auto-detects groups via `_chatDocProvider` | Επαναχρησιμοποίηση του existing chat screen (rule #4) |
| joinPublicGroup | Δεν προβλεπόταν | `joinPublicGroup(chatId)` στο repository/mixin/provider | Απαραίτητο για public group join χωρίς permission check |
| description editor | Στο GroupSettingsScreen | Δεν υλοποιήθηκε (δεν υπάρχει πεδίο description στο `chats` doc) | Απαιτεί public profile infrastructure (Phase 4+) |

## Αρχεία

| Αρχείο | Γραμμές | Ρόλος |
|--------|---------|-------|
| `lib/core/config/feature_flags.dart` | 21 | groupChatEnabled = true |
| `lib/data/local/tables/chat_cache_table.dart` | 33 | 4 group columns |
| `lib/data/local/database.dart` | 116 | Migration v8→v9 |
| `lib/repositories/chat_repository.dart` | 104 | Abstract interface (26 methods) |
| `lib/repositories/group_chat_mixin.dart` | 796 | Group logic (part of impl) — +joinPublicGroup |
| `lib/repositories/chat_repository_impl.dart` | 619 | Impl + sendMessage mentions |
| `lib/shared/utils/mention_utils.dart` | 57 | MentionService |
| `lib/repositories/group_search_repository.dart` | 224 | GroupSearchRepository |
| `lib/features/chat/providers/chat_provider.dart` | ~360 | Group providers + 15 action methods (+activeInvitesProvider, +updateMaxParticipants, +joinPublicGroup) |
| `lib/core/notifications/fcm_service.dart` | ~220 | activeChatIds set |
| `lib/core/router/app_router.dart` | ~274 | +8 group routes (6 real, 1 placeholder, 1 group list) |
| `firestore.rules` | 256 | Group rules: audit_log, invites, groups collection group |
| `firestore.indexes.json` | 177 | +4 composite indexes for group queries |
| `lib/features/chat/screens/chat_screen.dart` | ~345 | Group-aware AppBar, PopupMenu (info/call/leave), _chatDocProvider |
| `lib/features/chat/screens/chat_list_screen.dart` | ~278 | Group tiles, FAB Create Group, AppBar search icon |
| `lib/features/chat/screens/create_group_screen.dart` | ~280 | Search & select users, create group |
| `lib/features/chat/screens/group_info_screen.dart` | ~280 | Participant list, roles, name editor, leave |
| `lib/features/chat/screens/group_invite_screen.dart` | ~270 | Create/revoke/copy invite links |
| `lib/features/chat/screens/group_search_screen.dart` | ~220 | Discover & join public groups |
| `lib/features/chat/screens/group_settings_screen.dart` | ~280 | Avatar, max participants, permissions |
| `lib/features/chat/screens/group_call_screen.dart` | ~90 | Placeholder for group calls |
| `lib/features/chat/widgets/message_bubble.dart` | ~140 | Sender labels, system msgs, @mentions, seenBy |
| `lib/features/chat/widgets/chat_messages_list.dart` | ~130 | Scroll + markAsRead, isGroupChat |
