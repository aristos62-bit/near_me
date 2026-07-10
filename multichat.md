# MultiChat (Group Chat) — Πλήρης Προδιαγραφή

> **Έκδοση:** 2.0  
> **Ημερομηνία:** Ιούλιος 2026  
> **Κατάσταση:** Υλοποίηση σε εξέλιξη  
> 
> | Φάση | Κατάσταση |
> |------|:---------:|
> | **A** Foundation (Core) | ✅ **Ολοκληρωμένο** |
> | **B** Repository & Data | ✅ **Ολοκληρωμένο** |
> | **Γ** Services | ✅ **Ολοκληρωμένο** |
> | **Δ** FCM & Router | ✅ **Ολοκληρωμένο** |
> | **Ε** Core UI | ✅ **Ολοκληρωμένο** |
> | **ΣΤ** New UI Screens | ✅ **Ολοκληρωμένο** |
> | **Ζ** Polish | ✅ **Ολοκληρωμένο** |
---



## Πίνακας Περιεχομένων

1. [Επισκόπηση](#1-επισκόπηση)
2. [Απαραίτητες Προϋποθέσεις / Blockers](#2-απαραίτητες-προϋποθέσεις--blockers)
3. [Single Points of Truth (SPoT)](#3-single-points-of-truth-spot)
4. [Firestore Schema](#4-firestore-schema)
5. [Security Rules](#5-security-rules)
6. [Permission System](#6-permission-system)
7. [Encryption Strategy](#7-encryption-strategy)
8. [Drift Schema Migration (v8 → v9)](#8-drift-schema-migration-v8--v9)
9. [Repository Changes](#9-repository-changes)
10. [Invite Link / Group Sharing](#10-invite-link--group-sharing)
11. [Group Discovery & Join](#11-group-discovery--join)
12. [@Mentions](#12-mentions)
13. [Group Avatar](#13-group-avatar)
14. [Group Audit Log](#14-group-audit-log)
15. [Promote / Demote Admin](#15-promote--demote-admin)
16. [Read Receipts in Groups](#16-read-receipts-in-groups)
17. [Max Participants Limit](#17-max-participants-limit)
18. [Provider Changes](#18-provider-changes)
19. [FCM Changes](#19-fcm-changes)
20. [UI User Flow](#20-ui-user-flow)
21. [Νέες Οθόνες](#21-νέες-οθόνες)
22. [Τροποποιήσεις Υπαρχουσών Οθονών](#22-τροποποιήσεις-υπαρχουσών-οθονών)
23. [Λίστα Αρχείων προς Αλλαγή/Δημιουργία](#23-λίστα-αρχείων-προς-αλλαγήδημιουργία)
24. [Edge Cases & Προστασία](#24-edge-cases--προστασία)
25. [Side Effects Analysis](#25-side-effects-analysis)
26. [Σειρά Εκτέλεσης](#26-σειρά-εκτέλεσης)
27. [Παράρτημα B: Firebase Cost Analysis](#27-παράρτημα-b-firebase-cost-analysis)

---

## 1. Επισκόπηση

### Στόχος
Δυνατότητα δημιουργίας ομαδικών συνομιλιών (group chat) όπου πολλοί χρήστες μπορούν να συμμετέχουν στο ίδιο chat. Ο δημιουργός (Creator) έχει πλήρη έλεγχο και μπορεί να εκχωρεί granular permissions σε άλλους χρήστες.

### Βασικές Αρχές
- **Privacy-first:** Messages always AES-256 encrypted (ίδιο με 1-to-1)
- **Granular permissions:** Όχι απλά roles — ανά-πεδίο δικαιώματα
- **Single point of truth:** Repository pattern, όχι raw Firestore στο UI
- **Bilingual:** Όλο το UI σε Ελληνικά & Αγγλικά (L10n)
- **Debug logging:** DebugConfig.log σε κάθε operational action
- **Responsive:** LayoutBuilder + ResponsiveUtils
- **Feature flag:** Ομαλή ενεργοποίηση/απενεργοποίηση

### Τρέχον Chat System (πριν την αλλαγή)
| Στοιχείο | Περιγραφή |
|---|---|
| **ChatRepository** | Abstract: `createChat(otherUid)`, `sendMessage`, `streamChats`, `messagesStream`, `markAsRead`, `deleteChat`, `clearMessages` |
| **Firestore schema** | `/chats/{chatId}`: `participants: [uid1, uid2]` (ακριβώς 2) |
| **Εncryption** | AES-256 GCM, `deriveKey(chatId)` deterministic (SHA-256), key stored σε flutter_secure_storage |
| **Cache** | `ChatCacheTable` Drift: `ownerUid`, `otherUid`, `otherNickname`, `otherAvatarUrl`, ... |
| **ChatScreen** | AppBar "Προσωπικά μηνύματα", 3 widgets shell |
| **ChatListScreen** | `_ChatTile` με avatar + preview, 1-to-1 design |
| **FCM** | Notifications only between 2 participants |

---

## 2. Απαραίτητες Προϋποθέσεις / Blockers

| # | Τι πρέπει να γίνει | Blocker | Σημείωση |
|---|---|---|---|
| 1 | **Feature flag** `groupChatEnabled=true` | ✅ Υπάρχει ήδη (false) στο `feature_flags.dart` | Απλή αλλαγή |
| 2 | **Security rules**: `participants.size() == 2` → `>= 2 && <= maxParticipants` | ⚠️ Πρέπει deploy | Χωρίς αυτό, group chat δημιουργία αποτυγχάνει |
| 3 | **Drift migration** v8→v9: νέα πεδία `ChatCacheTable` | ⚠️ Πρέπει migration (database.dart) | 4 νέα columns |
| 4 | **Encryption key distribution**: νέοι participants | ✅ deriveKey deterministic | ΔΕΝ χρειάζεται αλλαγή |
| 5 | **FCM**: notify ALL participants | ⚠️ Πρέπει αλλαγή | Τώρα μόνο `otherUid` |
| 6 | **chat_repository_impl.dart**: ήδη 574 γραμμές (> 500) | ⚠️ Απαιτεί refactor | Extract `GroupChatMixin` → `group_chat_mixin.dart` (ChatRepositoryImpl with GroupChatMixin) |
| 7 | **Firestore indexes**: composite indexes για group search | ⚠️ Πρέπει deploy | `firestore.indexes.json`: 4 νέα indexes (βλ. §11.5) — collectionGroup 'groups' |
| 8 | **ConsentLog**: νέες actions | ⚠️ Πρέπει update | `created_group`, `added_to_group`, `removed_from_group`, `left_group` |
| 9 | **Permission System**: νέος μηχανισμός | ⚠️ Νέο σύστημα | GroupPermission enum + repository checks |
| 10 | **FcmService.activeChatId**: `String?` → `Set<String>` | ⚠️ Πρέπει αλλαγή | Για suppression notifications όταν είσαι σε group |

---

## 3. Single Points of Truth (SPoT)

> Κάθε διαδικασία του Multichat έχει **ΑΚΡΙΒΩΣ ΕΝΑ** σημείο αλήθειας, ακολουθώντας το ίδιο pattern με `AuthRepository.canUserCommunicate()`, `FcmService.activeChatId`, `DebugConfig` κλπ.

### 3.1 Πίνακας SPoT

| Διαδικασία | SPoT | Τύπος | Περιγραφή |
|---|---|---|---|
| **Permission check** | `GroupPermissions.hasPermission()` | static method | Μοναδική υλοποίηση λογικής effective permission (role default + override) |
| **Repository-level guard** | `GroupChatMixin._requirePermission()` | private method | Όλες οι protected group methods καλούν ΑΥΤΗΝ, ΠΟΤΕ raw hasPermission |
| **Invite link** | `GroupInviteService` | class | create/redeem/validate/revoke — όλη η λογική invites |
| **Group discovery** | `GroupSearchRepository` | abstract interface | Extends SearchRepository pattern — searchGroups, searchPublicGroups |
| **@mentions** | `MentionService` | class | extractMentions, validateParticipants, formatMentionText |
| **Group avatar upload** | `GroupAvatarService` | class | pick → crop → upload → update doc — ίδιο pattern με Profile avatar |
| **Read receipts (group)** | `ChatRepositoryImpl.markAsRead()` | override | Extended: γράφει `lastReadTimestamps[uid]` στο chat doc (1 write) αντί batch per message |
| **Audit log write** | `GroupAuditLogService.log()` | class | Κάθε group mutation καλεί αυτήν — ΠΟΤΕ raw Firestore write |
| **Audit log read** | `GroupAuditLogService.streamLog()` | Stream | Πάντα από αυτό το service, ΠΟΤΕ απευθείας Firestore |
| **Max participants** | `GroupRepositoryImpl._enforceLimit()` | private | Μοναδικό σημείο ελέγχου addParticipant + createGroupChat |
| **Promote/demote** | `ChatRepositoryImpl.updateParticipantRole()` | method | Μοναδικό σημείο αλλαγής role — ΠΟΤΕ raw Firestore update |
| **FCM suppression** | `FcmService.activeChatIds` | static Set | FCM foreground suppression για groups (όχι 2ο σημείο) |
| **Consent logging** | `ConsentLogService` (υπάρχον) | class | Νέες group actions από εδώ — όχι ξεχωριστός logger |
| **System messages** | `GroupChatMixin._sendSystemMessage()` | private | Μοναδική μέθοδος δημιουργίας system type messages |

### 3.2 Αρχή Λειτουργίας

```dart
// ΠΟΤΕ έτσι (raw Firestore από UI):
final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
final roles = doc.data()?['participantRoles'];
if (roles[uid] == 'admin') { /* ... */ }

// ΠΑΝΤΑ έτσι (SPoT):
final info = await chatRepo.getPermissionsInfo(chatId);
if (info.hasPermission(uid, GroupPermission.inviteMembers)) { /* ... */ }
// ή (αν είμαστε ήδη στο repository layer):
await _requirePermission(chatId, GroupPermission.inviteMembers);
```

---

## 4. Firestore Schema

### 4.1 `/chats/{chatId}` Document

```javascript
{
  participants: [uid1, uid2, uid3],           // array, ≥ 2, ≤ maxParticipants
  participantNicknames: {uid1: "Νίκος", ...},  // map
  participantRoles: {
    uid1: "creator",                           // creator = absolute power
    uid2: "admin",                             // admin = full management (except manageAdmins/managePermissions)
    uid3: "member"                             // member = basic permissions
  },
  permissionOverrides: {
    uid3: {                                    // member με granular override
      inviteMembers: true                      // μπορεί να προσκαλεί, αλλά τίποτα άλλο
    }
  },
  participantJoinedAt: {
    uid1: Timestamp,
    uid2: Timestamp
  },
  participantInvitedBy: {
    uid2: uid1,
    uid3: uid1
  },
  participantIsActive: {
    uid1: true,
    uid2: true,
    uid3: false                                // false = αποχώρησε
  },
  maxParticipants: 10,                         // default: 10
  isGroupChat: true,                           // false για 1-to-1
  groupName: "Φίλοι Αθήνα",                    // optional, editable
  groupAvatarUrl: "https://...",               // optional, future phase
  lastReadTimestamps: {                        // SPoT: markAsRead (1 write/user, όχι batch per message)
    uid1: Timestamp,
    uid2: Timestamp
  },
  createdAt: Timestamp,
  isActive: true,
  lastMessageAt: Timestamp,
  lastMessageBy: uid,
  lastMessage: "encrypted:string",
  lastMessageType: "text" | "system",
  systemMessage: "Ο/Η Νίκος προστέθηκε στην ομάδα"  // only for system messages
}
```

### 4.2 `/chats/{chatId}/messages/{msgId}` (updated)

```javascript
{
  senderId: uid,
  content: "encrypted:string",                // AES-256 GCM encrypted
  type: "text" | "image" | "system",          // 'system' = non-encrypted metadata
  timestamp: Timestamp,
  isRead: false,                              // legacy (1-to-1 backward compat — group: IGNORED)
  mentions: [uid2, uid3],                     // @mentioned UIDs (SPoT via MentionService)
  mentionTargets: ["uid2", "uid3"]            // explicit targets for FCM routing
};
```

> **SPoT:** Read receipts για groups → `lastReadTimestamps` στο chat doc (Section 4.1).  
> **SPoT:** `mentions` γράφεται ΜΟΝΟ από `MentionService.extractMentions()` στο `sendMessage()`.

Στα system messages, το `content` είναι **plaintext** (μη encrypted) bilingual string, π.χ. `"Ο Νίκος προστέθηκε στην ομάδα / Nikos joined the group"`.

### 4.3 `/chats/{chatId}/invites/{inviteId}` (NEW — Invite Links)

```javascript
{
  token: "abc123def456",                     // μοναδικό, random UUID
  createdBy: uid,                             // ποιος δημιούργησε
  expiresAt: Timestamp,                       // default: 7 days από δημιουργία
  maxUses: 10,                                // default: 10, null = unlimited
  usedBy: [uid2, uid3],                       // array UIDs που εξαργύρωσαν
  useCount: 2,                                // aggregate counter
  isRevoked: false,                           // ανάκληση από creator
  createdAt: Timestamp
}
```

> **SPoT:** `GroupInviteService` — create / redeem / getInfo / revoke. ΠΟΤΕ raw Firestore.

### 4.4 `/chats/{chatId}/audit_log/{entryId}` (NEW — Audit Log)

```javascript
{
  action: "role_changed",                     // role_changed | permission_changed |
                                             // name_changed | avatar_changed |
                                             // participant_added | participant_removed |
                                             // participant_left | group_created
  actorUid: uid,                              // who performed the action
  targetUid: uid,                             // who was affected (optional)
  details: {                                  // action-specific data
    oldRole: "member",
    newRole: "admin",
    permission: "inviteMembers",
    oldValue: false,
    newValue: true,
    oldName: "Παλιό Όνομα",
    newName: "Νέο Όνομα"
  },
  timestamp: Timestamp
}
```

> **SPoT:** `GroupAuditLogService.log(action, actorUid, {targetUid, details})` — ΠΟΤΕ raw Firestore write.  
> Read: `GroupAuditLogService.streamLog(chatId)` — Stream (Firestore orderBy timestamp).  
> Δεν αποθηκεύεται τοπικά στο Drift (όπως messages).

### 4.5 `/groups/{chatId}` (NEW — Group Public Profile για Discovery)

```javascript
{
  chatId: "same_as_chat",                     // reference στο chats/{chatId}
  groupName: "Φίλοι Αθήνα",
  groupAvatarUrl: "https://...",              // optional
  memberCount: 4,
  description: "Παρέα για εξόδους στην Αθήνα",// optional
  tags: ["εξοδος", "αθηνα", "παρεα"],         // optional, max 5
  city: "Αθήνα",                              // optional, derived from members
  isPublic: true,                             // visible in search
  createdBy: uid,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

> **SPoT:** `GroupSearchRepository` — search, createPublicProfile, updatePublicProfile, deletePublicProfile.  
> Δημιουργείται ΜΟΝΟ αν creator επιλέξει "Δημόσια ομάδα" στο createGroup.  
> Collection group query: `collectionGroup('groups')` όπως τα public profiles.

### 4.6 Backward Compatibility

---

## 5. Security Rules

### 5.1 Chats Collection

```javascript
match /chats/{chatId} {
  // CREATE: relaxed from size() == 2
  allow create: if isAuthenticated()
                && isVerified()
                && request.auth.uid in request.resource.data.participants
                && request.resource.data.participants.size() >= 2
                && request.resource.data.participants.size()
                     <= request.resource.data.maxParticipants
                && request.resource.data.maxParticipants >= 2   // hard floor
                && request.resource.data.maxParticipants <= 100;  // hard cap

  // READ: unchanged — isParticipant works for any array size
  allow read: if isAuthenticated()
              && isParticipant(resource.data);

  // UPDATE: permission-sensitive with server-side role gates
  allow update: if isAuthenticated()
                && isParticipant(resource.data)
                && (
                  // Last message updates (any participant — no escalation risk)
                  request.resource.data.diff(resource.data).affectedKeys()
                    .hasOnly(['lastMessageAt', 'lastMessageBy', 'lastMessage',
                              'lastMessageType', 'lastMessageSender', 'systemMessage'])
                  ||
                  // Read receipts (any participant, only their own key)
                  request.resource.data.diff(resource.data).affectedKeys()
                    .hasOnly(['lastReadTimestamps.${request.auth.uid}'])
                  ||
                  // Non-sensitive display fields (admin+ — granular overrides enforced client-side)
                  (request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['groupName', 'groupAvatarUrl'])
                   && resource.data.participantRoles[request.auth.uid] in ['creator', 'admin'])
                  ||
                  // Participant management: add/remove members (admin+)
                  (request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['participants', 'participantJoinedAt',
                               'participantInvitedBy', 'participantIsActive'])
                   && resource.data.participantRoles[request.auth.uid] in ['creator', 'admin'])
                  ||
                  // CRITICAL: role/permission/limit changes — ONLY creator
                  (request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['participantRoles', 'permissionOverrides', 'maxParticipants'])
                   && resource.data.participantRoles[request.auth.uid] == 'creator'
                   && request.resource.data.maxParticipants >= 2
                   && request.resource.data.maxParticipants <= 100)
                );

  // DELETE: any active participant
  allow delete: if isAuthenticated()
                && isParticipant(resource.data);
```

### 5.2 Messages Subcollection (updated)

```javascript
  match /messages/{msgId} {
    allow read: if isAuthenticated()
                && isParticipant(
                     get(/databases/$(database)/documents/chats/$(chatId)).data
                   );
    allow create: if isAuthenticated()
                  && isVerified()
                  && request.auth.uid == request.resource.data.senderId
                  && isParticipant(
                       get(/databases/$(database)/documents/chats/$(chatId)).data
                     )
                  && isNotBlockedInChat(chatId);
    allow update: if isAuthenticated()
                  && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['isRead']);         // μόνο 1-to-1: isRead batch
    // delete: only with permission (enforced client-side via repository)
    allow delete: if isAuthenticated()
                  && isParticipant(
                       get(/databases/$(database)/documents/chats/$(chatId)).data
                     );
  }
```

### 5.3 Invites Subcollection (NEW)

```javascript
  match /invites/{inviteId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated()
                  && isParticipant(
                       get(/databases/$(database)/documents/chats/$(chatId)).data
                     );
    allow update: if isAuthenticated()
                  && (
                    // Revoke: only creator
                    (resource.data.createdBy == request.auth.uid
                     && request.resource.data.diff(resource.data).affectedKeys()
                          .hasOnly(['isRevoked']))
                    ||
                    // Redeem: any authenticated user
                    (request.resource.data.diff(resource.data).affectedKeys()
                          .hasOnly(['usedBy', 'useCount']))
                  );
    allow delete: if false;
  }
```

### 5.4 Audit Log Subcollection (NEW)

```javascript
  match /audit_log/{entryId} {
    allow read: if isAuthenticated()
                && isParticipant(
                     get(/databases/$(database)/documents/chats/$(chatId)).data
                   );
    allow create: if isAuthenticated()
                  && isParticipant(
                       get(/databases/$(database)/documents/chats/$(chatId)).data
                     );
    allow update: if false;
    allow delete: if false;
  }
```

### 5.5 Groups Public Collection (NEW)

```javascript
  match /{path=**}/groups/{doc} {
    allow read: if isAuthenticated()
                && resource.data.isPublic == true;
    allow write: if isAuthenticated()
                 && request.auth.uid == resource.data.createdBy;
  }
```

> **Defense in Depth (3 Layers):**  
> 1. **Client-side (Repository layer):** Granular permission checks (`GroupPermissions.hasPermission()`) — κάθε allowed action ελέγχει το σωστό permission με override support.  
> 2. **Server-side (Security Rules):** Role-based gates (πιο πάνω) — αποτρέπουν privilege escalation χωρίς να αναπαράγουν όλο το granular σύστημα. Admin+ για group metadata, creator-only για roles/permissions/limits.  
> 3. **Data validation (Security Rules):** Type checks, size limits (`participants.size() >= 2`, `<= maxParticipants`) — αποτρέπουν malformed writes.  
>
> Το granular permission system (π.χ. member με `inviteMembers: true`) **δεν αναπαράγεται στα rules** — θα ήταν maintenance nightmare. Αντ' αυτού, τα rules παρέχουν minimum role gate: admin+ για προσθήκη/αφαίρεση μελών, creator για roles/permissions. Αυτό σημαίνει ότι ένα member με granular `inviteMembers: true` θα απορριφθεί από τα rules αν κάνει raw Firestore call, αλλά θα περάσει από το client-side code (όπου ελέγχεται το granular permission). Αυτό είναι αποδεκτό: ο επιτιθέμενος με raw access δεν μπορεί να κάνει privilege escalation, ακόμα κι αν χάσει granular overrides.

---

## 6. Permission System

### 6.1 GroupPermission Enum

```dart
/// Granular permissions for group chat management.
/// Each permission represents a specific action a participant can perform.
enum GroupPermission {
  /// Πρόσκληση νέων μελών
  inviteMembers,

  /// Αφαίρεση υπαρχόντων μελών
  removeMembers,

  /// Διαγραφή μηνυμάτων (οποιουδήποτε)
  deleteMessages,

  /// Αλλαγή ονόματος ομάδας
  changeGroupName,

  /// Αλλαγή avatar ομάδας
  changeGroupAvatar,

  /// Διαχείριση permissions άλλων μελών
  managePermissions,

  /// Προαγωγή/υποβιβασμός Admin
  manageAdmins,

  /// Καρφίτσωμα μηνυμάτων (future phase)
  pinMessages,
}
```

### 6.2 Default Permissions ανά Role

| Permission | `creator` | `admin` | `member` |
|---|---|---|---|
| `inviteMembers` | ✅ | ✅ | ❌ |
| `removeMembers` | ✅ | ✅ | ❌ |
| `deleteMessages` | ✅ | ✅ | ❌ |
| `changeGroupName` | ✅ | ✅ | ❌ |
| `changeGroupAvatar` | ✅ | ✅ | ❌ |
| `managePermissions` | ✅ | ❌ | ❌ |
| `manageAdmins` | ✅ | ❌ | ❌ |
| `pinMessages` | ✅ | ✅ | ❌ |

### 5.3 Effective Permission Calculation

```dart
class GroupPermissions {
  /// Υπολογίζει effective permission για έναν χρήστη.
  /// Η σειρά προτεραιότητας:
  /// 1. Αν το permission είναι explicitly στο permissionOverrides → override value
  /// 2. Αλλιώς → default του role
  static bool hasPermission({
    required String uid,
    required Map<String, String> roles,
    required Map<String, Map<String, bool>> overrides,
    required GroupPermission permission,
  }) {
    final role = roles[uid] ?? 'member';
    final userOverrides = overrides[uid];

    // Explicit override υπάρχει;
    if (userOverrides != null && userOverrides.containsKey(permission.name)) {
      return userOverrides[permission.name]!;
    }

    // Default βάσει ρόλου
    return _defaultForRole(role, permission);
  }

  static bool _defaultForRole(String role, GroupPermission p) {
    if (role == 'creator' || role == 'admin') {
      // creator & admin έχουν όλα τα defaults, εκτός manageAdmins/managePermissions
      if (!kIsWeb) {
        // Web-safe
      }
      return role == 'creator' || (p != GroupPermission.manageAdmins
                                  && p != GroupPermission.managePermissions);
    }
    return false; // member = κανένα default
  }
}
```

### 5.4 Permission Overrides in Firestore

```javascript
// Στο /chats/{chatId} document:
"permissionOverrides": {
  "uid3": {
    "inviteMembers": true,    // Νίκος: μπορεί να προσκαλεί
    "deleteMessages": false   // Νίκος: ΔΕΝ μπορεί να διαγράφει (explicit block)
  }
}
```

### 5.5 Permission Check Pattern

```dart
/// Repository-level check. Throws AppException αν δεν έχει δικαίωμα.
Future<void> _requirePermission(
  String chatId,
  GroupPermission permission,
) async {
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final data = chatDoc.data()!;
  final roles = Map<String, String>.from(data['participantRoles'] ?? {});
  final overrides = Map<String, Map<String, bool>>.from(
    (data['permissionOverrides'] as Map?)?.map(
      (k, v) => MapEntry(k, Map<String, bool>.from(v as Map)),
    ) ?? {},
  );

  if (!GroupPermissions.hasPermission(
    uid: _auth.currentUser!.uid,
    roles: roles,
    overrides: overrides,
    permission: permission,
  )) {
    throw AppException.auth(
      permission.name,
      _permissionDeniedMessage(permission),
    );
  }
}
```

### 5.6 UI — Διαχείριση από Creator

**GroupInfoScreen → tap σε συμμετέχοντα → PermissionsEditor:**

```
┌──────────────────────────────────┐
│  Δικαιώματα: Νίκος               │
│  Τρέχων ρόλος: Μέλος             │
├──────────────────────────────────┤
│  Βασικά δικαιώματα:              │
│  [✓] Πρόσκληση νέων μελών        │
│  [ ] Αφαίρεση μελών              │
│  [ ] Διαγραφή μηνυμάτων          │
│  [ ] Αλλαγή ονόματος ομάδας      │
│  [ ] Αλλαγή εικόνας ομάδας       │
│                                   │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│  Για Διαχειριστές:               │
│  [ ] Καρφίτσωμα μηνυμάτων        │
│                                   │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│  Διαχείριση (μόνο Creator):      │
│  [⭐] Προαγωγή σε Admin          │
│  [⛔] Διαγραφή από ομάδα         │
│                                   │
│  [↺] Επαναφορά σε προεπιλογή     │
└──────────────────────────────────┘
```

### 5.7 Permission Rules Matrix

| Ενέργεια | Creator | Admin | Member (+override) | Member (default) |
|---|---|---|---|---|
| Αλλαγή ονόματος | ✅ | ✅ | ✅ (with override) | ❌ |
| Προσθήκη μέλους | ✅ | ✅ | ✅ (with override) | ❌ |
| Αφαίρεση μέλους | ✅ | ✅ | ❌ (ΠΟΤΕ χωρίς override) | ❌ |
| Διαγραφή μηνύματος | ✅ | ✅ | ❌ | ❌ |
| Αλλαγή permissions | ✅ | ❌ | ❌ | ❌ |
| Προαγωγή σε Admin | ✅ | ❌ | ❌ | ❌ |
| Διαγραφή ομάδας | ✅ | ❌ | ❌ | ❌ |

---

## 7. Encryption Strategy

### Απόφαση: **Deterministic key derivation (unchanged)**

```dart
// Ίδιο με 1-to-1 — ΔΕΝ χρειάζεται αλλαγή
static encrypt.Key deriveKey(String chatId) {
  final hash = sha256.convert(utf8.encode('near_me_e2e_key_$chatId'));
  return encrypt.Key(Uint8List.fromList(hash.bytes));
}
```

### Λόγοι:
1. `deriveKey(chatId)` = SHA-256(salt + chatId) → **deterministic**
2. Όλοι οι participants ξέρουν το chatId → μπορούν να παράγουν το ίδιο key
3. Νέος participant: προστίθεται στο chat → γνωρίζει chatId → deriveKey → διαβάζει history
4. `EncryptionUtils.getKeyOrDerive(chatId)` ήδη δουλεύει: δοκιμάζει stored key, πέφτει στο derive
5. System messages (type: 'system') δεν κρυπτογραφούνται — είναι metadata όπως join/leave

### Trade-off:
- Αποχωρήσαντες participants μπορούν ακόμα να διαβάσουν παλιά μηνύματα (ίδιο limitation με 1-to-1)
- Λύση: key rotation (μελλοντική φάση) — νέο generateKey + re-encrypt ή new messages only

---

## 8. Drift Schema Migration (v8 → v9)

### 8.1 ChatCacheTable — Νέες Στήλες

```dart
// Υπάρχουσες (unchanged):
IntColumn get id => integer().autoIncrement()();
TextColumn get ownerUid => text().nullable()();
TextColumn get chatId => text().nullable()();
TextColumn get otherUid => text().nullable()();
TextColumn get otherNickname => text().nullable()();
TextColumn get otherAvatarUrl => text().nullable()();
DateTimeColumn get lastMessageAt => dateTime().nullable()();
TextColumn get lastMessage => text().nullable()();
TextColumn get lastMessageSender => text().nullable()();
TextColumn get lastMessageType => text().nullable()();
IntColumn get unreadCount => integer().withDefault(const Constant(0))();
BoolColumn get hasUnread => boolean().withDefault(const Constant(false))();

// ΝΕΕΣ (v9):
BoolColumn get isGroupChat => boolean().withDefault(const Constant(false))();
IntColumn get participantCount => integer().withDefault(const Constant(2))();
TextColumn get participantUids => text().nullable()();  // JSON array ["uid1","uid2",...]
TextColumn get groupName => text().nullable()();
```

### 8.2 Database Migration (database.dart)

```dart
if (from < 9) {
  await m.addColumn(chatCacheTable, chatCacheTable.isGroupChat);
  await m.addColumn(chatCacheTable, chatCacheTable.participantCount);
  await m.addColumn(chatCacheTable, chatCacheTable.participantUids);
  await m.addColumn(chatCacheTable, chatCacheTable.groupName);
  DebugConfig.log(DebugConfig.databaseLocal,
      'Migration v8->v9: added group chat columns to ChatCache');
}
```

### 8.3 Τα υπάρχοντα 1-to-1 chats παίρνουν default τιμές:
- `isGroupChat = false`
- `participantCount = 2`
- `participantUids = null`
- `groupName = null`

### 8.4 Cache Matching: ΠΑΝΤΑ μέσω chatId (ποτέ otherUid)

> **Κρίσιμο (Session 153 fix):** Κάθε read/update/delete στο `ChatCacheTable` γίνεται αποκλειστικά μέσω `chatId.equals(chatId)`, όχι μέσω `otherUid`. Αυτό ισχύει ήδη για 1-to-1 και είναι **υποχρεωτικό** για groups όπου `otherUid = null`.

```dart
// ΣΩΣΤΟ — matching via chatId:
await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
    .write(...);

// ΛΑΘΟΣ — ΠΟΤΕ via otherUid (θα δημιουργήσει duplicate rows):
await (_db.update(_db.chatCacheTable)..where((t) => t.otherUid.equals(otherUid)))
    .write(...);
```

Το duplicate-row guard (select→detect >1→delete all→reset) παραμένει ως defense-in-depth:

```dart
var rows = await (_db.select(_db.chatCacheTable)
  ..where((t) => t.chatId.equals(chatId))
).get();

if (rows.length > 1) {
  await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
  rows = [];
}
```

---

## 9. Repository Changes

### 9.1 ChatRepository (abstract) — Νέες Μέθοδοι

```dart
abstract class ChatRepository {
  // Υπάρχουσες (unchanged):
  Future<String> createChat(String otherUid);
  Future<void> sendMessage(String chatId, String content);
  Future<List<ChatCacheTableData>> getChats();
  Stream<List<ChatCacheTableData>> streamChats();
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId);
  Future<void> markAsRead(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> clearMessages(String chatId);

  // ΝΕΕΣ για Group Chat:
  /// Δημιουργεί ομαδική συνομιλία.
  Future<String> createGroupChat(
    List<String> participantUids, {
    String? groupName,
  });

  /// Προσθέτει νέο συμμετέχοντα. Απαιτεί permission inviteMembers.
  Future<void> addParticipant(String chatId, String newUid);

  /// Αφαιρεί συμμετέχοντα (αποχώρηση ή διαγραφή από admin).
  /// Αν ο uid == currentUser → αποχώρηση
  /// Αν ο uid != currentUser → απαιτεί permission removeMembers
  Future<void> removeParticipant(String chatId, String uid);

  /// Επιστρέφει λίστα ενεργών UIDs συμμετεχόντων.
  Future<List<String>> getParticipantUids(String chatId);

  /// Stream με λίστα ενεργών UIDs (real-time).
  Stream<List<String>> participantUidsStream(String chatId);

  /// Αλλάζει όνομα ομάδας. Απαιτεί permission changeGroupName.
  Future<void> updateGroupName(String chatId, String name);

  /// Αλλάζει ρόλο συμμετέχοντα. Απαιτεί permission manageAdmins.
  Future<void> updateParticipantRole(
    String chatId, String uid, String newRole);

  /// Αλλάζει permission override για συμμετέχοντα.
  /// Απαιτεί permission managePermissions.
  Future<void> updatePermissionOverride(
    String chatId,
    String uid,
    GroupPermission permission,
    bool value,
  );

  /// Ελέγχει αν ο χρήστης έχει συγκεκριμένο δικαίωμα.
  Future<bool> hasPermission(String chatId, GroupPermission permission);

  /// Επιστρέφει roles map + permission overrides.
  Future<GroupPermissionsInfo> getPermissionsInfo(String chatId);
}
```

### 9.2 ChatRepositoryImpl — Ομαδοποίηση

Λόγω του ορίου 500 γραμμών, η υλοποίηση χωρίζεται:

```
chat_repository_impl.dart
├── ChatRepositoryImpl (1-to-1 methods — υπάρχον)
│   ├── createChat
│   ├── sendMessage
│   ├── streamChats
│   ├── messagesStream
│   ├── markAsRead          (1-to-1: isRead batch · group: επιστρέφει στο mixin)
│   ├── deleteChat
│   └── clearMessages
│
└── with GroupChatMixin     (βλ. group_chat_mixin.dart)

——— Ξεχωριστό αρχείο ———

group_chat_mixin.dart
└── mixin GroupChatMixin on ChatRepositoryImpl
    ├── createGroupChat
    ├── addParticipant
    ├── removeParticipant
    ├── updateGroupName
    ├── updateParticipantRole
    ├── updatePermissionOverride
    ├── updateMaxParticipants
    ├── markAsRead*          (override — group branch)
    ├── hasPermission
    ├── getPermissionsInfo
    ├── _requirePermission   (private)
    ├── _enforceParticipantLimit
    ├── _sendSystemMessage
    ├── _logAudit
    └── _maybeTransferCreator[OnLeave]
```

> **Σημαντικό:** Το `markAsRead` στο `ChatRepositoryImpl` γίνεται `@override` από το mixin για group mode (βλ. §16). Η 1-to-1 ροή μένει αμετάβλητη.  
> **Line count:** `chat_repository_impl.dart` πέφτει ~150 γραμμές (αφαιρούνται οι group methods). `group_chat_mixin.dart` ~350 γραμμές. Και τα δύο κάτω από 500.

### 9.3 Βασικές Υλοποιήσεις

#### createGroupChat

```dart
Future<String> createGroupChat(
  List<String> participantUids, {
  String? groupName,
}) async {
  final user = _auth.currentUser;
  if (user == null) throw AppException.auth(...);
  final uid = user.uid;

  // Validation (client-side, rules will enforce server-side)
  if (participantUids.length < 1) throw AppException(...) // need at least 1 other
  if (participantUids.length > 9) throw AppException(...) // max 10 total (1 + 9)
  if (participantUids.contains(uid)) throw AppException(...) // no self
  if (participantUids.any((id) => id.isEmpty)) throw AppException(...)
  if (participantUids.toSet().length != participantUids.length) throw AppException(...) // no duplicates

  // Get my nickname
  final myProfile = await _firestore
      .collection('users').doc(uid).collection('public').doc('profile').get();
  final myNickname = myProfile.data()?['nickname'] as String? ?? uid;

  // Get nicknames for all participants (parallel)
  final nicknameFutures = participantUids.map((pUid) async {
    final doc = await _firestore
        .collection('users').doc(pUid).collection('public').doc('profile').get();
    return MapEntry(pUid, doc.data()?['nickname'] as String? ?? pUid);
  });
  final nicknames = Map.fromEntries(await Future.wait(nicknameFutures));
  nicknames[uid] = myNickname;

  final chatId = _firestore.collection('chats').doc().id;
  final now = FieldValue.serverTimestamp();
  final allUids = [uid, ...participantUids];

  await _firestore.collection('chats').doc(chatId).set({
    'participants': allUids,
    'participantNicknames': nicknames,
    'participantRoles': {
      uid: 'creator',
      for (final pUid in participantUids) pUid: 'member',
    },
    'permissionOverrides': {},
    'participantJoinedAt': {
      for (final pUid in allUids) pUid: now,
    },
    'participantInvitedBy': {
      for (final pUid in participantUids) pUid: uid,
    },
    'participantIsActive': {
      for (final pUid in allUids) pUid: true,
    },
    'maxParticipants': 10,
    'isGroupChat': true,
    'groupName': groupName ?? _defaultGroupName(nicknames),
    'createdAt': now,
    'isActive': true,
  });

  // Encryption: deriveKey works deterministically — όλοι οι participants
  // θα μπορούν να το derive γνωρίζοντας το chatId.
  final key = EncryptionUtils.deriveKey(chatId);
  await EncryptionUtils.storeKey(chatId, key);

  // System message
  await _sendSystemMessage(chatId, 'group_created', uid, participantUids);

  DebugConfig.log(DebugConfig.repositoryResult, 'createGroupChat: $chatId with ${allUids.length} participants');
  return chatId;
}
```

**Helper μέθοδος (ίδιο mixin):**

```dart
/// Default group name: μέχρι 3 ονόματα + "+N ακόμα" αν υπάρχουν περισσότερα.
String _defaultGroupName(Map<String, String> nicknames) {
  final names = nicknames.values.toList();
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} +${names.length - 3} ακόμα';
}
```

#### addParticipant

```dart
Future<void> addParticipant(String chatId, String newUid) async {
  final uid = _auth.currentUser!.uid;

  // Permission check
  await _requirePermission(chatId, GroupPermission.inviteMembers);

  // Validate
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final data = chatDoc.data()!;
  final participants = List<String>.from(data['participants'] ?? []);
  if (participants.contains(newUid)) throw AppException(...) // already in
  if (participants.length >= (data['maxParticipants'] ?? 10)) throw AppException(...) // at max
  if (newUid == uid) throw AppException(...); // self

  // Block check (parallel — οποιοσδήποτε blocker)
  final futureIsBlocked = participants.map((pUid) async {
    final doc = await _firestore.doc('users/$pUid/blocked/$newUid').get();
    return doc.exists;
  });
  final blockedBy = await Future.wait(futureIsBlocked);
  if (blockedBy.any((b) => b)) throw AppException(...) // blocked by participant

  // Get nickname (parallel)
  final nicknameFuture = participants.map((pUid) async {
    final doc = await _firestore
        .collection('users').doc(pUid).collection('public').doc('profile').get();
    final nickname = doc.data()?['nickname'] as String? ?? pUid;
    return MapEntry(pUid, nickname);
  });
  final nicknames = Map.fromEntries(await Future.wait(nicknameFuture));
  final newDoc = await _firestore
      .collection('users').doc(newUid).collection('public').doc('profile').get();
  nicknames[newUid] = newDoc.data()?['nickname'] as String? ?? newUid;

  // Firestore update (transaction-safe)
  await _firestore.runTransaction((transaction) async {
    final snap = await transaction.get(chatDoc.reference);
    final currentParticipants = List<String>.from(snap.data()!['participants'] ?? []);
    if (currentParticipants.contains(newUid)) return; // race — already added
    if (currentParticipants.length >= (snap.data()!['maxParticipants'] ?? 10)) return;

    transaction.update(chatDoc.reference, {
      'participants': FieldValue.arrayUnion([newUid]),
      'participantNicknames.$newUid': nicknames[newUid],
      'participantRoles.$newUid': 'member',
      'participantJoinedAt.$newUid': FieldValue.serverTimestamp(),
      'participantInvitedBy.$newUid': uid,
      'participantIsActive.$newUid': true,
    });
  });

  // System message
  await _sendSystemMessage(chatId, 'participant_added', uid, [newUid]);
}
```

#### removeParticipant (αποχώρηση ή αφαίρεση)

```dart
Future<void> removeParticipant(String chatId, String targetUid) async {
  final uid = _auth.currentUser!.uid;
  final isSelf = targetUid == uid;

  if (!isSelf) {
    await _requirePermission(chatId, GroupPermission.removeMembers);
  }

  await _firestore.collection('chats').doc(chatId).update({
    'participants': FieldValue.arrayRemove([targetUid]),
    'participantIsActive.$targetUid': false,
  });

  // Αν ο targetUid ήταν creator + αποχωρεί → transfer creator
  if (!isSelf) {
    await _maybeTransferCreator(chatId, targetUid);
  } else {
    await _maybeTransferCreatorOnLeave(chatId, uid);
  }

  // System message
  await _sendSystemMessage(chatId,
      isSelf ? 'participant_left' : 'participant_removed',
      isSelf ? uid : uid, // sender
      [targetUid]);

  // Local cleanup
  await _removeChatCache(chatId);
}
```

### 9.4 Permission Info Model

```dart
class GroupPermissionsInfo {
  final Map<String, String> roles;           // uid → role
  final Map<String, Map<String, bool>> overrides; // uid → permission → value

  GroupPermissionsInfo({
    required this.roles,
    required this.overrides,
  });

  bool hasPermission(String uid, GroupPermission p) {
    return GroupPermissions.hasPermission(
      uid: uid,
      roles: roles,
      overrides: overrides,
      permission: p,
    );
  }
}
```

### 9.5 `_syncChatFromFirestore` — Group Support (Blockers)

> **Προσοχή:** Η υπάρχουσα `_syncChatFromFirestore` (γραμμή ~328) έχει `if (otherUid == null) return;` — **θα αποκλείσει εντελώς τα groups από το local cache.** Πρέπει να γίνει group-aware.

```dart
Future<void> _syncChatFromFirestore(String chatId, Map<String, dynamic> data) async {
  // ... υπάρχον preamble ...

  // ΒΛΟΚΕΡ: group chats με isGroupChat==true έχουν otherUid == null
  // → ΠΡΕΠΕΙ να μπει `if (isGroupChat)` branch ΠΡΙΝ το early return
  final isGroupChat = data['isGroupChat'] == true;
  if (isGroupChat) {
    await _syncGroupChatToCache(chatId, data);  // ομαδική sync (βλ. παρακάτω)
    return;
  }

  // Υπάρχουσα ροή 1-to-1 (unchanged):
  final otherUid = participants.where((p) => p != uid).firstOrNull;
  if (otherUid == null) return;  // guard — group chats δεν φτάνουν εδώ πλέον
  // ... rest of 1-to-1 sync ...
}

Future<void> _syncGroupChatToCache(String chatId, Map<String, dynamic> data) async {
  final uid = _auth.currentUser!.uid;

  var rows = await (_db.select(_db.chatCacheTable)
    ..where((t) => t.chatId.equals(chatId))
  ).get();

  if (rows.length > 1) {
    await (_db.delete(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId))).go();
    rows = [];
  }

  final groupName = data['groupName'] as String?;
  final participants = List<String>.from(data['participants'] ?? []);
  final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
  final lastMessageBy = data['lastMessageBy'] as String?;
  final lastMessageType = data['lastMessageType'] as String? ?? 'text';
  final encryptedLastMessage = data['lastMessage'] as String?;

  // Unread count via lastReadTimestamps (βλ. §16.3)
  final lastRead = data['lastReadTimestamps']?[uid]?.toDate() ?? DateTime(2020);
  int unreadCount = 0;
  if (lastMessageBy != null && lastMessageBy != uid) {
    try {
      final count = await _firestore
          .collection('chats').doc(chatId).collection('messages')
          .where('senderId', isNotEqualTo: uid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastRead))
          .count().get();
      unreadCount = count.count ?? 0;
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

  if (rows.isNotEmpty) {
    final existing = rows.first;
    await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
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
          participantCount: Value(participants.length),
          participantUids: Value(participants.join(',')),  // CSV για Drift text
          isGroupChat: const Value(true),
        ));
  } else {
    await _db.into(_db.chatCacheTable).insert(
      ChatCacheTableCompanion.insert(
        chatId: Value(chatId),
        ownerUid: Value(uid),
        otherUid: const Value(null),               // groups: null
        otherNickname: const Value(null),           // groups: null
        otherAvatarUrl: const Value(null),           // groups: null
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
        participantUids: Value(participants.join(',')),
        isGroupChat: const Value(true),
      ),
    );
  }
}
```

> **Σημείωση:** `participantUids` αποθηκεύεται ως CSV string (όχι JSON) για συμβατότητα με Drift text queries. Η ανάγνωση γίνεται με `.split(',')`. Αυτό είναι read-heavy pattern (διαβάζεται σε κάθε chat list refresh) και write-seldom (μόνο όταν αλλάζουν participants).
>
> **Edge case:** empty participants → `''.split(',')` επιστρέφει `['']`, όχι `[]`. Χρειάζεται guard στο σημείο ανάγνωσης:
> ```dart
> final uids = participantUids == null || participantUids!.isEmpty
>     ? <String>[]
>     : participantUids!.split(',');
> ```
>
> **Unit tests required (πριν την ένταξη στο streamChats):**
> 1. **Dedup path:** 2+ rows με ίδιο chatId → 1 row μετά το sync
> 2. **Unread count:** mock lastReadTimestamps παλιό/νέο → σωστό unreadCount
> 3. **Insert vs Update:** πρώτη sync (insert) vs επόμενη sync (update)
> 4. **System message lastMessage:** skip decrypt, παραμένει ως έχει

---

## 10. Invite Link / Group Sharing

### 10.1 Επισκόπηση

Δημιουργία μοναδικών invite links που επιτρέπουν σε νέους χρήστες να συμμετάσχουν σε group χωρίς απευθείας πρόσκληση από admin.

### 10.2 SPoT: `GroupInviteService`

```dart
/// Single Point of Truth για όλη τη λογική invite links.
/// Δημιουργία, εξαργύρωση, ανάκληση, πληροφορίες.
class GroupInviteService {
  static Future<String> createInviteLink({
    required String chatId,
    Duration expiresIn = const Duration(days: 7),
    int? maxUses,
  }) async { ... }

  /// Εξαργύρωση token. Επιστρέφει chatId ή null αν άκυρο/ληγμένο.
  static Future<String?> redeemInvite(String token) async { ... }

  /// Πληροφορίες για preview (χωρίς εξαργύρωση).
  static Future<InviteInfo?> getInviteInfo(String token) async { ... }

  /// Ανάκληση (μόνο από creator).
  static Future<void> revokeInvite(String chatId, String inviteId) async { ... }

  /// Λίστα ενεργών invites ενός chat.
  static Future<List<InviteInfo>> getActiveInvites(String chatId) async { ... }
}
```

### 10.3 ChatRepository — Νέες Μέθοδοι

```dart
abstract class ChatRepository {
  /// Δημιουργεί invite link για group.
  Future<String> createInviteLink(String chatId, {
    Duration expiresIn = const Duration(days: 7),
    int? maxUses,
  });

  /// Εξαργυρώνει invite token. Επιστρέφει chatId ή null.
  Future<String?> redeemInviteLink(String token);

  /// Παίρνει πληροφορίες invite (groupName, memberCount κλπ).
  Future<InviteInfo?> getInviteInfo(String token);

  /// Ανακαλεί invite.
  Future<void> revokeInvite(String chatId, String inviteId);

  /// Λίστα ενεργών invites.
  Future<List<InviteInfo>> getActiveInvites(String chatId);
}
```

### 10.4 Firestore Invite Schema

Δείτε Section 4.3 — `/chats/{chatId}/invites/{inviteId}`.

### 10.5 UI Flow

```
GroupInfoScreen → "Πρόσκληση μέσω συνδέσμου"
  → Δημιουργία link (copy to clipboard)
  → Share sheet (native)
  → Ο παραλήπτης ανοίγει το link
    → App link: nearme://join?token=abc123
    → Web fallback: https://nearme.app/join?token=abc123
  → JoinConfirmationScreen:
    ┌──────────────────────────────┐
    │  Πρόσκληση σε "Φίλοι Αθήνα"  │
    │  👥 4 μέλη                   │
    │  Από: Νίκος                  │
    │                              │
    │  [✓ Αποδοχή Πρόσκλησης]     │
    └──────────────────────────────┘
```

---

## 11. Group Discovery & Join

### 11.1 Επισκόπηση

Δυνατότητα αναζήτησης δημόσιων groups και αίτησης συμμετοχής. Ακολουθεί το ίδιο pattern με το `SearchRepository` (Firestore native → Typesense future).

### 11.2 SPoT: `GroupSearchRepository`

```dart
/// Single Point of Truth για αναζήτηση groups.
/// Repository pattern — ίδιο interface pattern με SearchRepository.
abstract class GroupSearchRepository {
  /// Αναζήτηση δημόσιων groups.
  Future<List<GroupPublicProfile>> searchGroups({
    String? query,       // groupName partial match
    String? city,
    List<String>? tags,
    int limit = 20,
  });

  /// Δημιουργία public profile για group.
  Future<void> createPublicProfile(String chatId, GroupPublicProfile profile);

  /// Ενημέρωση public profile.
  Future<void> updatePublicProfile(String chatId, GroupPublicProfile profile);

  /// Διαγραφή public profile (όταν γίνει private ή διαγραφεί).
  Future<void> deletePublicProfile(String chatId);
}
```

### 11.3 Firestore Schema

Δείτε Section 4.5 — `/groups/{chatId}` collection.

### 11.4 UI Flow

```
ChatListScreen → 🔍 Εικονίδιο αναζήτησης (δίπλα στο FAB)
  → GroupSearchScreen
    ┌──────────────────────────────┐
    │ 🔍 Αναζήτησε ομάδες...       │
    │                              │
    │ ─── Κοντινές ομάδες ───      │
    │ 👥 Φίλοι Αθήνα (4)    2km   │
    │    Παρέα για εξόδους         │
│    [Συμμετοχή]               │
│                              │
│ 👥 Gamers Club (12)   5km   │
│    Valorant, CS2, LoL        │
│    [Συμμετοχή]               │
└──────────────────────────────┘
```

### 11.5 Firestore Indexes (collectionGroup 'groups')

Ακολουθεί το ίδιο μοτίβο με το υπάρχον `firestore_search_repository.dart` (4 query paths → 4 composite indexes):

```javascript
// firestore.indexes.json — νέες εγγραφές
[
  // 1. Basic: isPublic == true, orderBy __name__
  {
    "collectionGroup": "groups",
    "queryScope": "COLLECTION_GROUP",
    "fields": [
      { "fieldPath": "isPublic", "order": "ASCENDING" },
      { "fieldPath": "__name__", "order": "ASCENDING" }
    ]
  },
  // 2. City filter: isPublic == true, city == value, orderBy __name__
  {
    "collectionGroup": "groups",
    "queryScope": "COLLECTION_GROUP",
    "fields": [
      { "fieldPath": "isPublic", "order": "ASCENDING" },
      { "fieldPath": "city", "order": "ASCENDING" },
      { "fieldPath": "__name__", "order": "ASCENDING" }
    ]
  },
  // 3. Tags filter: isPublic == true, tags array-contains, orderBy __name__
  {
    "collectionGroup": "groups",
    "queryScope": "COLLECTION_GROUP",
    "fields": [
      { "fieldPath": "isPublic", "order": "ASCENDING" },
      { "fieldPath": "tags", "order": "ASCENDING" },
      { "fieldPath": "__name__", "order": "ASCENDING" }
    ]
  },
  // 4. Newest first: isPublic == true, orderBy createdAt DESC
  {
    "collectionGroup": "groups",
    "queryScope": "COLLECTION_GROUP",
    "fields": [
      { "fieldPath": "isPublic", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" }
    ]
  }
]
```

> **Σημείωση:** Αυτά τα indexes είναι **προαπαιτούμενο** πριν το πρώτο deploy του GroupSearchRepository, αλλιώς τα queries θα αποτύχουν με `FAILED_PRECONDITION` (όπως Session 100). Το deployment γίνεται με `firebase deploy --only firestore:indexes`.

---

## 12. @Mentions

### 12.1 Επισκόπηση

Ο χρήστης μπορεί να κάνει @mention άλλων μελών του group. Το mentioned μέλος λαμβάνει ειδικό FCM notification.

### 12.2 SPoT: `MentionService`

```dart
/// Single Point of Truth για @mentions.
class MentionService {
  /// Εξάγει mentions από κείμενο. Επιστρέφει λίστα UIDs.
  static List<String> extractMentions(
    String text,
    Map<String, String> participantNicknames, // uid → nickname
  );

  /// Επιστρέφει το text με visual highlight markers.
  static String formatForDisplay(String text);

  /// Ελέγχει ότι τα mentions αναφέρονται σε υπάρχοντες participants.
  static List<String> validateParticipants(
    List<String> mentionedUids,
    List<String> participantUids,
  );
}
```

### 12.3 sendMessage Extended

```dart
Future<void> sendMessage(String chatId, String content) async {
  // Υπάρχουσα ροή (encrypt, batch, κλπ) ...

  // ΝΕΟ: Extract mentions before encryption
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final nicknames = Map<String, String>.from(
      chatDoc.data()?['participantNicknames'] ?? {});
  final mentionedUids = MentionService.extractMentions(content, nicknames);
  final validMentions = MentionService.validateParticipants(
      mentionedUids, chatDoc.data()?['participants'] ?? []);

  if (validMentions.isNotEmpty) {
    msgRef.set({
      ...baseData,
      'mentions': validMentions,     // ΕΠΙΠΛΕΟΝ πεδίο
    }, SetOptions(merge: true));
  }
}
```

### 12.4 FCM Mention Notification

```dart
// Στην Cloud Function sendFcmNewMessage:
if (message.data['mentions'] != null && message.data['mentions'].length > 0) {
  // Στείλτε ειδικό notification μόνο στους mentioned users:
  // "Ο Νίκος σε ανέφερε στην ομάδα 'Φίλοι Αθήνα'"
}
```

### 12.5 UI

Στο `_MessageBubble`: αν το μήνυμα έχει mentions και ο currentUser είναι μέσα, highlight το όνομα του @ με διαφορετικό χρώμα (π.χ. primary color, bold).

---

## 13. Group Avatar

### 13.1 Επισκόπηση

Δυνατότητα ορισμού εικόνας για το group, ακολουθώντας το ίδιο pattern με το profile avatar.

### 13.2 SPoT: `GroupAvatarService`

```dart
/// Single Point of Truth για group avatar upload/delete.
/// Ίδιο pattern με ProfileRepository avatar flow.
class GroupAvatarService {
  static Future<String?> uploadAvatar(
    String chatId,
    XFile image, {
    bool cropRequired = true,
  }) async {
    // 1. image_cropper (1:1 locked)
    // 2. Compress (400x400 max)
    // 3. Upload to Firebase Storage: /group_avatars/{chatId}/avatar.jpg
    // 4. Get download URL
    // 5. Update Firestore chat doc: groupAvatarUrl = url
    // 6. Return URL
  }

  static Future<void> deleteAvatar(String chatId) async {
    // 1. Delete from Storage
    // 2. Update Firestore doc: groupAvatarUrl = null
  }
}
```

### 13.3 ChatRepository — Νέες Μέθοδοι

```dart
abstract class ChatRepository {
  Future<void> updateGroupAvatar(String chatId, XFile image);
  Future<void> removeGroupAvatar(String chatId);
}
```

### 13.4 Storage Rules

```
match /group_avatars/{chatId}/avatar.jpg {
  allow read: if isAuthenticated();
  allow write: if isAuthenticated()
               && isParticipant(chatId);
  allow delete: if isAuthenticated()
                && isParticipant(chatId);
  // Max size: 5MB
}
```

### 13.5 UI

```
GroupInfoScreen → tap στο group avatar → bottom sheet:
  ┌──────────────────────────────┐
  │  📷 Επιλογή φωτογραφίας      │
  │  🗑 Διαγραφή φωτογραφίας     │
  └──────────────────────────────┘
  → Image picker → cropper (1:1) → upload → update UI
```

---

## 14. Group Audit Log

### 14.1 Επισκόπηση

Καταγραφή όλων των σημαντικών αλλαγών στο group (όπως ConsentLog για το profile). Δεν αποθηκεύεται τοπικά — Firestore subcollection.

### 14.2 SPoT: `GroupAuditLogService`

```dart
/// Single Point of Truth για audit log.
/// Γράφει ΔΙΑΒΑΖΕΙ ΠΑΝΤΑ από Firestore subcollection.
class GroupAuditLogService {
  static Future<void> log({
    required String chatId,
    required String action,
    required String actorUid,
    String? targetUid,
    Map<String, dynamic>? details,
  }) async { ... }

  /// Stream με audit log entries (Firestore orderBy timestamp desc).
  static Stream<List<AuditLogEntry>> streamLog(String chatId, {int limit = 50});

  /// Pagination (load older).
  static Future<List<AuditLogEntry>> loadMore(
    String chatId, {
    required DocumentSnapshot? lastVisible,
    int limit = 50,
  });
}
```

### 14.3 Actions Matrix

| Action | Trigger | Actor | Details |
|---|---|---|---|
| `group_created` | createGroupChat | Creator | participantUids |
| `participant_added` | addParticipant | Admin/Creator | targetUid, invitedBy |
| `participant_removed` | removeParticipant | Admin/Creator | targetUid |
| `participant_left` | removeParticipant(self) | Member | - |
| `role_changed` | updateParticipantRole | Creator | oldRole, newRole |
| `permission_changed` | updatePermissionOverride | Creator | permission, oldValue, newValue |
| `name_changed` | updateGroupName | Admin/Creator | oldName, newName |
| `avatar_changed` | updateGroupAvatar | Admin/Creator | - |
| `max_participants_changed` | updateMaxParticipants | Creator | oldMax, newMax |

### 14.4 UI

```
GroupInfoScreen → [📋 Ιστορικό] button → GroupAuditLogScreen
  ┌──────────────────────────────┐
  │  ← Ιστορικό Αλλαγών          │
  │                              │
  │  🕐 9/7 12:30                │
  │  Νίκος: Άλλαξε όνομα         │
  │  "Παρέα" → "Φίλοι Αθήνα"    │
  │                              │
  │  🕐 9/7 12:15                │
  │  Μαρία: Προστέθηκε           │
  │  από Νίκος                   │
  │                              │
  │  🕐 9/7 12:00                │
  │  Νίκος: Δημιουργία ομάδας    │
  │                              │
  │  [📥 Παλαιότερες καταχωρήσεις] │
  └──────────────────────────────┘
```

---

## 15. Promote / Demote Admin

### 15.1 Επισκόπηση

Ο Creator μπορεί να προάγει member → admin και admin → member. Δεν μπορεί να υποβιβάσει τον εαυτό του.

### 15.2 SPoT: `ChatRepositoryImpl.updateParticipantRole()`

```dart
Future<void> updateParticipantRole(
  String chatId, String targetUid, String newRole,
) async {
  final uid = _auth.currentUser!.uid;

  // Μόνο creator μπορεί
  await _requirePermission(chatId, GroupPermission.manageAdmins);

  // Δεν μπορεί να αλλάξει role του creator
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final roles = Map<String, String>.from(chatDoc.data()?['participantRoles'] ?? {});
  if (roles[targetUid] == 'creator') throw AppException(...);
  if (targetUid == uid) throw AppException(...); // self-demotion guard

  // Δεν μπορεί να υποβιβάσει άλλο admin αν δεν έχει manageAdmins
  if (roles[targetUid] == 'admin' && newRole == 'member') {
    // allowed (creator always has manageAdmins)
  }

  final oldRole = roles[targetUid];
  await _firestore.collection('chats').doc(chatId).update({
    'participantRoles.$targetUid': newRole,
    // Clear permission overrides on demotion για security
    if (newRole == 'member')
      'permissionOverrides.$targetUid': {},
  });

  // Audit log
  await _logAudit(chatId, 'role_changed', uid,
      targetUid: targetUid,
      details: {'oldRole': oldRole, 'newRole': newRole});

  // System message
  await _sendSystemMessage(chatId, 'role_changed', uid, [targetUid, newRole]);
}
```

### 15.3 UI Flow

```
PermissionsEditor → tap [⭐ Προαγωγή σε Admin]
  → ConfirmDialog: "Θα προαχθεί ο Νίκος σε Admin. Συνέχεια;"
  → updateParticipantRole → UI update (role badge + permissions switch)

PermissionsEditor → tap [⬇ Υποβιβασμός σε Μέλος]
  → ConfirmDialog: "Θα αφαιρεθούν τα δικαιώματα Admin από τον Νίκο. Συνέχεια;"
  → updateParticipantRole → clear overrides → UI update
```

---

## 16. Read Receipts in Groups

### 16.1 Επισκόπηση

Αντί για batch update per-message (`readBy` array) που κοστίζει N writes ανά άνοιγμα chat, χρησιμοποιούμε **ένα field στο chat doc** (`lastReadTimestamps[uid] = Timestamp`).

**Κόστος:** 1 write/user/άνοιγμα (αντί N unread × M users).

**Λειτουργία:** Client-side σύγκριση: message `createdAt` ≤ `lastReadTimestamps[uid]` → "το uid το διάβασε".

### 16.2 SPoT: `ChatRepositoryImpl.markAsRead()` (extended)

```dart
Future<void> markAsRead(String chatId) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final uid = user.uid;

  // Group mode: 1 write στο chat doc (όχι batch per message)
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final isGroup = chatDoc.data()?['isGroupChat'] == true;

  if (isGroup) {
    await _firestore.collection('chats').doc(chatId).update({
      'lastReadTimestamps.$uid': FieldValue.serverTimestamp(),
    });
  } else {
    // Υπάρχουσα ροή 1-to-1 (unchanged — batch update isRead: true)
    final unread = await _firestore
        .collection('chats').doc(chatId).collection('messages')
        .where('isRead', isEqualTo: false).get();
    final docs = unread.docs
        .where((d) => d.data()['senderId'] != uid).toList();
    if (docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Update local cache
  await (_db.update(_db.chatCacheTable)..where((t) => t.chatId.equals(chatId)))
      .write(const ChatCacheTableCompanion(
        hasUnread: Value(false),
        unreadCount: Value(0),
      ));
}
```

### 16.3 `_syncChatFromFirestore` — Group Unread Count

```dart
// Στο _syncChatFromFirestore, όταν isGroupChat:
if (data['isGroupChat'] == true) {
  final lastRead = data['lastReadTimestamps']?[uid]?.toDate() ?? DateTime(2020);
  final count = await _firestore
      .collection('chats').doc(chatId).collection('messages')
      .where('senderId', isNotEqualTo: uid)
      .where('createdAt', isGreaterThan: Timestamp.fromDate(lastRead))
      .count().get();
  unreadCount = count.count;
} else {
  // Υπάρχον: .where('isRead', isEqualTo: false).count().get()
}
```

> **Απαιτεί index:** composite index στο `/chats/{chatId}/messages` on `(senderId, createdAt)`. Πιθανώς ήδη υπάρχει από άλλα queries.

### 16.4 UI — Seen By (client-side)

Στο `_MessageBubble` για group messages, αντί για διπλό τick, εμφανίζουμε **ονόματα που το διάβασαν** (up to 3):

```dart
// seenBy = participants όπου lastReadTimestamps[uid] >= message.createdAt (εκτός sender)
if (isGroup) {
  final seenBy = participantTimestamps.entries
      .where((e) => e.key != message.senderId
                  && e.value != null
                  && e.value >= message.createdAt)
      .map((e) => nicknames[e.key] ?? e.key)
      .toList();
  if (seenBy.isNotEmpty) {
    // "Είδατε: Νίκος, Μαρία +2" (max 3 names)
  }
}
```

### 16.5 1-to-1 Backward Compatibility

- Τα 1-to-1 messages συνεχίζουν να χρησιμοποιούν `isRead: bool` — **καμία αλλαγή**
- `markAsRead()` μπαίνει σε `if (isGroup)` branch — παλιά ροή αμετάβλητη
- `_MessageBubble` για 1-to-1: δείχνει `Icons.done` / `Icons.done_all` όπως πριν
- `_MessageBubble` για groups: δείχνει "Είδατε: ..." (αντί για read icon)

---

## 17. Max Participants Limit

### 17.1 Επισκόπηση

Default max 10 participants. Ο Creator μπορεί να αλλάξει το όριο (π.χ. 5, 20, 50).

### 17.2 SPoT: `GroupChatMixin._enforceParticipantLimit()`

```dart
/// Μοναδικό σημείο ελέγχου participant limit.
/// Καλείται από createGroupChat και addParticipant.
void _enforceParticipantLimit(int currentCount, int maxAllowed) {
  if (currentCount > maxAllowed) {
    throw AppException.validation(
      'max_participants',
      'Το μέγιστο όριο συμμετεχόντων είναι $maxAllowed / '
      'Maximum participant limit is $maxAllowed',
    );
  }
}

/// Ενημέρωση μέγιστου ορίου (μόνο creator).
Future<void> updateMaxParticipants(String chatId, int newMax) async {
  await _requirePermission(chatId, GroupPermission.manageAdmins);
  // Δεν μπορεί να είναι μικρότερο από τρέχοντες participants
  final chatDoc = await _firestore.collection('chats').doc(chatId).get();
  final currentCount = (chatDoc.data()?['participants'] as List?)?.length ?? 0;
  if (newMax < currentCount) throw AppException(...); // cannot reduce below current

  await _firestore.collection('chats').doc(chatId).update({
    'maxParticipants': newMax,
  });
  await _logAudit(chatId, 'max_participants_changed', uid,
      details: {'oldMax': oldMax, 'newMax': newMax});
}
```

### 17.3 UI

```
GroupInfoScreen → tap "4 από 10" → MaxParticipantsEditor
  ┌──────────────────────────────┐
  │  Μέγιστος Αριθμός Μελών      │
  │                              │
  │        [─]  10  [+]          │
  │       (5 - 100)              │
  │                              │
  │  [💾 Αποθήκευση]             │
  └──────────────────────────────┘
```

---

## 18. Provider Changes

### 18.1 ChatProvider — Νέοι Providers

```dart
// Νέο provider: stream με UIDs συμμετεχόντων
final participantUidsProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate,
      'participantUidsProvider created for chat: $chatId');
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.participantUidsStream(chatId);
});

// Νέο provider: permission info για group
final groupPermissionsProvider =
    FutureProvider.autoDispose.family<GroupPermissionsInfo?, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate,
      'groupPermissionsProvider created for chat: $chatId');
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getPermissionsInfo(chatId);
});
```

### 18.2 ChatActionsNotifier — Νέες Μέθοδοι

```dart
class ChatActionsNotifier extends Notifier<ChatActionState> {
  // Υπάρχουσες (unchanged):
  Future<String?> createChat(String otherUid) async { ... }
  Future<bool> sendMessage(String chatId, String content) async { ... }
  Future<void> markAsRead(String chatId) async { ... }
  Future<void> deleteChat(String chatId) async { ... }
  Future<void> clearMessages(String chatId) async { ... }

  // ΝΕΕΣ:
  Future<String?> createGroupChat(List<String> uids, {String? name}) async {
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      final chatId = await _chatRepo.createGroupChat(uids, groupName: name);
      state = ChatActionState(status: ChatActionStatus.success, createdChatId: chatId);
      ref.invalidate(chatsProvider);
      return chatId;
    } catch (e, s) {
      DebugConfig.error('ChatActions: createGroupChat failed', data: e, exception: s);
      state = ChatActionState(status: ChatActionStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<void> addParticipant(String chatId, String newUid) async {
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.addParticipant(chatId, newUid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
      ref.invalidate(participantUidsProvider(chatId));
    } catch (e, s) { ... }
  }

  Future<void> removeParticipant(String chatId, String uid) async {
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.removeParticipant(chatId, uid);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) { ... }
  }

  Future<void> updateGroupName(String chatId, String name) async {
    state = const ChatActionState(status: ChatActionStatus.loading);
    try {
      await _chatRepo.updateGroupName(chatId, name);
      state = const ChatActionState(status: ChatActionStatus.success);
      ref.invalidate(chatsProvider);
    } catch (e, s) { ... }
  }

  Future<void> updatePermissionOverride(
    String chatId, String uid, GroupPermission p, bool value,
  ) async { ... }
}
```

---

## 19. FCM Changes

### ⚠️ ΠΡΟΑΠΑΙΤΟΥΜΕΝΟ: Full grep audit πριν το rename

Πριν αλλάξουμε το `fcm_service.dart`, **υποχρεωτικό audit** για κάθε αναφορά `activeChatId` (singular) σε ΟΛΟ το codebase:

```bash
# grep -r "activeChatId" lib/ --include="*.dart"
# ΑΝΑΜΕΝΟΜΕΝΑ σημεία (μη εξαντλητικά):
#   lib/core/notifications/fcm_service.dart          → definition + usage
#   lib/features/chat/screens/chat_screen.dart       → initState/dispose
#   lib/features/chat/screens/chat_list_screen.dart  → πιθανό suppression check
#   lib/providers/notification_provider.dart          → πιθανό reference
#   lib/core/router/app_router.dart                  → πιθανό deep link handling
```

Κάθε εύρεση πρέπει να ενημερωθεί:
- `FcmService.activeChatId = chatId` → `FcmService.activeChatIds.add(chatId)`
- `FcmService.activeChatId == chatId` → `FcmService.activeChatIds.contains(chatId)`
- `FcmService.activeChatId = null` → `FcmService.activeChatIds.remove(chatId)`

> **Blocking:** Αν παραλειφθεί έστω και ένα σημείο, το group chat suppression θα σπάσει. Το §25 το αναφέρει ήδη ως P2 breaking change.

### 19.1 FcmService Field

```dart
// ΠΡΙΝ:
static String? activeChatId;

// ΜΕΤΑ:
static final Set<String> activeChatIds = {};
```

### 19.2 ChatScreen init/dispose

```dart
@override
void initState() {
  super.initState();
  FcmService.activeChatIds.add(widget.chatId);
}

@override
void dispose() {
  FcmService.activeChatIds.remove(widget.chatId);
  super.dispose();
}
```

### 19.3 Should Suppress Foreground

```dart
static bool shouldSuppressForeground(RemoteMessage msg) {
  final type = msg.data['type'] as String?;
  if (type != 'chat_message') return false;

  final chatId = msg.data['chatId'] as String?;
  if (chatId == null || chatId.isEmpty) return false;

  return activeChatIds.contains(chatId);  // single check vs set
}
```

### 19.4 Cloud Functions — Group FCM με sendEachForMulticast

Η Cloud Function που στέλνει FCM notifications για chat_messages πρέπει να επεκταθεί:

1. Διαβάζει `participants` array (όχι μόνο `otherUid`)
2. Φιλτράρει: sender excluded, inactive participants excluded
3. Fetch tokens από `fcm_tokens` subcollection για κάθε recipient (έως 100 χρήστες × πολλαπλά devices)
4. **Χρησιμοποιεί `admin.messaging().sendEachForMulticast()`** (batch έως 500 tokens ανά κλήση) αντί για loop με ξεχωριστό `send()` per recipient

```typescript
// fcm-utils.ts — νέα multicast helper
async function sendGroupNotification(
  chatId: string,
  participantUids: string[],
  senderUid: string,
  payload: MessagingPayload,
) {
  // Fetch tokens για όλους τους recipients (parallel)
  const tokenPromises = participantUids
    .filter(uid => uid !== senderUid)
    .map(uid => getFcmTokens(uid));  // υπάρχουσα helper
  const allTokens = (await Promise.all(tokenPromises)).flat();

  // sendEachForMulticast: batch έως 500 tokens
  // (δεν χρειάζεται retry/backoff per-user — το fcm-utils.ts retry καλύπτει το batch)
  const result = await admin.messaging().sendEachForMulticast({
    tokens: allTokens,
    notification: payload.notification,
    data: payload.data,
  });

  // Handle failures (invalid tokens κλπ)
  result.responses.forEach((resp, idx) => {
    if (!resp.success) {
      handleFailedToken(allTokens[idx], resp.error);
    }
  });
}
```

5. Payload διαφορετικό για group:

```
// 1-to-1 chat:
{ "type": "chat_message", "chatId": "..." }

// group chat:
{ "type": "chat_message", "chatId": "...", "isGroupChat": true, "groupName": "..." }
```

> **Απόφαση:** Cloud Function, ΟΧΙ client-side FCM. Λόγοι: (α) ο client δεν έχει FCM send credentials, (β) το fcm-utils.ts retry/backoff infrastructure είναι ήδη έτοιμο, (γ) `sendEachForMulticast` αποφεύγει N ξεχωριστά sends για groups έως 100 άτομα.

---

## 20. UI User Flow

### 20.1 Ανακάλυψη & Δημιουργία

```
DiscoveryScreen
  └── PublicProfileViewScreen (για χρήστη Νίκος)
       ├── [💬 Αποστολή Μηνύματος] → 1-to-1 chat (αν allowDirectChat)
       └── [👥 Πρόσκληση σε Ομάδα] → Picker με υπάρχοντα groups

ChatListScreen
  └── [FAB / AppBar action: ❚ Δημιουργία Ομάδας]
       → CreateGroupScreen
          → search & select 2-10 χρήστες
          → optional group name
          → [Δημιουργία] → redirect στο group ChatScreen
```

### 20.2 Group Chat Screen

```
ChatScreen (group mode)

  AppBar:
    ┌──────────────────────────────────────┐
    │ ← 🔙  [👥👤👤+2]  Φίλοι Αθήνα  ⋮  │
    │                  4 βλέπουν 🔒        │
    └──────────────────────────────────────┘
      (tap title → GroupInfoScreen)

  PopupMenu (⋮):
    ├── 👤 Προσθήκη ατόμου     → AddParticipantScreen
    ├── ℹ️ Πληροφορίες ομάδας   → GroupInfoScreen
    ├── 🚪 Αποχώρηση από ομάδα → ConfirmDialog
    ├── 🗑 Διαγραφή μηνυμάτων  → ConfirmDialog

  Messages (με μηνύματα από Ν, system messages):
    ┌─────────────────────────────────┐
    │ 🔵 Νίκος                       │ ← sender label (only if not me)
    │   Γεια σε όλους!               │
    │   12:30  ✓✓                    │
    ├─────────────────────────────────┤
    │    Ο Νίκος προστέθηκε           │ ← system message (κέντρο, γκρι)
    │    στην ομάδα                   │
    ├─────────────────────────────────┤
    │                    🔵 Εγώ       │
    │                    Καλώς!       │
    │                    12:31 ✓✓     │
    └─────────────────────────────────┘

  InputBar:
    ┌──────────────────────────────────────┐
    │ [Γράψε στην ομάδα...    ] [📤]      │
    └──────────────────────────────────────┘
```

### 20.3 CreateGroupScreen

```
┌──────────────────────────────────────┐
│ ← Δημιουργία Ομάδας                  │
├──────────────────────────────────────┤
│ 📝 Όνομα ομάδας (προαιρετικό)        │
│ [___________________________]        │
│                                       │
│ 🔍 Αναζήτησε χρήστες...              │
│ [___________________________]         │
│                                       │
│ ─── Επιλεγμένα (3/10) ───            │
│ [👤 Νίκος ✕] [👤 Μαρία ✕] [👤 Γιώργος ✕]│
│                                       │
│ ─── Αποτελέσματα ───                 │
│ 🟢 Ελένη (2.3km)          [☐]        │
│ 🟡 Πέτρος (5.1km)         [☐]        │
│ 🔴 Άννα (offline)         [☐]        │
│ ...                                  │
│                                       │
│ ───────────────────────────────────── │
│ [✓ Δημιουργία Ομάδας (3 συμμετέχοντες)]│ ← enabled only if ≥ 1 selected
└──────────────────────────────────────┘
```

### 20.4 AddParticipantScreen

```
┌──────────────────────────────────────┐
│ ← Προσθήκη στην "Φίλοι Αθήνα"       │
├──────────────────────────────────────┤
│ 🔍 Αναζήτησε χρήστες...              │
│ [___________________________]         │
│                                       │
│ Δεν προτείνονται ήδη συμμετέχοντες    │
│ (Νίκος, Μαρία, Γιώργος, Ελένη)      │
│                                       │
│ ─── Αποτελέσματα ───                 │
│ 🟢 Πέτρος (online, 2.3km)  [+ Πρόσθεσε] │
│ 🔴 Αννα (offline)          [+ Πρόσθεσε] │
│                                       │
│ 4/10 μέλη                             │
└──────────────────────────────────────┘
```

### 20.5 GroupInfoScreen

```
┌──────────────────────────────────────┐
│ ← Πληροφορίες Ομάδας                 │
├──────────────────────────────────────┤
│ [👥👤👤+2]                          │
│                                       │
│ 📝 [Φίλοι Αθήνα]             ✏️     │ ← editable (αν changeGroupName)
│                                       │
│ 👥 4 από 10 συμμετέχοντες             │
│                                       │
│ ─── Συμμετέχοντες ───                │
│ ┌─────────────────────────────────┐   │
│ │  🟢 ● Εγώ              [Creator]│ → tap → PermissionsEditor (self)
│ │  🟢 ● Νίκος             [Admin] │ → tap → PermissionsEditor
│ │  🟡 ● Μαρία             [Μέλος] │ → tap → PermissionsEditor
│ │  🔴 ● Γιώργος           [Μέλος] │ → tap → PermissionsEditor
│ └─────────────────────────────────┘   │
│                                       │
│ 🔒 Κρυπτογράφηση AES-256 από άκρο σε  │
│    άκρο                               │
│ 📅 Δημιουργήθηκε: 9/7/2026            │
│                                       │
│ ───────────────────────────────────── │
│ 🚪 [Αποχώρηση από Ομάδα]             │
│ 🗑 [Διαγραφή Ομάδας]      (admin)    │
└──────────────────────────────────────┘
```

### 20.6 PermissionsEditor (tap σε συμμετέχοντα)

```
┌──────────────────────────────────────┐
│ ← Δικαιώματα: Νίκος                  │
│ Ρόλος: Μέλος                         │
├──────────────────────────────────────┤
│ Βασικά δικαιώματα:                   │
│ [✓] Πρόσκληση νέων μελών             │ ← THIS IS WHAT YOU WANT
│ [ ] Αφαίρεση μελών                   │
│ [ ] Διαγραφή μηνυμάτων               │ ← THIS STAYS OFF
│ [ ] Αλλαγή ονόματος ομάδας           │
│ [ ] Αλλαγή εικόνας ομάδας            │
│                                       │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
│ Για Διαχειριστές:                    │
│ [ ] Καρφίτσωμα μηνυμάτων             │
│                                       │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
│ Διαχείριση (μόνο Creator):           │
│ [⭐] Προαγωγή σε Admin               │
│ [⛔] Διαγραφή από ομάδα              │
│                                       │
│ [↺] Επαναφορά σε προεπιλογή ρόλου    │
└──────────────────────────────────────┘
```

### 20.7 ChatListScreen — Group Tiles

### 20.8 GroupSearchScreen (NEW)

```
ChatListScreen → 🔍 εικονίδιο → GroupSearchScreen

┌──────────────────────────────┐
│ ← Ανακάλυψη Ομάδων           │
├──────────────────────────────┤
│ 🔍 [Αναζήτησε ομάδες...]     │
│                              │
│ ─── Κοντινές Ομάδες ───      │
│ 👥 Φίλοι Αθήνα         2km  │
│    4 μέλη • Παρέα για εξόδους│
│    [Συμμετοχή]               │
│                              │
│ 👥 Gamers Club          5km  │
│    12 μέλη • Valorant, CS2   │
│    [Συμμετοχή]               │
│                              │
│ ─── Αποτελέσματα ───         │
│ ...                          │
└──────────────────────────────┘
```

### 20.9 JoinConfirmationScreen (NEW)

```
Εμφανίζεται όταν χρήστης πατάει invite link ή "Συμμετοχή":

┌──────────────────────────────┐
│  ← Πρόσκληση σε Ομάδα        │
├──────────────────────────────┤
│         [👥👤👤]              │
│                              │
│   Θέλεις να συμμετάσχεις     │
│   στην ομάδα                 │
│   "Φίλοι Αθήνα";             │
│                              │
│   👤 4 μέλη                   │
│   🔒 AES-256 Encrypted       │
│                              │
│   [✓ Αποδοχή Πρόσκλησης]    │
│   [✕ Ακύρωση]               │
└──────────────────────────────┘
```

### 20.10 GroupAuditLogScreen (NEW)

```
GroupInfoScreen → [📋 Ιστορικό] → GroupAuditLogScreen

┌──────────────────────────────┐
│ ← Ιστορικό Αλλαγών          │
├──────────────────────────────┤
│ 🕐 9/7 12:30                 │
│ Νίκος: Άλλαξε όνομα ομάδας  │
│ "Παρέα" → "Φίλοι Αθήνα"    │
│                              │
│ 🕐 9/7 12:15                 │
│ Μαρία: Προστέθηκε στην ομάδα│
│ από Νίκος                    │
│                              │
│ 🕐 9/7 12:00                 │
│ Νίκος: Δημιούργησε την ομάδα│
│                              │
│ [📥 Παλαιότερες καταχωρήσεις] │
└──────────────────────────────┘
```

```
👥 Φίλοι Αθήνα (4)              🟢 2 online
   Νίκος: Γεια σε όλους!          12:30
                           [3 🔵 unread]

💬 Νίκος                       🟢 online
   Εσύ: Τα λέμε!                11:00
```

---

## 21. Νέες Οθόνες

| # | Οθόνη | Path | Περιγραφή |
|---|---|---|---|---|
| 1 | `CreateGroupScreen` | `/chat/create-group` | Δημιουργία νέας ομάδας |
| 2 | `GroupInfoScreen` | `/chat/:chatId/info` | Πληροφορίες ομάδας + λίστα συμμετεχόντων + permissions |
| 3 | `AddParticipantScreen` | `/chat/:chatId/add` | Αναζήτηση και προσθήκη νέων μελών |
| 4 | `PermissionsEditorScreen` | dialog | Επεξεργασία δικαιωμάτων + promote/demote (Section 15) |
| 5 | `GroupSearchScreen` | `/group-search` | Ανακάλυψη δημόσιων groups (Section 11) |
| 6 | `JoinConfirmationScreen` | `/join?token=` | Αποδοχή invite link (Section 10) |
| 7 | `GroupAuditLogScreen` | `/chat/:chatId/audit-log` | Ιστορικό αλλαγών (Section 14) |
| 8 | `MaxParticipantsEditor` | dialog | Αλλαγή ορίου συμμετεχόντων (Section 17) |

---

## 22. Τροποποιήσεις Υπαρχουσών Οθονών

### 22.1 ChatScreen

| Τροποποίηση | Περιγραφή |
|---|---|
| AppBar title | Αν `isGroupChat`: tap → GroupInfoScreen. Subtitle: `"N βλέπουν"` αντί `"Προσωπικά μηνύματα"` |
| AppBar subtitle icon | `👥` group icon + `🔒` lock |
| AppBar PopupMenu | 4 options: Προσθήκη, Πληροφορίες, Αποχώρηση, Clear (ανάλογα permissions) |
| _MessageBubble | Σε group: δείχνει `senderNickname` πάνω από μήνυμα (αν sender != currentUser) |
| System messages | Ειδικό styling: κεντραρισμένο, γκρι, μικρότερη γραμματοσειρά |
| _ChatInputBar | Placeholder: `"Γράψε στην ομάδα..."` / `"Type to the group..."` |

### 22.2 ChatListScreen (_ChatTile)

| Τροποποίηση | Περιγραφή |
|---|---|
| Icon | `Icons.group` (👥) αντί `Icons.person` (💬) για group chats |
| Preview text | Πάντα `"Όνομα: μήνυμα"` (ποτέ `"Εσύ:"` prefix) |
| Subtitle | `"Νίκος, Μαρία, ..."` (όχι single otherNickname) |
| Unread badge | Σωστό count (ίδια λογική) |
| Online status | Group: δείχνει `"N online"` αντί για ένα indicator |

---

## 23. Λίστα Αρχείων προς Αλλαγή/Δημιουργία

### 23.1 Αρχεία προς Επεξεργασία (15)

| # | Αρχείο | Αλλαγή |
|---|---|---|
| 1 | `lib/core/config/feature_flags.dart` | `groupChatEnabled = true` |
| 2 | `firestore.rules` | Relax participant size constraint, add participantRoles checks |
| 3 | `lib/data/local/tables/chat_cache_table.dart` | +4 columns (isGroupChat, participantCount, participantUids, groupName) |
| 4 | `lib/data/local/database.dart` | Schema v8 → v9 migration |
| 5 | `lib/repositories/chat_repository.dart` | +17 abstract methods (11 group base + 6 invite/search/avatar/audit) |
| 6 | `lib/repositories/chat_repository_impl.dart` | `with GroupChatMixin` · αφαίρεση group methods (μεταφέρθηκαν στο mixin) · line count μειώνεται |
| 7 | `lib/features/chat/providers/chat_provider.dart` | +participantUidsProvider, +groupPermissionsProvider, +inviteLinkProvider, +groupAvatarProvider, +auditLogProvider, +ChatActions methods |
| 8 | `lib/features/chat/screens/chat_screen.dart` | Group-aware AppBar, MessageBubble, PopupMenu, System messages, mentions highlight, seenBy indicator |
| 9 | `lib/features/chat/screens/chat_list_screen.dart` | _ChatTile group display, CreateGroup FAB, GroupSearch trigger |
| 10 | `lib/core/notifications/fcm_service.dart` | activeChatId → activeChatIds (Set) |
| 11 | `lib/core/router/app_router.dart` | +6 routes (create-group, info, add, /join, group-search, audit-log) |
| 12 | `lib/shared/utils/consent_action_config.dart` | +4 group actions |
| 13 | `lib/features/discovery/screens/public_profile_view_screen.dart` | +"Πρόσκληση σε Ομάδα" button |
| 14 | `firestore.indexes.json` | +4 composite indexes: collectionGroup 'groups' (isPublic+city, isPublic+tags, isPublic+createdAt DESC, isPublic+__name__) |
| 15 | `lib/data/local/database.g.dart` | Regenerate with build_runner |

### 23.2 Νέα Αρχεία (12)

| # | Αρχείο | Περιγραφή |
|---|---|---|
| 1 | `lib/repositories/group_chat_mixin.dart` | **Mixin** — όλες οι group methods (createGroupChat, addParticipant, κτλ) · ChatRepositoryImpl `with GroupChatMixin` |
| 2 | `lib/features/chat/screens/create_group_screen.dart` | Δημιουργία ομάδας (search + select) |
| 3 | `lib/features/chat/screens/group_info_screen.dart` | Πληροφορίες + συμμετέχοντες + permissions |
| 4 | `lib/features/chat/screens/add_participant_screen.dart` | Αναζήτηση + προσθήκη μέλους |
| 5 | `lib/features/chat/widgets/group_participant_tile.dart` | Widget συμμετέχοντα |
| 6 | `lib/features/chat/widgets/system_message_bubble.dart` | Widget system μηνύματος |
| 7 | `lib/services/group_invite_service.dart` | SPoT: Invite link create/redeem/revoke |
| 8 | `lib/repositories/group_search_repository.dart` | SPoT: Group discovery & public profiles |
| 9 | `lib/services/mention_service.dart` | SPoT: @Mention extraction & validation |
| 10 | `lib/services/group_avatar_service.dart` | SPoT: Group avatar upload/delete |
| 11 | `lib/services/group_audit_log_service.dart` | SPoT: Audit log entries & stream |
| 12 | `lib/features/chat/widgets/seen_by_indicator.dart` | Read receipts (group "seen by" labels) |

### 23.3 Νέα UI Screens (5)

| # | Screen | Source |
|---|---|---|
| 1 | `lib/features/chat/screens/group_search_screen.dart` | Group Discovery (Section 11) |
| 2 | `lib/features/chat/screens/join_confirmation_screen.dart` | Invite Link (Section 10) |
| 3 | `lib/features/chat/screens/group_audit_log_screen.dart` | Audit Log (Section 14) |
| 4 | `lib/features/chat/screens/max_participants_editor.dart` | Max Participants (Section 17) |
| 5 | `lib/features/chat/screens/permissions_editor_screen.dart` | Promote/Demote UI (Section 15) |

### 23.4 Σύνολο
- **Edit:** 15 αρχεία (υπάρχοντα)
- **Create:** 17 αρχεία (1 mixin + 11 services/widgets + 5 screens)
- **Εκτίμηση:** ~1900-2300 νέες γραμμές

---

## 24. Edge Cases & Προστασία

| # | Edge Case | Προστασία |
|---|---|---|
| 1 | **Μέγιστος αριθμός συμμετεχόντων** | `maxParticipants: 10` — `addParticipant()` ελέγχει πριν Firestore write. Transaction για race condition. |
| 2 | **Προσθήκη blocked χρήστη** | Block check σε `createGroupChat()` και `addParticipant()`: αν ΟΠΟΙΟΣΔΗΠΟΤΕ από τους υπάρχοντες participants έχει block τον νέο user → blocked message. |
| 3 | **Προσθήκη self** | Έλεγχος `newUid != currentUid` |
| 4 | **Προσθήκη ήδη participant** | Έλεγχος `!participants.contains(newUid)` (double-check με Firestore transaction) |
| 5 | **Creator αποχωρεί** | `_maybeTransferCreatorOnLeave()`: αν φεύγει ο creator, προάγεται ο παλαιότερος admin (ή member αν δεν υπάρχει admin) |
| 6 | **Admin αποχωρεί** | Αν είναι ο τελευταίος admin, auto-promote του παλαιότερου member |
| 7 | **Μόνο 2 participants** | Παραμένει group chat (δεν γυρνάει σε 1-to-1 mode) |
| 8 | **Delete chat από έναν participant** | Διαγράφει μόνο local cache + τοπικό key. Firestore doc παραμένει για τους υπόλοιπους. |
| 9 | **Clear messages σε group** | `clearMessages()` απαιτεί `deleteMessages` permission |
| 10 | **Concurrent add (race)** | Firestore transaction: read participants → validate → write |
| 11 | **Προσθήκη offline user** | Το Firestore update γίνεται κανονικά. Όταν ο χρήστης έρθει online, το streamChats() listener θα συγχρονίσει το cache. |
| 12 | **Encryption με νέο participant** | deriveKey(chatId) → δίνει ίδιο key → old messages readable (intentional design decision) |
| 13 | **FCM σε group** | Notify all active participants εκτός sender. Cloud Function loop. |
| 14 | **Screenshot protection σε group** | Ίδια με 1-to-1 — FLAG_SECURE (Android) — ήδη λειτουργεί. |
| 15 | **Biometric lock + FCM tap** | `FcmService.activeChatIds` Set επιτρέπει suppression αν ο χρήστης είναι σε group. |
| 16 | **Unverified user invited** | Guard: `canUserCommunicate()` check στο `addParticipant()` — απορρίπτεται. |
| 17 | **Group name XSS/injection** | Firestore string → Flutter `Text` widget → καμία HTML render → ασφαλές. |
| 18 | **Empty group (όλοι έφυγαν)** | Auto-delete μετά από 30 ημέρες via Cloud Function (μελλοντικά). Προς το παρόν: `isActive=false` + system message. |
| 19 | **Riverpod dispose/create cascade** | Ίδιο pattern με τρέχον 1-to-1 — auth listener ήδη invalidates `chatsProvider`. |
| 20 | **Permission override race** | Firestore transaction: read → modify → write. |
| 21 | **System message encryption** | Τα system messages (join/leave/rename) είναι plaintext (type: 'system', όχι encrypted). Κανένα privacy issue (public metadata). |
| 22 | **Μη έγκυρος creator** | Αν creator UID δεν είναι πια verified ή έχει διαγραφεί → auto-promote επόμενου admin. |
| 23 | **Πολλαπλά groups με ίδιο όνομα** | Επιτρέπεται — τα groups αναγνωρίζονται από chatId, όχι όνομα. |
| 24 | **Search για AddParticipantScreen** | Χρησιμοποιεί το ίδιο `SearchRepository.search()` με πρόσθετο φίλτρο `NOT IN (existing participants)`. |

---

## 25. Side Effects Analysis

| Επηρεαζόμενο Σύστημα | Επίπτωση | Severity | Αντιμετώπιση |
|---|---|---|---|
| **ChatListScreen** | Group chats στη λίστα με group icon | P3 | _ChatTile update |
| **Δημιουργία 1-to-1 chat** | Αμετάβλητη | - | Παραμένει ίδια |
| **Διαγραφή chat** | Αν group: αφαιρεί μόνο local cache για τον αποχωρήσαντα | P2 | Same as 1-to-1 |
| **MarkAsRead** | Group: unread count query σωστό (Firestore count) | P2 | Ίδιος κώδικας |
| **sendMessage** | Αν group: encrypted + system message για join/leave | P3 | New type handling |
| **messagesStream** | Αν group: decryption unchanged, system messages plaintext | P2 | type check |
| **streamChats** | _syncChatFromFirestore: χειρίζεται group fields | P2 | Conditional group handling |
| **ProfileScreen (isPublished)** | Αμετάβλητο | - | - |
| **SearchProvider** | Αμετάβλητο (addParticipant χρησιμοποιεί SearchRepository) | - | - |
| **RequestsDashboard** | Αμετάβλητο | - | - |
| **PresenceService** | Online indicator σε group participant list | P4 ευκαιρία | Reuse υπάρχον statusProvider |
| **BlockRepository** | Block check στο addParticipant | P3 | Πρόσθετος έλεγχος |
| **ConsentLog** | Νέες actions (group_created, added_to_group, left_group) | P4 | New consent entries |
| **Router redirect** | `/chat/:chatId` redirect unchanged | - | Λειτουργεί |
| **unreadBadgeProvider** | Group unread counting σωστό | P3 | Ίδιος κώδικας |
| **FcmService.activeChatId** | `String?` → `Set<String>` | P2 | Breaking change — προσοχή σε imports |
| **Tests (30 unit)** | 30 tests unaffected (new feature) | - | - |
| **File size: chat_repository_impl.dart** | >500 lines → group methods extracted to mixin | P2 | `group_chat_mixin.dart` (~350 lines) · `chat_repository_impl.dart` πέφτει ~150 γραμμές |
| **File size: chat_screen.dart** | Θα αυξηθεί (~300→450) | P2 | Widget extraction |
| **Cloud Functions (5)** | +1 νέα CF (sendEachForMulticast) για groups έως 100 άτομα | P3 | Επέκταση υπάρχουσας sendFcmNewMessage (βλ. §19.4) |

---

## 26. Σειρά Εκτέλεσης

### Φάση A — Foundation (Blocks 1-3) ✅ **Ολοκληρωμένο**
1. **Feature flag** `groupChatEnabled = true` + σχετική προστασία (ότι είναι υπό ανάπτυξη) ✅
2. **Drift migration** v8→v9 (`ChatCacheTable` νέα πεδία) + `dart run build_runner build --delete-conflicting-outputs` ✅ (schema updated, migration added)
3. **ChatRepository abstract** + 11 νέες μεθόδους (συμπεριλαμβανομένων invite, avatar, audit log) (βλ. Φάση Β)
   - Firestore rules: updated with MultiChat grants (admin+/creator-only, invites, audit_log, groups) ✅
   - Firestore indexes: 4 composite για collectionGroup 'groups' ✅

### Φάση B — Repository & Data (Blocks 4-9)

### Φάση B — Repository & Data (Blocks 4-9)

> ⚡ **Πριν το Block 8:** `firebase deploy --only firestore:indexes` — 4 νέα composite indexes για collectionGroup 'groups' (βλ. §11.5). Χωρίς αυτό, το GroupSearchRepository θα αποτύχει με `FAILED_PRECONDITION`.
>
> ⚡ **Block 5 (GroupChatMixin):** line-by-line review του `_syncGroupChatToCache` (και τα 2 branches: insert/update) πριν το commit. Βλ. §9.5 — το ChatCacheTable dedup έχει ήδη σπάσει 2 φορές (Session 70, Session 153).
>
> ⚡ **Unit tests (`_syncGroupChatToCache`):** 4 cases — dedup path, unread count, insert vs update, system message skip-decrypt. Πρέπει να περνάνε πριν ενταχθεί το mixin στο `streamChats` (Block 17).
4. **GroupPermissions** model + `GroupPermission` enum + `hasPermission()` logic
5. **GroupChatMixin** — υλοποίηση group μεθόδων (createGroupChat, addParticipant, removeParticipant, κτλ) + **`_enforceParticipantLimit`** + **`markAsRead` extended** (lastReadTimestamps — 1 write/user)
6. **`_requirePermission`** σε κάθε protected method
7. **GroupInviteService** — invite link create/redeem/revoke (SPoT section 10)
8. **GroupSearchRepository** — searchGroups/create/update/delete public profiles (SPoT section 11)
9. **GroupAuditLogService** — log/streamLog/loadMore (SPoT section 14)

### Φάση Γ — Services (Blocks 10-13)
10. **MentionService** — extractMentions/formatForDisplay/validateParticipants (SPoT section 12)
11. **GroupAvatarService** — uploadAvatar/deleteAvatar (SPoT section 13)
12. **ChatProvider** — `participantUidsProvider`, `groupPermissionsProvider`, provider invalidations
13. **ChatActionsNotifier** — νέες public methods (createGroup, add/remove participant, invite, κτλ)

### Φάση Δ — FCM & Router (Blocks 14-15)
14. **FCM** — `activeChatId` → `activeChatIds` Set · Cloud Function επέκταση: `sendEachForMulticast` για groups έως 100 άτομα (SPoT section 19)
15. **AppRouter** — νέες routes (/chat/create-group, /chat/:chatId/info, /chat/:chatId/add, /join?token=)

### Φάση E — Core UI Screens (Blocks 16-20)
16. **ChatListScreen** — FAB, group tiles, avatar stack
17. **ChatScreen** — group mode, system messages, sender labels, PopupMenu, mentions highlight
18. **CreateGroupScreen** (νέο) — search + select + create
19. **GroupInfoScreen** (νέο) — participant list + permissions + audit log button + max participants
20. **AddParticipantScreen** (νέο) — search + add

### Φάση ΣΤ — New UI Screens (Blocks 21-25)
21. **GroupSearchScreen** (νέο) — public group discovery (section 11)
22. **JoinConfirmationScreen** (νέο) — invite link accept (section 10)
23. **GroupAuditLogScreen** (νέο) — history view (section 14)
24. **MaxParticipantsEditor** (νέο dialog) — change max limit (section 17)
25. **PermissionsEditor** — promote/demote UI (section 15)

### Φάση Z — Polish & Verification (Blocks 26-30)
26. **PublicProfileViewScreen** — +"Πρόσκληση σε Ομάδα" button
27. **ConsentLog** — νέες actions (consent_action_config.dart)
28. **Firestore rules** deploy (invites, audit_log, groups collections)
29. **`flutter analyze`**, **`flutter test`**, manual test (dual device)
30. **End-to-end group flow test** (create → invite → join → mention → read receipts → audit log)

---

## Παράρτημα: Permission Check Matrix (Complete)

| Method | Permission Required | Notes |
|---|---|---|
| `createGroupChat` | - (creator) | Creator always has full permissions |
| `addParticipant` | `inviteMembers` | Self excluded in method |
| `removeParticipant` (self) | - | Anyone can leave |
| `removeParticipant` (other) | `removeMembers` | Cannot remove creator |
| `deleteChat` | - (only creator) | Or any participant can delete local cache |
| `clearMessages` | `deleteMessages` | Per-message delete future |
| `updateGroupName` | `changeGroupName` | |
| `updateGroupAvatar` | `changeGroupAvatar` | |
| `updatePermissionOverride` | `managePermissions` | Only creator |
| `updateParticipantRole` | `manageAdmins` | Only creator, cannot demote self |
| `pinMessages` | `pinMessages` | Future phase |

---

## 27. Παράρτημα B: Firebase Cost Analysis (για μελλοντική αξιολόγηση)

### 27.1 Αρχή: Groups ΔΕΝ πολλαπλασιάζουν writes ανά μήνυμα

| Λειτουργία | 1-to-1 | Group (N=10) | Διαφορά |
|---|---|---|---|
| **sendMessage** | 2 writes (message + chat doc) | 2 writes | **Καμία** |
| **markAsRead** | N unread batch writes | 1 write (lastReadTimestamps) | **Φθηνότερο** |
| **chat list load** | 1 read | 1 read | **Καμία** |
| **message history** | 20 reads | 20 reads | **Καμία** |
| **FCM per message** | 1 CF + 1 token read | 1 CF + (N-1) token reads | **+N-2 token reads** |
| **Unread count** | 1 count query | 1 count query | **Καμία** |
| **Group search** | — | ~1 read + index (free) | **Optional** |
| **Audit log** | — | 1 write/action | **Σπάνιο** |

### 27.2 Μοναδικό νέο κόστος: FCM token reads

```
100 messages/day × group των 10 (8 extra token reads)
= 800 reads/day = ~24.000 reads/month = ~$0.014/μήνα (Blaze)
```

### 27.3 Κόστος που αποφύγαμε (readBy array → lastReadTimestamps)

```
100 messages × 9 readers × 1 write = 900 writes/day = ~$1.62/μήνα
→ saved με τη σχεδίαση του §16
```

### 27.4 Audit log TTL (future)

Αν το audit log γίνει μεγάλο (> 90 μέρες), προσθήκη Cloud Function:

```
functions.firestore.document('chats/{chatId}/audit_log/{entryId}')
  .onDelete() ή scheduled function για TTL cleanup
```

### 27.5 Συμπέρασμα

**MultiChat είναι σχεδόν cost-neutral.** Μοναδική αύξηση: token reads για FCM (~$0.01-0.05/μήνα). Τα indexes είναι δωρεάν. Το audit log TTL είναι μελλοντική βελτιστοποίηση, όχι τρέχουσα ανάγκη.
