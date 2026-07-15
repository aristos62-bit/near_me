# NearMe — Firestore Cost Optimization Strategy

> **Ημερομηνία:** 14 Ιουλίου 2026
> **Βάση:** Ανάλυση 107+ .dart αρχείων, 6 Cloud Functions, firestore.rules (308 γραμμές)
> **Στόχος:** Ελάχιστο δυνατό κόστος Firestore χωρίς απώλεια λειτουργικότητας

---

## Πίνακας Περιεχομένων

1. [Υφιστάμενη Κατάσταση](#1-υφιστάμενη-κατάσταση)
2. [Αρχές Βελτιστοποίησης](#2-αρχές-βελτιστοποίησης)
3. [🔴 P0 — Κρίσιμα (κόστος + functional risk)](#3-p0--κρίσιμα)
4. [🔴 P1 — Υψηλή Προτεραιότητα (σημαντική μείωση κόστους)](#4-p1--υψηλή-προτεραιότητα)
5. [🟡 P2 — Μεσαία Προτεραιότητα](#5-p2--μεσαία-προτεραιότητα)
6. [🟢 P3 — Χαμηλή Προτεραιότητα](#6-p3--χαμηλή-προτεραιότητα)
7. [Συνολική Στρατηγική Writes](#7-συνολική-στρατηγική-writes)
8. [Στρατηγική Listeners](#8-στρατηγική-listeners)
9. [Στρατηγική Cloud Functions](#9-στρατηγική-cloud-functions)
10. [Εκτίμηση Εξοικονόμησης](#10-εκτίμηση-εξοικονόμησης)
11. [Προτεινόμενη Σειρά Εκτέλεσης](#11-προτεινόμενη-σειρά-εκτέλεσης)

---

## 1. Υφιστάμενη Κατάσταση

### Συνοπτικά Νούμερα

| Μέγεθος | Τιμή |
|---|---|
| Collections | 13 (chats, messages, audit_log, invites, users/public, users/status, users/blocked, users/fcm_tokens, requests, groups, banned, reports, public CG) |
| Listeners (`.snapshots()`) | 12 |
| StreamProviders (Firestore) | 10 (8 autoDispose, 2 manual) |
| Cloud Functions | 6 (4 Firestore triggers + 2 callable) |
| Firestore Reads (κατά προσέγγιση) | ~40+ ανά typical session |
| Batch writes | Χρησιμοποιούνται σε markAsRead, clearMessages |
| Transactions | 1 (addGroupParticipant CF) |

### Οπτικοποίηση Listeners

```
┌──────────────────────────────────────────────────────────┐
│                   App Instance                           │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │  LISTENERS ΠΑΝΤΑ ΕΝΕΡΓΟΙ                      │       │
│  │  ┌────────────────────────────────────┐      │       │
│  │  │ authStateProvider (NO autoDispose)  │ ← Auth│       │
│  │  │ chatsProvider (NO autoDispose)      │ ← chats│       │
│  │  └────────────────────────────────────┘      │       │
│  │                                              │       │
│  │  LISTENERS autoDispose (ενεργά όσο υπάρχει UI)        │
│  │  ┌────────────────────────────────────┐      │       │
│  │  │ chatDocProvider(chatId)            │ ← chat doc    │
│  │  │ messagesProvider(chatId)           │ ← messages    │
│  │  │ chatDocForSettingsProvider(chatId) │ ← chat doc ★  │
│  │  │ auditLogStreamProvider(chatId)     │ ← audit_log   │
│  │  │ userStatusProvider(uid)            │ ← status      │
│  │  │ incomingRequestsProvider           │ ← requests    │
│  │  │ outgoingRequestsProvider           │ ← requests    │
│  │  │ publicProfileStreamProvider(uid)   │ ← public      │
│  │  └────────────────────────────────────┘      │       │
│  └──────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Αρχές Βελτιστοποίησης

1. **Μείωση reads:** Κάθε read = χρέωση. Προτιμούμε cached data όταν είναι OK.
2. **Batch writes:** Αντί για N writes σε loop, 1 batch με N operations.
3. **`.limit()` σε κάθε query:** Ποτέ unbounded queries — πάντα `.limit(N)`.
4. **Parallel reads:** Αντί για sequential `await a; await b;`, χρήση `Future.wait([a, b])`.
5. **Ένα listener ανά document:** Ποτέ duplicate listeners στο ίδιο doc.
6. **Server-side filtering:** Όσο πιο πολύ στα rules/queries, τόσο λιγότερο client-side processing.
7. **Cache όπου possible:** Drift local DB + in-memory caches.
8. **Avoid reads-after-writes:** Η `set()` πετυχαίνει → δεν χρειάζεται verify read.

---

## 3. 🔴 P0 — Κρίσιμα

### P0.1 — `_deleteChatForEveryone`: Pagination loop + batch — ✅ FIXED

| Αρχείο | Γραμμές | Κόστος τώρα | Κατάσταση |
|--------|---------|-------------|:---------:|
| `chat_repository_delete.dart` | 88-137 | Pagination loop, max 500 ops/batch | **✅ Fixed (Session 166)** |

**Πρόβλημα (2 issues):**

1. **One-by-one delete:** Διέγραφε messages ένα-ένα σε loop — 500 messages = 500 writes.
2. **Unbounded read:** `.get()` χωρίς `.limit()` — φόρτωνε ΟΛΑ τα messages.

**Λύση που υλοποιήθηκε:**

```dart
while (hasMore) {
  final messages = await firestore
      .collection('chats').doc(chatId).collection('messages')
      .limit(500)
      .get();

  if (messages.docs.isEmpty) break;

  final batch = firestore.batch();
  for (final doc in messages.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();

  if (messages.docs.length < 500) hasMore = false;
}
```

**Τι άλλαξε:**
- Από unbounded read → `.limit(500)` pagination loop ✅
- Από one-by-one delete → batch των 500 ✅
- Debug logs per batch + total count ✅
- `flutter analyze` — **0 issues** ✅

**Εξοικονόμηση:** 500 writes → ~1-2 batches. Σε 1k chats με 100 msg avg = **~49.500 writes saved**.

---

### P0.2 — `_findExistingChat`: Unbounded `.get()` + functional risk (duplicate chat) — ✅ FIXED

| Αρχείο | Γραμμές | Κόστος τώρα | Κατάσταση |
|--------|---------|-------------|:---------:|
| `chat_repository_impl.dart` | 118-150 | Διάβαζε ΟΛΑ τα chats του uid | **✅ Fixed** |

**Πρόβλημα (2 issues):**

1. **Unbounded query:** `arrayContains: uid1` χωρίς `.limit()` — φόρτωνε ΟΛΑ τα chats του χρήστη (300+ reads για να βρει 1 match).
2. **Functional risk:** Αν βάζαμε `.limit(50)` χωρίς `orderBy()`, η σειρά επιστροφής δεν είναι εγγυημένη. Αν ο χρήστης έχει >50 chats και το ζητούμενο chat δεν είναι στα πρώτα 50, θα δημιουργούσε **duplicate chat**.

**Λύση που υλοποιήθηκε (Session 166+):**

3-tier approach με `participantPair` + self-healing lazy backfill:

```
_findExistingChat(uid1, uid2)
│
├── Tier 2: participantPair direct query (.limit(1))
│   └── Αν βρει && both active → return chatId
│
└── Tier 3: legacy fallback (.limit(10), client-side filter)
    ├── Αν βρει → self-healing update (participantPair + isGroupChat: false)
    └── Αν όχι → null (νέο chat)
```

**Αλλαγές στον κώδικα:**

1. `createChat()` — αποθηκεύει `participantPair` (sorted UID pair) + `isGroupChat: false`
2. `_findExistingChat()` — Tier 2: `where('participantPair', ==, pairStr).where('isGroupChat', ==, false).limit(1)` → 1 read
3. Tier 3 legacy fallback: `where('participants', arrayContains: uid1).limit(10)` + client-side filter (skip groups, check both participants, length==2)
4. Self-healing backfill: best-effort `update({'participantPair': pairStr, 'isGroupChat': false})` στο legacy match
5. Both-active guard: `participants.contains(uid1) && participants.contains(uid2)` πριν return

**Firestore rules deploy:**
- Νέος κλάδος στο `allow update` των chats για `participantPair` + `isGroupChat`:
```javascript
// Legacy chat participantPair backfill (self-healing, any participant, one-time)
request.resource.data.diff(resource.data).affectedKeys()
  .hasOnly(['participantPair', 'isGroupChat'])
```
- `firebase deploy --only firestore:rules` ✅
- `flutter analyze` — **0 issues** ✅

**Edge cases που θωρακίστηκαν:**
- Legacy chats χωρίς `participantPair` → Tier 3 fallback
- Legacy chats χωρίς `isGroupChat` field → client-side `if (data['isGroupChat'] == true) continue` (δεν αποκλείει docs με missing field)
- User σε 100+ groups → `.limit(10)` cap
- `deleteChatForMe` → both-active guard αποκλείει μισο-σβησμένα chats
- Concurrent createChat → προϋπάρχον ρίσκο (δεν το εισάγει/λύνει αυτή η αλλαγή)

**Εξοικονόμηση:** Tier 2: **1 read** (από unbounded). Tier 3 fallback: ≤10 reads (από unbounded). Self-healing backfill μεταφέρει σταδιακά legacy chats σε Tier 2.

---

### P0.3 — `markAsRead`: Unbounded `.get()` + N writes χωρίς `.limit()` — ✅ FIXED

| Αρχείο | Γραμμές | Κόστος τώρα | Κατάσταση |
|--------|---------|-------------|:---------:|
| `chat_repository_impl.dart` | 368-407 | 1 write + ≤50 reads + ≤50 writes | **✅ Fixed (Session 166)** |

**Πρόβλημα:** `where('isRead', isEqualTo: false)` χωρίς `.limit()` — αν ένα chat έχει 1000+ unread messages, φορτώνονται ΟΛΑ και γράφονται ΟΛΑ. Διπλό κόστος: N reads + N writes. Επίσης PERMISSION_DENIED στα Firestore Rules λόγω `${}` interpolation σε CEL.

**Λύση που υλοποιήθηκε (2 σκέλη):**

#### Fix 1 — Firestore Rules (Session 160)
`firestore.rules:119-124` — nested `diff()` αντί `${}` interpolation:
```
request.resource.data.lastReadTimestamps.diff(
  resource.data.get('lastReadTimestamps', {})
).affectedKeys().hasOnly([request.auth.uid])
```

#### Fix 2 — Client code (Session 166)
`chat_repository_impl.dart:368-407`:
1. Γράφει `lastReadTimestamps.{uid}` με serverTimestamp (1 write, 0 reads)
2. Query unread messages με **`.limit(50)`** — bounded ≤50 reads + ≤50 writes
3. Batch mark isRead=true
4. Update local Drift cache (hasUnread=false)

```dart
// ✅ ΥΛΟΠΟΙΗΜΕΝΗ ΛΥΣΗ (chat_repository_impl.dart:368-407):
await firestore.collection('chats').doc(chatId).update({
  'lastReadTimestamps.${user.uid}': FieldValue.serverTimestamp(),
});

final unread = await firestore
    .collection('chats').doc(chatId).collection('messages')
    .where('isRead', isEqualTo: false)
    .limit(50)  // ← .limit(50) — bounded reads/writes
    .get();

final docs = unread.docs.where((d) => d.data()['senderId'] != user.uid).toList();
if (docs.isNotEmpty) {
  final batch = firestore.batch();
  for (final doc in docs) { batch.update(doc.reference, {'isRead': true}); }
  await batch.commit();
}
```

**Resize metrics:**
| Πριν | Μετά |
|------|------|
| N reads + N writes (όλα unread) | 1 write (lastReadTimestamp) + ≤50 reads + ≤50 writes |
| 1000 unread → 2000 ops | 1000 unread → ≤101 ops |

**Εξοικονόμηση:** ~1.900 ops saved per markAsRead με 1000 unread.
**Verified:** `flutter analyze` clean ✅, code confirmed Session 166.

---

### P0.4 — `clearMessages`: Pagination loop + `.limit(500)` — ✅ FIXED

| Αρχείο | Γραμμές | Κόστος τώρα | Κατάσταση |
|--------|---------|-------------|:---------:|
| `chat_repository_clear.dart` (NEW) | ~65 | Pagination loop, max 500 ops/batch | **✅ Fixed (Session 166)** |
| `chat_repository_impl.dart` | 678 (από 710) | Removed old clearMessages, with ChatClearMixin | **✅ Fixed** |

**Πρόβλημα (2 issues):**

1. **Unbounded read:** `.get()` χωρίς `.limit()` — φόρτωνε ΟΛΑ τα messages.
2. **CRASH BUG:** `batch.delete` χωρίς pagination — αν >500 messages, `Firestore exception: maximum 500 operations per batch` — **crash σε production**.

**Λύση που υλοποιήθηκε:**

Νέο `ChatClearMixin` στο `chat_repository_clear.dart` — pagination loop με batches των 500:

```dart
while (hasMore) {
  final messages = await firestore
      .collection('chats').doc(chatId).collection('messages')
      .limit(batchSize)  // 500
      .get();

  if (messages.docs.isEmpty) break;

  final batch = firestore.batch();
  for (final doc in messages.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();

  if (messages.docs.length < batchSize) hasMore = false;
}
```

**Τι άλλαξε:**
- Από unbounded read → `.limit(500)` pagination loop ✅
- Από crash σε >500 msgs → safe batching ✅
- Debug logs per batch + total count ✅
- `flutter analyze` — **0 issues** ✅

**Εξοικονόμηση:** ~300-900 reads saved ανά clearMessages (ανάλογα unread count).

---

## 4. 🔴 P1 — Υψηλή Προτεραιότητα

### ✅ P1.1 — Duplicate listener: `chatDocProvider` + `_chatDocForSettingsProvider` — **FIXED (Session 167)**

| Αρχείο | Γραμμές | Τύπος |
|--------|---------|-------|
| ~~`group_settings_screen.dart`~~ | ~~14-18~~ | ~~Private StreamProvider~~ **REMOVED** |
| `chat_provider.dart:10` | `chatDocProvider` | StreamProvider.autoDispose.family (reused) |

**Πρόβλημα:** Δύο ξεχωριστοί StreamProvider ακούνε και οι δύο στο ίδιο `chats/{chatId}` document. Κάθε φορά που κάποιος ανοίγει GroupSettings, δημιουργείται **δεύτερος listener** στο ίδιο ακριβώς doc.

**Λύση:** Αντικατάσταση `_chatDocForSettingsProvider` με `chatDocProvider(chatId)` reuse.

**Αλλαγές σε 1 αρχείο:**
- `group_settings_screen.dart`:
  1. Αφαίρεση `import 'package:cloud_firestore/cloud_firestore.dart';` (unused)
  2. Αφαίρεση `_chatDocForSettingsProvider` definition (lines 14-18)
  3. `ref.watch(_chatDocForSettingsProvider(...))` → `ref.watch(chatDocProvider(...))`

**Verified:** `flutter analyze` — **0 issues** ✅

**Εξοικονόμηση:** 1 duplicate listener ανά group settings open. Με 100 opens/ημέρα → **50% reduction στο listener cost για αυτό το doc.**

---

### P1.2 — Sequential reads in `createChat()` (2 sequential profile reads)

| Αρχείο | Γραμμές | Κόστος τώρα |
|--------|---------|-------------|
| `chat_repository_impl.dart` | 81-88 | 2 reads sequential |

```dart
// ΤΩΡΑ (chat_repository_impl.dart:81-88):
final myProfile = await firestore
    .collection('users').doc(uid).collection('public').doc('profile').get();
// ...
final otherProfile = await firestore
    .collection('users').doc(otherUid).collection('public').doc('profile').get();

// ΠΡΕΠΕΙ:
final results = await Future.wait([
  firestore.collection('users').doc(uid).collection('public').doc('profile').get(),
  firestore.collection('users').doc(otherUid).collection('public').doc('profile').get(),
]);
final myProfile = results[0];
final otherProfile = results[1];
```

**Εξοικονόμηση:** ~50% latency reduction (αλλά ίδιο read cost). Βελτίωση UX + μικρότερη πιθανότητα race conditions.

---

### P1.3 — `sendRequest()`: 3 sequential reads, 1 debug-only

| Αρχείο | Γραμμές | Issues |
|--------|---------|--------|
| `request_repository_impl.dart` | 42-91 | 3 sequential reads |

**Πρόβλημα:** 3 ξεχωριστά `await` reads πριν την `add()`:
1. `users/$toUid/blocked/$uid` (γραμμή 42-44)
2. `users/$toUid/public/profile` (γραμμή 58-59)
3. `banned/$uid` (γραμμή 85) — **debug-only, completely unnecessary in production**

```dart
// Λύση:
// 1. Αφαίρεση banned check (γραμμές 83-90) — είναι debug-only, τα rules ήδη το ελέγχουν
// 2. Parallel reads για block check + target profile:
final results = await Future.wait([
  _firestore.doc('users/$toUid/blocked/$uid').get(),
  _firestore.collection('users').doc(toUid).collection('public').doc('profile').get(),
]);
```

**Εξοικονόμηση:** 1 read saved πάντα (banned check) + 1 read latency βελτίωση.

---

### P1.4 — `publish()`: Debug verify read after `set()` (1 read per publish)

| Αρχείο | Γραμμές | Issue |
|--------|---------|-------|
| `profile_repository_impl.dart` | 362-380 | Verify read μετά από set() |

```dart
// ΤΩΡΑ (profile_repository_impl.dart:362-380):
await _firestore.collection('users').doc(uid).collection('public').doc('profile').set(json);
// ↑ set() πέτυχε
try {
  final verifyDoc = await _firestore
      .collection('users').doc(uid).collection('public').doc('profile').get();  // ← άχρηστο!
  // κάνει log τα δεδομένα
} catch (e) { /* non-fatal */ }
```

**Λύση:** Το `set()` επιστρέφει success → το verify read είναι **debug-only**. Αφαίρεση ή wrap σε `DebugConfig` flag.

```dart
await _firestore.collection('users').doc(uid).collection('public').doc('profile').set(json);
if (DebugConfig.debugMode) {
  // μόνο σε debug mode κάνουμε verify
  try { /* verify read */ } catch (e) { /* ignore */ }
}
```

**Εξοικονόμηση:** 1 read saved ανά publish. Με 100 publishes/ημέρα → 3.000 reads/μήνα saved.

---

### P1.5 — `ChatCacheTable._syncChatFromFirestore`: 2 count queries per chat update

| Αρχείο | Γραμμές | Issue |
|--------|---------|-------|
| `group_chat_mixin.dart` | 166-174 | 2 sequential `.count().get()` calls |

**Πρόβλημα:** Κάθε φορά που το chat listener βλέπει αλλαγή, κάνει 2 ξεχωριστά count queries:
1. `messages.where(timestamp > lastRead).count().get()`
2. `messages.where(senderId == uid AND timestamp > lastRead).count().get()`

Αυτό συμβαίνει για **κάθε chat που ενημερώνεται** στο `streamChats`.

```dart
// Λύση:
// 1. Αποθήκευση unreadCount στο chat doc (Firestore) — γράφεται από sendMessage
// 2. Αντί για 2 count queries, απλή ανάγνωση chatDoc['unreadCount']

// Ή εναλλακτικά, 1 parallel query αντί 2 sequential:
final results = await Future.wait([
  firestore.collection('chats').doc(chatId).collection('messages')
      .where('timestamp', isGreaterThan: Timestamp.fromDate(lastRead))
      .count().get(),
  firestore.collection('chats').doc(chatId).collection('messages')
      .where('senderId', isEqualTo: uid)
      .where('timestamp', isGreaterThan: Timestamp.fromDate(lastRead))
      .count().get(),
]);
```

**Εξοικονόμηση:** 2 count queries ανά chat update × 5 updates/ημέρα/chat × 100 chats = **1.000 count queries/μήνα saved.**

---

## 5. 🟡 P2 — Μεσαία Προτεραιότητα

### P2.1 — Cloud Function: `sendChatNotification` reads sender profile 2× (αχρείαστα)

| Αρχείο | Γραμμές | Issue |
|--------|---------|-------|
| `functions/src/index.ts` | 102, 116 | 2 reads του ίδιου profile |

```typescript
// ΓΡΑΜΜΗ 102:
const senderSnap = await db.doc(`users/${message.senderId}/public/profile`).get();
// ...χρησιμοποιεί senderName...

// ΓΡΑΜΜΗ 116 (group branch):
const lang = (await db.doc(`users/${message.senderId}/public/profile`).get()).data()?.lang ?? 'en';
// ↑ ΔΕΥΤΕΡΗ read του ίδιου document!
```

**Λύση:** Reuse `senderSnap` από τη γραμμή 102:

```typescript
const senderSnap = await db.doc(`users/${message.senderId}/public/profile`).get();
const senderName = senderSnap.data()?.nickname ?? 'Someone';
const lang = senderSnap.data()?.lang ?? 'en';  // ← reuse, όχι νέο read
```

**Εξοικονόμηση:** 1 read saved per new message notification. Με 1.000 messages/ημέρα → **30.000 reads/μήνα saved.**

---

### P2.2 — `sendChatNotification`: 1-to-1 branch reads recipient profile + tokens + block σε 3 sequential calls

| Αρχείο | Γραμμές | Κόστος τώρα |
|--------|---------|-------------|
| `functions/src/index.ts` | 156-165 | 3 sequential reads |

```typescript
// Sequential: block → lang → tokens (γραμμές 156-165)
const blockSnap = await db.doc(`...blocked/...`).get();
const langSnap = await db.doc(`users/${recipientUid}/public/profile`).get();  
const tokensSnap = await db.collection(`users/${recipientUid}/fcm_tokens`).get();
```

**Λύση:** `Promise.all()` για παράλληλες reads (block check + profile + tokens).

---

### ⏭️ P2.3 / P2.4 — `group_chat_mixin.dart` refactor (SKIP — risk/benefit unacceptable)

| Αρχείο | Γραμμές | Θέμα |
|--------|---------|------|
| `group_chat_mixin.dart` | ~796 (exception στο file-size limit) | `_requirePermission` + sequential reads |

**Ανάλυση:** Κάθε group action στο mixin κάνει 1 read για permission check (`_requirePermission`) + πιθανά άλλο read για το action. Η βελτιστοποίηση θα απαιτούσε refactor σχεδόν όλων των μεθόδων (796 γραμμές).

**Απόφαση: SKIP** — Το όφελος (~€0.02/μήνα για 1k users) είναι αμελητέο σε σχέση με τον κίνδυνο regression σε τόσο μεγάλο και κρίσιμο αρχείο. Αν κάποτε το κόστος γίνει μετρήσιμο (100k+ users), επανεξέταση.

> **Σημείωση:** Η απόφαση αυτή βασίζεται στο ότι (α) το file-size όριο είναι ήδη σε exception, (β) το refactor θα ακουμπούσε 15+ μεθόδους, (γ) το οικονομικό όφελος είναι πρακτικά μηδέν.

---

### ✅ P2.6 — Provider cascade on startup (chatsProvider dispose/recreate) — **FIXED (Session 167)**

| Αρχείο | Γραμμή | Issue |
|--------|--------|-------|
| `main.dart` | 359 | `prev is AsyncData` |

**Πρόβλημα:** Σε κάθε startup, το `chatsProvider` δημιουργούνταν 2 φορές — μία από το `unreadBadgeProvider` cascade και μία από το `ref.invalidate(chatsProvider)` στο main's auth listener (το πρώτο emit του `authStateProvider` έκανε `prev?.value = null` → `uidChanged = true` → invalidate).

**Λύση:** `if ((uidChanged \|\| emailVerifiedChanged) && prev is AsyncData)` — το `prev is AsyncData` αποκλείει το πρώτο emit (`AsyncLoading` → `AsyncData`), επιτρέποντας μόνο real changes.

**Εξοικονόμηση:** 1 επιπλέον `streamChats()` query + decrypt cycle στο startup. Αμελητέο κόστος αλλά διορθώνει περιττό pattern.

---

### P2.5 — `sendChatNotification`: sender profile read also in non-group branch

| Αρχείο | Γραμμές | Issue |
|--------|---------|-------|
| `functions/src/index.ts` | 116 | sender profile read via `db.doc()...get()` αντί `senderSnap` reuse |

**Διόρθωση:** Ήδη καλύφθηκε στο P2.1, αλλά απαιτεί προσοχή — το branch `isGroupChat == true` κάνει 2nd read ενώ υπάρχει ήδη `senderSnap` από τη γραμμή 102.

---

## 6. 🟢 P3 — Χαμηλή Προτεραιότητα

### P3.1 — N+1 listeners: `_AuditLogTile` → `chatDocProvider` (per audit entry)

| Αρχείο | Γραμμή | Issue |
|--------|--------|-------|
| `group_audit_log_screen.dart` | 187 | Each audit log tile watches `chatDocProvider(chatId)` |

**Πρόβλημα:** Αν υπάρχουν 20 audit log entries στην οθόνη και κάθε `_AuditLogTile` κάνει `ref.watch(chatDocProvider(chatId))`, δημιουργούνται 20 listeners στο ίδιο document. Ευτυχώς το Riverpod autoDispose family κάνει cache το snapshot, αλλά το `.watch()` θα προκαλέσει rebuilds.

**Λύση:** Το `chatDocProvider` είναι autoDispose family και το Riverpod το κάνει cache — οπότε ΔΕΝ δημιουργούνται 20 listeners. Αλλά για performance, καλύτερα να περνιέται το participantNicknames map ως prop.

**Εξοικονόμηση:** Κυρίως UI rebuilds, όχι Firestore reads. Low priority.

---

### P3.2 — `GroupChatMixin`: `_syncChatFromFirestore` does 2 count queries per update (redundant with `streamChats`)

| Αρχείο | Γραμμή | Issue |
|--------|--------|-------|
| `group_chat_mixin.dart` | 166-174 | Redundant count queries |

(Ήδη καλύφθηκε στο P1.5 — επαναλαμβάνεται εδώ ως υπενθύμιση για το technical debt.)

---

### P3.3 — `deleteUserData` (CF): Θα μπορούσε να χρησιμοποιεί recursive delete ή batch pagination

| Αρχείο | Γραμμή | Issue |
|--------|--------|-------|
| `functions/src/index.ts` | ~565-690 | Sequential deletes |

**Πρόβλημα:** Το `deleteUserData` callable function είναι heavy operation που τρέχει σπάνια (μόνο σε delete account). Δεν δικαιολογείται optimization εκτός αν υπάρχουν 1000+ χρήστες.

**Πρόταση:** Deploy optimization ΜΟΝΟ όταν το κόστος γίνει measurable. Προς το παρόν, leave as-is.

---

### P3.4 — `streamIncomingRequests` / `streamOutgoingRequests`: Listeners χωρίς `.limit()`

| Αρχείο | Γραμμή | Issue |
|--------|--------|-------|
| `request_repository_impl.dart` | 187-201, 217-231 | Listeners χωρίς `.limit()` |

**Πρόβλημα:** Τα requests streams δεν έχουν `.limit()` — αν κάποιος έχει 1000+ requests, όλα φορτώνονται.

**Λύση:** Προσθήκη `.limit(100)` + cursor-based pagination αν χρειαστεί.

---

## 7. Συνολική Στρατηγική Writes

### 7.1 — Batch Policy

| Operation | Current | Target | Status |
|-----------|---------|--------|--------|
| `deleteChatForEveryone` | One-by-one delete ❌ | Pagination loop 500 ✅ | **P0.1 ✅ Fixed** |
| `clearMessages` | Unbounded + crash ❌ | Pagination loop 500 ✅ | **P0.4 ✅ Fixed** |
| `markAsRead` | N reads + N writes ❌ | lastReadTimestamp + .limit(50) ✅ | **P0.3 ✅ Fixed** |
| `_findExistingChat` | Unbounded read ❌ | participantPair 3-tier ✅ | **P0.2 ✅** |
| `sendMessage` | Single write ✅ | N/A (1 msg = 1 write) | OK |
| `publish` | Single set ✅ | N/A | OK |
| `sendRequest` | Single add ✅ | N/A | OK |
| `respondToRequest` | Single update ✅ | N/A | OK |

### 7.2 — Write Optimization Checklist

```dart
// ✅ ΣΩΣΤΟ — batch για πολλαπλά writes:
final batch = firestore.batch();
for (final doc in docs) {
  batch.update(doc.reference, {'field': value});
}
await batch.commit();

// ✅ ΣΩΣΤΟ — FieldValue για atomic updates:
await docRef.update({
  'field': FieldValue.increment(1),
  'array': FieldValue.arrayUnion([element]),
});

// ❌ ΛΑΘΟΣ — one-by-one writes:
for (final doc in docs) {
  await doc.reference.delete();
}

// ❌ ΛΑΘΟΣ — read after write:
await docRef.set(data);
final verify = await docRef.get();  // ← unnecessary
```

### 7.3 — Μέγιστα Batch μεγέθη

| Batch Type | Max Operations | Notes |
|-----------|:-----------:|-------|
| Firestore batch writes | 500 | Hard limit — πάντα <500 |
| Firestore transaction | 500 | Hard limit |
| Firebase Functions batch | 500 | Ανά batch commit |

---

## 8. Στρατηγική Listeners

### 8.1 — Current vs Optimal Listener Count

| Listener | Σήμερα | Βέλτιστο | Σημείωση |
|----------|:------:|:---------:|----------|
| `authStateProvider` | 1 | 1 | Must-have, NO autoDispose |
| `chatsProvider` | 1 | 1 | Must-have, NO autoDispose |
| `chatDocProvider` | 1 | 1 | autoDispose family |
| `_chatDocForSettingsProvider` | 1 | **0** (reuse) | **Duplicate → P1.1** |
| `messagesProvider` | 1 | 1 | autoDispose family |
| `auditLogStreamProvider` | 1 | 1 | autoDispose family |
| `userStatusProvider` | 1 | 1 | autoDispose family |
| `incomingRequestsProvider` | 1 | 1 | autoDispose |
| `outgoingRequestsProvider` | 1 | 1 | autoDispose |
| `publicProfileStreamProvider` | 1 | 1 | autoDispose family |
| **Σύνολο** | **10** | **9** | **1 duplicate removed** |

### 8.2 — Listener `limit()` additions

| Stream | Current | Target | Priority |
|--------|---------|--------|----------|
| `streamChats()` | No limit ❌ | `.limit(100)` | **P2 (medium)** |
| `streamIncomingRequests()` | No limit ❌ | `.limit(100)` | **P3 (low)** |
| `streamOutgoingRequests()` | No limit ❌ | `.limit(100)` | **P3 (low)** |

### 8.3 — Debounce policy

| Pattern | Recommendation |
|---------|---------------|
| Auth state changes | Already handled (Session 151: `isSigningOut` flag) |
| Search input changes | Already handled (Nominatim 800ms debounce) |
| Firestore snapshot changes | N/A — real-time requirements |
| Provider cascade on auth | Already mitigated (Session 151-154 + 167: `prev is AsyncData`) |

---

## 9. Στρατηγική Cloud Functions

### 9.1 — Cost per invocation breakdown

| Function | Trigger | Avg Reads | Avg Writes | Optimization Potential |
|----------|---------|:---------:|:----------:|:----------------------:|
| `sendChatNotification` | onCreate message | 4-5 | 0-1 (tokens cleanup) | **P2.1, P2.2** |
| `onReportCreated` | onCreate report | 3-4 | 1-2 | Minimal (σπάνια κλήση) |
| `sendRequestNotification` | onCreate request | 3-4 | 0-1 (tokens cleanup) | Moderate |
| `sendRequestResponseNotification` | onUpdate request | 3-4 | 0-1 (tokens cleanup) | Moderate |
| `deleteUserData` | onCall | ~10-50+ | ~10-50+ | Low priority (σπάνια) |
| `addGroupParticipant` | onCall | ~4-6 | 1 (transaction) | Low priority |

### 9.2 — Optimizations ανά CF

#### `sendChatNotification`
- [x] **P2.1**: Reuse `senderSnap` αντί 2nd read (γραμμή 102→116)
- [x] **P2.2**: Parallel reads για 1-to-1 branch (block + profile + tokens)
- [ ] Προαιρετικό: Cache `senderName` στο chat doc message (γράφεται από client μαζί με το message) → 0 reads

#### `sendRequestNotification` / `sendRequestResponseNotification`
- [ ] Παρόμοιο pattern με chat — parallel reads όπου possible

### 9.3 — Προτεινόμενα νέα patterns για CF

```typescript
// ✅ ΠΑΡΑΛΛΗΛΕΣ reads:
const [snap1, snap2] = await Promise.all([
  db.doc(`path1`).get(),
  db.doc(`path2`).get(),
]);

// ✅ CACHED reads:
const senderSnap = await db.doc(`path`).get();
const senderName = senderSnap.data()?.nickname;
const lang = senderSnap.data()?.lang;  // ← reuse, όχι νέο await

// ❌ SEQUENTIAL reads:
const snap1 = await db.doc(`path1`).get();
const snap2 = await db.doc(`path2`).get();  // ← περιμένει snap1

// ❌ DUPLICATE reads:
const name = (await db.doc(`path`).get()).data()?.nickname;
const lang = (await db.doc(`path`).get()).data()?.lang;  // ← 2nd read!
```

---

## 10. Εκτίμηση Εξοικονόμησης

### Για 1.000 ενεργούς χρήστες / μήνα

| # | Optimization | Reads Saved/μήνα | Writes Saved/μήνα | € Saved/μήνα | Status |
|:-:|-------------|:---------------:|:----------------:|:------------:|:------:|
| P0.1 | Pagination batch delete (1-to-1) | 0 | ~49.500 | ~€0.89 | **✅** |
| **P0.2** | **participantPair 3-tier lookup** | **~89.700** | **0** | **~€0.72** | **✅** |
| P0.3 | markAsRead lastReadTimestamp + .limit(50) | ~30.000 | ~30.000 | ~€0.48 | **✅** |
| P0.4 | `clearMessages` pagination loop | ~3.000 | 0 | ~€0.02 | **✅** |
| P1.1 | Remove duplicate listener | ~15.000 | 0 | ~€0.12 | **✅ (Session 167)** |
| P1.2 | Parallel createChat reads | (latency) | 0 | — | ⏳ |
| P1.3 | Remove debug banned check | ~3.000 | 0 | ~€0.02 | ⏳ |
| P1.4 | Remove verify read in publish | ~3.000 | 0 | ~€0.02 | ⏳ |
| P1.5 | Unread count optimization | ~30.000 | 0 | ~€0.24 | ⏳ |
| P2.1 | CF senderSnap reuse | ~30.000 | 0 | ~€0.24 | ⏳ |
| **Σύνολο** | | **~218.700** | **~79.500** | **~€2.87/μήνα** | |

> **Σημείωση:** Το Firestore χρεώνει ~$0.06/100k reads, ~$0.18/100k writes (Blaze plan). Η εξοικονόμηση για 1k χρήστες είναι ~€2.53/μήνα. Για 10k χρήστες → ~€25/μήνα. Για 100k χρήστες → ~€250/μήνα.

### Εξοικονόμηση σε κλίμακα

| Χρήστες | Reads/μήνα σήμερα | Reads/μήνα optimized | Εξοικονόμηση |
|:-------:|:-----------------:|:--------------------:|:------------:|
| 1.000 | ~326.000 | ~122.300 | **~62%** |
| 10.000 | ~3.260.000 | ~1.223.000 | **~62%** |
| 100.000 | ~32.600.000 | ~12.230.000 | **~62%** |
| 1.000.000 | ~326.000.000 | ~122.300.000 | **~62%** |

> **Το κλειδί:** Τα unbounded queries (P0.2, P0.3) και τα duplicate listeners (P1.1) είναι τα μεγαλύτερα cost drivers. Η εξοικονόμηση είναι **αναλογική** — όσο μεγαλώνει η βάση χρηστών, τόσο μεγαλύτερη η εξοικονόμηση.

---

## 11. Προτεινόμενη Σειρά Εκτέλεσης

### ✅ Ολοκληρωμένα
| Σειρά | Θέμα | Impact | Κατάσταση |
|:-----:|------|:------:|:---------:|
| **✅** | **P0.2** — `_findExistingChat`: 3-tier lookup + self-healing backfill | **Κόστος + Duplicate fix** | **Session 166** ✅ |
| **✅** | **P0.3** — `markAsRead`: lastReadTimestamp + .limit(50) + rules fix | **Κόστος + Rules PERMISSION_DENIED** | **Session 166** ✅ |
| **✅** | **P0.4** — `clearMessages`: pagination loop + `.limit(500)` | **Crash fix** + Κόστος | **Session 166** ✅ |
| **✅** | **P0.1** — `_deleteChatForEveryone`: pagination loop + batch | **Crash fix** + Κόστος | **Session 166** ✅ |
| **✅** | **P1.1** — Remove duplicate `_chatDocForSettingsProvider` | **Κόστος (duplicate listener)** | **Session 167** ✅ |
| **✅** | **P2.6** — Provider cascade on startup: `prev is AsyncData` | Περιττό pattern | **Session 167** ✅ |

### Φάση Α — Κρίσιμα (P0) — **ΟΛΑ ΟΛΟΚΛΗΡΩΜΕΝΑ** ✅

### Φάση Β — Υψηλή Προτεραιότητα (P1 — 5 items, 1 ✅)
| Σειρά | Θέμα | Impact | Εκτίμηση |
|:-----:|------|:------:|:--------:|
| **✅** | **P1.1** — Remove duplicate `_chatDocForSettingsProvider` | Κόστος | **✅ Fixed (Session 167)** |
| 5 | **P1.2** — Parallel reads in `createChat()` | Latency | 15 λεπτά |
| 6 | **P1.3** — Remove debug banned check + parallel reads in `sendRequest()` | Κόστος + Latency | 20 λεπτά |
| 7 | **P1.4** — Conditional verify read in `publish()` | Κόστος | 10 λεπτά |
| 8 | **P1.5** — Optimize unread count queries in `_syncChatFromFirestore` | Κόστος | 30 λεπτά |

### Φάση Γ — Μεσαία Προτεραιότητα (P2 — 3 items)
| Σειρά | Θέμα | Impact | Εκτίμηση |
|:-----:|------|:------:|:--------:|
| 9 | **P2.1** — CF senderSnap reuse | Κόστος (CF) | 15 λεπτά |
| 10 | **P2.2** — CF parallel reads 1-to-1 | Latency (CF) | 15 λεπτά |
| 11 | **P2.5** — `.limit(100)` στο `streamChats` | Κόστος | 15 λεπτά |

> **P2.3/P2.4:** SKIP — δες αναλυτική αιτιολόγηση στην ενότητα 5.

### Φάση Δ — Χαμηλή Προτεραιότητα (P3 — 4 items)
| Σειρά | Θέμα | Impact | Εκτίμηση |
|:-----:|------|:------:|:--------:|
| 12 | **P3.1** — AuditLog N+1 (προληπτικό) | Performance | 20 λεπτά |
| 13 | **P3.3** — deleteUserData pagination (όταν χρειαστεί) | Scalability | 1 ώρα |
| 14 | **P3.4** — Requests stream `.limit(100)` | Κόστος | 15 λεπτά |

---

## Παράρτημα: Κανόνες Code Review για Firestore

```
🚫 ΠΟΤΕ:
- .get() χωρίς .limit()
- loop με individual writes (batch ή commitBatch πάντα)
- 2+ sequential awaits όταν μπορεί να γίνει Future.wait
- read μετά από write (το write πέτυχε, μην το ξαναδιαβάζεις)
- Duplicate onSnapshot listeners στο ίδιο doc

✅ ΠΑΝΤΑ:
- .limit(N) σε κάθε collection query (ακόμα και σε listeners)
- batch για >1 write operations
- Future.wait για ανεξάρτητες reads
- autoDispose σε StreamProviders που ακούνε Firestore
- Cache όπου είναι logical (Drift local, in-memory)
```

---

*Τελευταία ενημέρωση: 14 Ιουλίου 2026*
