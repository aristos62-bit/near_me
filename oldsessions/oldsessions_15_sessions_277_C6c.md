## Session 277 — C6c implementation: writes/idempotency timeouts (100%) — 02 Οκτ 2026

### Σκοπός
Υλοποίηση της τελικής πρότασης C6c (Sessions 275-276 ουρά: writes/idempotency review). Μηδέν νέα helpers/codes/flags/strings — reuse `withTimeout`+`throwTimeoutAs`+`deleteChatSubcollection`+`StorageHelpers`. Με αναστολή 2+4 (ολόκληρη πρόταση μονοκοπανιά με backups).

### Υλοποίηση (12 αρχεία lib + 1 test, +0 νέα)
- **`core/utils/firestore_cleanup.dart`** — `batch.commit()` με `withTimeout 10s` + ίδια fatal/non-fatal break-σημασιολογία με το GET.
- **`core/services/presence_service.dart`** — `_start` naked `set online` → silent `withTimeout 6s` (ποτέ throw στο boot).
- **`core/notifications/fcm_service.dart`** — `clearTokens.commit` με 8s · κάθε `saveToken.set` attempt με silent 6s (retry-loop αμετάβλητο).
- **`repositories/group_search_repository.dart`** — `create/update/deletePublicProfile` με 6s (callers non-fatal).
- **`data/remote/storage_service.dart`** — import `timeouts.dart` + silent 10s στα `deleteAvatar/deletePhoto`.
- **`repositories/chat_repository_impl.dart`** — `_batchUpdateChatDocs` await+warn-catch+commits 8s · `sendMessage.commit` 8s + rethrow · `sendMedia.commit` 8s · `createChat.set` 8s · `markAsRead` head 6s + commit 8s · reactions update/delete 6s.
- **`repositories/chat_repository_delete.dart`** — leave-update 6s · chat-doc delete 8s · sysmsg commit 8s.
- **`repositories/chat_repository_message_actions.dart`** — edit update + delete doc 6s.
- **`repositories/request_repository_impl.dart`** — `sendAdd` 8s + rethrow · respond updates 6s · delete 6s · markSeen silent 6s.
- **`repositories/report_repository_impl.dart`** — import timeouts + `add` 8s.
- **`repositories/profile_repository_impl.dart`** — publish set 8s · unpublish 6s · helpRequest on/off 6s · geo-sync silent 6s.
- **`repositories/group_chat_mixin.dart`** — createSet 8s + `group/create-failed` · invite set 6s · revoke 6s · admin-remove 6s · creator-transfer 6s · name/role/perm/perm-reset/max/expiry/avatar updates 6-8s · group delete 8s · memberCount head+write silent 6s · syncField silent 6s.
- **`repositories/auth_repository_impl.dart`** — import timeouts · CF `deleteUserData` 8s silent · 4 deletes + blocked scan/loop 6s silent · `user.delete/re-auth` via υπάρχον `_withAuthTimeout`.
- **Εξαιρέσεις (τεκμηριωμένες):** `runTransaction` (retry semantics) · Drift όλα (local) · streams · encryption/moderation/pure SPoTs · `ConnectivityGuard` (CF μόνο) · manual CF gates ×4 + `FirebaseInit` (ήδη bounded, συνοχή).

### Tests
- `test/core/timeouts_test.dart` +3 (`chat/network-error`, `chat/delete-failed`, `chat/unknown-error`).
- `flutter analyze` → 0 issues. `flutter test` → **643/643** (was 640).

### Backups
- `backups/*_pre_C6c_20261002_*.dart` (12 lib + 1 test) + `backups/oldsessions*_pre_S277_*`.

### DESIGN.md
- Δεν υπάρχει στο repo (verified). Καμία αλλαγή αρχιτεκτονικής (client-only timeouts, ίδια payloads/rules/indexes/CF) → καμία δημιουργία/ενημέρωση.
