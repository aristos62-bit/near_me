## Session 279 — Open items: overflow fix + chat_list guard + tests (+103) — 03 Οκτ 2026

### Σκοπός
Κλείσιμο των ανοιχτών από S278: overflow fix, chat_list guard + tests, highlight, settings/delete/blocked/messenger/chat-actions/chat-logic/permissions/idle/filters/emoji/fromFirestore tests. Δύο production micro-edits με OK χρήστη, όλα τα άλλα test-only.

### Production micro-edits (2, με backups)
- `incoming_share_sheet.dart` — Column → SingleChildScrollView (S274 pattern, αόρατο όταν χωράει). Backup `backups/incoming_share_sheet_pre_overflow_20261002_180000.dart`.
- `chat_list_screen.dart` — TextEditingController → onChanged draft (έσβηνε dispose-race στο dialog pop), try/catch guard γύρω από 2× `FirebaseAuth.instance` (VM-safe, ίδια συμπεριφορά με app). Backups `backups/chat_list_screen_pre_{authguard,invitedialog}_*.dart`.

### Νέα tests
- `dashboard_highlight_test` (2), `delete_account_screen_test` (9), `settings_screen_test` (15), `blocked_users_screen_test` (6), `app_messenger_test` (8), `emoji_picker_config_test` (6), `chat_actions_notifier_test`, `chat_providers_logic_test` (harness reuse), `chat_list_screen_test` (8), `group_permissions_info_test`, `search_filters_test`, `idle_lock_service_test`, `group_search fromFirestore` append, `connectivity_mocks` helper.
- Μαθήματα: nested `when` ποτέ · autoDispose → listen-pattern · dialog-pop χωρίς controller · lazy ListView → tall viewport · `any(named:)` overlap → exact values · ErrorView 'Retry' σκληρό · `go` αντικαθιστά, `push` κρατάει stack.

### Παρατηρήσεις χωρίς αλλαγή
- `_BlockedUserTile` unblock χωρίς try/catch (διαρροή σε αποτυχία).
- Phone notifier δεν περνάει `_mapPhoneError` (βγαίνει unknown-error).
- Blueprint §14/§16 stale · §19 βήμα 7 (secure-storage deleteAll) λείπει από deleteAccount impl.

### Έλεγχος
- `flutter analyze` → 0 issues. `flutter test` → **906/906** (was 803, +103).
- Test `.dart` CRLF / UTF-8 no BOM, ελληνικά επαληθευμένα.

### Backups
- `backups/*20261002_180000*`, `backups/*20261003_120000*`, `backups/oldsessions*_pre_S279_*`.

### DESIGN.md
- Δεν υπάρχει (6η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής → καμία ενέργεια.
