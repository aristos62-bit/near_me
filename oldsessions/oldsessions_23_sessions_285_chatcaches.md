## Session 285 — Φάση Β5: chat caches reset + cache-hit tests — 03 Οκτ 2026

### Σκοπός
Determinism + επαλήθευση του anti-rebuild-storm machinery (S174/S178/S200/S216) με tests.

### Υλοποίηση (1 function + 1 test file, με backup)
- **`chat_provider.dart`** (+~12γρ.): `@visibleForTesting resetChatProviderCaches()` — καθαρίζει ΜΟΝΟ τις 2 globals (`_chatDocSnapCaches`, `_participantUidCaches`). Οι instance caches δεν το χρειάζονται (πεθαίνουν με το container· υπάρχει η `clearMessageCaches`). Παράπλευρο lint-fix: αφαίρεση πια-άχρηστου `dart:typed_data` import (το δίνει η foundation).
- **Νέο `test/features/chat/chat_cache_test.dart`** (6 tests): setUp reset · chatDoc suppression (single emit, snap1) · changed doc → νέο emit · participantUids identical · stream→getters→clear→empty · messagesStream identical · streamChats no-duplicate-emit.

### Πραγματικά ευρήματα (test-driven)
1. Το fake **δεν εκπέμπει event** σε πανομοιότυπο `set` → suppression μέσω mocktail `Stream.fromIterable` με 2 διακριτά snaps.
2. Η encrypt-cache γεμίζει από το **messagesStream**, όχι από το send.
3. Το Riverpod κάνει **dedup ίδιων τιμών** → η απόδειξη του suppression είναι η απουσία 2ου emit (όχι `identical` δύο emits).

### Έλεγχοι
- `flutter analyze` → 0 issues. `flutter test` → **947/947** (was 941, +6).
- Backup `backups/chat_provider_pre_B5_20261003.bak`.

### DESIGN.md / blueprint.md / audit_report.md
- Δεν υπάρχει DESIGN.md (17η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής → καμία ενημέρωση blueprint/audit.
