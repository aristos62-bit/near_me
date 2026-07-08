# PERMISSION_DENIED — Firestore Listeners After Sign-Out

## Πρόβλημα

Κατά την αποσύνδεση (`signOut()`), οι ενεργοί Firestore listeners (`snapshots()`) παραμένουν ζωντανοί μετά την ακύρωση του auth token, προκαλώντας 6× συνεχόμενα PERMISSION_DENIED errors:

```
Listen for .../status/status ... failed: PERMISSION_DENIED   (×4)
Listen for .../requests where toUid==... failed: PERMISSION_DENIED
Listen for .../chats where participants... failed: PERMISSION_DENIED
```

## Αιτία

Στο `auth_repository_impl.dart:signOut()`, η `_auth.signOut()` ακυρώνει το auth token **πριν** προλάβουν να ακυρωθούν οι Firestore listeners:

```
signOut():
  1. PresenceService.setOffline()
  2. FcmService.clearTokens()
  3. LocationService.clearSession()
  4. Chat cache clear
  5. _auth.signOut()             ← TOKEN INVALIDATED ΕΔΩ
                                  ← Listeners ακόμα ενεργοί → PERMISSION_DENIED
```

### Listeners που παραμένουν ζωντανοί

| Count | Path | Provider | Τύπος |
|:-----:|------|----------|:-----:|
| 4 | `users/{uid}/status/status` | `userStatusProvider` (family) | snapshots() |
| 1 | `requests` (incoming) | `incomingRequestsProvider` | snapshots() |
| 1 | `requests` (outgoing) | `outgoingRequestsProvider` | snapshots() |
| 1 | `chats` (participants) | `chatsProvider` | streamChats() async* + listen |

### Blocker: main.dart listener chain

Το `main.dart:336` έχει `ref.listen(unreadBadgeProvider, (_, _) {})` πάνω σε non-autoDispose `Provider<int>`. Αυτό κρατάει ζωντανή όλη την αλυσίδα:

```
main.dart ref.listen(unreadBadgeProvider, ...)
  → unreadBadgeProvider (Provider, non-autoDispose)
    → chatsProvider (StreamProvider, non-autoDispose)
    → unreadRequestsProvider (Provider, autoDispose)
      → incomingRequestsProvider (StreamProvider, autoDispose)
```

Ακόμα και τα `autoDispose` providers **δεν αποδεσμεύονται** όσο υπάρχει watcher στην αλυσίδα.

---

## Λύση

### Προσέγγιση: Guard Flag + autoDispose + Invalidation

Τρία επίπεδα άμυνας:

#### 1. Interface Level — Static Guard Flag (`auth_repository.dart`)

Προσθήκη static `isSigningOut` flag στο `AuthRepository` interface. Κάθε repository μπορεί να το ελέγξει χωρίς να εξαρτάται από το implementation.

Το `signOut()` στο `AuthRepositoryImpl` θέτει `isSigningOut = true` **πριν από όλες** τις λειτουργίες cleanup:

```
signOut(): 1. setSigningOut(true) → 2. setOffline() → ... → N. _auth.signOut() → setSigningOut(false)
```

#### 2. Repository Level — Guard Checks

- `streamChats()`: `if (isSigningOut) { yield []; return; }`
- `streamIncomingRequests()`: `if (isSigningOut) return Stream.empty();`
- `streamOutgoingRequests()`: `if (isSigningOut) return Stream.empty();`

Αν το Riverpod ξαναχτίσει providers κατά τη διάρκεια του signOut, οι νέοι streams επιστρέφουν κενά αμέσως — **κανένας νέος Firestore listener δεν δημιουργείται**.

#### 3. Provider Level — autoDispose + error handling (`status_provider.dart`)

Αλλαγή `userStatusProvider` από `StreamProvider.family` → `StreamProvider.autoDispose.family`. Προσθήκη `.handleError()` για graceful fallback σε PERMISSION_DENIED.

#### 4. Caller Level — Invalidation (`settings_screen.dart:_signOut()`)

Provider invalidation πριν το `signOut()` για να διακοπεί η main.dart chain:
```
ref.invalidate(chatsProvider)
ref.invalidate(incomingRequestsProvider)
ref.invalidate(outgoingRequestsProvider)
ref.invalidate(unreadBadgeProvider)
```

### Χρονική ακολουθία post-fix

```
1. ref.invalidate(...) providers           ← marks dirty
2. AuthRepository.setSigningOut(true)     ← GUARD: νέοι streams επιστρέφουν κενά
3. PresenceService/FCM/Location cleanup    ← token ακόμα valid ✅
4. Old streams fire (αν υπάρχουν)          ← token valid ακόμα → κανένα PERMISSION_DENIED ✅
5. _auth.signOut()                         ← TOKEN INVALIDATED
6. Riverpod rebuilds (next microtask)      ← νέοι streams → isSigningOut=true → empty ✅
7. Router redirect → /welcome              ← providers autoDispose (no watchers) ✅
```

---

## Αρχεία προς αλλαγή

| # | Αρχείο | Αλλαγή | Κατάσταση |
|:-:|--------|--------|:---------:|
| 1 | `auth_repository.dart` | Static `isSigningOut` flag + setter (interface) | ✅ |
| 2 | `auth_repository_impl.dart` | `setSigningOut(true)` πριν cleanup + `setSigningOut(false)` μετά | ✅ |
| 3 | `chat_repository_impl.dart` | `isSigningOut` guard στο `streamChats()` | ✅ |
| 4 | `request_repository_impl.dart` | `isSigningOut` guard στα `streamIncoming/OutgoingRequests()` | ✅ |
| 5 | `status_provider.dart` | `autoDispose.family` + `handleError()` | ✅ |
| 6 | `settings_screen.dart` | Provider invalidation (chatsProvider, requestProviders, unreadBadgeProvider) | ✅ |

---

## Πρόοδος

| Βήμα | Περιγραφή | Ημερομηνία | Κατάσταση |
|:----:|-----------|:----------:|:---------:|
| 1 | Ανάλυση προβλήματος — 6× PERMISSION_DENIED | 2026-07-08 | ✅ |
| 2 | Ανακάλυψη blocker: `main.dart:336 ref.listen(unreadBadgeProvider)` | 2026-07-08 | ✅ |
| 3 | Σχεδιασμός λύσης: guard flag + autoDispose + invalidation | 2026-07-08 | ✅ |
| 4 | `auth_repository.dart` — static `isSigningOut` flag | 2026-07-08 | ✅ |
| 5 | `auth_repository_impl.dart` — `setSigningOut(true)` στο `signOut()` | 2026-07-08 | ✅ |
| 6 | `chat_repository_impl.dart` — `isSigningOut` guard | 2026-07-08 | ✅ |
| 7 | `request_repository_impl.dart` — `isSigningOut` guards | 2026-07-08 | ✅ |
| 8 | `status_provider.dart` — `autoDispose.family` + `handleError()` | 2026-07-08 | ✅ |
| 9 | `settings_screen.dart` — provider invalidation before signOut | 2026-07-08 | ✅ |
| 10 | `dart analyze` — No issues found | 2026-07-08 | ✅ |

---

## Edge Cases

| Σενάριο | Συμπεριφορά |
|:---------|:------------|
| Double tap signOut | Idempotent — `_cancelAllSubscriptions()` σε κενή λίστα + `_auth.signOut()` |
| Network failure | `setOffline()` fail → catch. `_cancelAllSubscriptions()` local, δεν απαιτεί network |
| App lifecycle pause | `PresenceService._isShuttingDown=true` → lifecycle ignored |
| Re-login μετά | New auth → new providers → new listeners (registry empty) |
| Delete account | Ίδιο PERMISSION_DENIED pattern — προτείνεται ξεχωριστό fix |

---

## Σημειώσεις

- **Δεν επηρεάζεται** το UI/resize/multilanguage — μόνο business logic & state management
- **Δεν αλλάζει** η διεπαφή (`AuthRepository`, `RequestRepository`, `ChatRepository`) — μόνο implementation
- **Debug logging** με `DebugConfig` flags: `providerDispose`, `presence`, `authFlow`, `firestoreStream`
