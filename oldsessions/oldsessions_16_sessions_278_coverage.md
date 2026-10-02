## Session 278 — Coverage P1-P4: pure utils + leaf widgets + notifiers + request screens (+160 tests) — 02 Οκτ 2026

### Σκοπός
Κλείσιμο των μεγαλύτερων κενών κάλυψης (screens ~2-9%, shared/utils 20.1%) με 4 φάσεις. Μηδέν production edits, μηδέν νέες dependencies/keys/flags — μόνο `test/` + 1 helper.

### Spikes (πριν τις φάσεις)
- **Connectivity mock: PASS** — channel `dev.fluttercommunity.plus/connectivity`, `check` → `['wifi']/['none']`. Νέο `test/helpers/connectivity_mocks.dart` (μοναδικό νέο shared αρχείο, test-only). Τεχνική-reuse από clipboard mock S269. Production hook ΔΕΝ χρειάστηκε.
- **DatabaseService real init σε VM: SKIP** — lazy success + platform-channel throw στο πρώτο touch + static-singleton ρύπανση. Τα 3-4 tests αποσύρθηκαν (fallback του πλάνου).

### P1 pure/utils (~91)
- `error_messages_test` (21): known codes el/en + bilingual passthrough. Εύρημα: 0 direct tests πριν.
- `l10n_formatters_test` (21): distances/labels/auto-lock/unread/help/blur + `localizedMessage` via testWidgets. Μαθήματα: `supportedLocales` + delegates υποχρεωτικά (S264/S270).
- `mention_utils_test` (9), `consent_action_config_test` (8), `help_request_config_test` (10, HelpRequest verified), `avatar_blur_test` (6, χωρίς pump), `giphy_gif_test` (7 — μόνο pure/invalid/empty-key paths), `vision_failopen_test` (4), `firebase_init_test` (2, false χωρίς app), `presence_lifecycle_test` (3 — paused/detached/reset· resumed ρητά εκτός, πετάει σύγχρονα σε VM).
- Εκτός με αιτιολόγηση: `phoneCountryCode` (host-locale), Giphy network, StorageService direct (έμμεσα via mixin), `consent_log_provider` + chat streams (static auth/global caches, χωρίς hook), CachedNetworkImage path.

### P2 leaf widgets S270-remnants (15)
- `read_receipt_indicator_test` (6, icons/counts — όχι tooltip text), `chat_recipient_picker_test` (4), `incoming_share_sheet_test` (5, χωρίς Image.file branch).
- **Υποψήφιο production bug (δεν άλλαξε):** RenderFlex overflow ~2.5px στο sheet σε 800×600 — ίδιο handling S273/S274 (viewport override στο test, απόφαση χρήστη εκκρεμεί).

### P3 notifiers (35)
- `verify_welcome_notifiers_test` (12), `phone_verify_notifier_test` (13 — no-vId guard χωρίς connectivity), `delete_account_notifier_test` (6), `unread_requests_provider_test` (4, listen-pattern S271).
- Μαθήματα: ΚΑΝΕΝΑ nested `when` (hoisted users) · `.future`-read σε autoDispose → listen-pattern · phone friendly-codes κλειδώνουν πραγματική συμπεριφορά (`auth/unknown-error`, ο notifier δεν περνάει `_mapPhoneError` — παρατήρηση, όχι αλλαγή).

### P4 request screens (19, πλήρεις αναγνώσεις 327+366 γρ.)
- `send_request_screen_test` (10): chips-matrix, selection, unverified/disabled, input, offline-stay, online success (GoRouter home+push stack — το `go` αντικαθιστά, το `pop` θέλει stack) + args, failure snackbar+reenable. Μάθημα: `_settleTimer` παντού (build-logs) · AppBar/button ομώνυμο κείμενο.
- `requests_dashboard_test` (9): locked, empty tabs, lists+badges, error+`Retry` (το ErrorView label είναι σκληρό 'Retry', το μήνυμα 'Σφάλμα φόρτωσης' χωρίς τελεία), filters, selection/select-all/close, markAsSeen, accept+snackbar, bulk-delete (confirm FilledButton disambiguation).
- Spike-gated (highlight-scroll, settings/chat_list screens): εκτός μετρήσεων.

### Έλεγχος
- `flutter analyze` → 0 issues (3 test-lints διορθώθηκαν: unused import, `(_,_)`).
- `flutter test` → **803/803** (was 643, +160).
- Line endings: test `.dart` CRLF / UTF-8 no BOM (S272), ελληνικά επαληθευμένα via Read.

### Backups
- `backups/oldsessions*_pre_S278_*` (τα νέα test files δεν θέλουν backup — δημιουργήθηκαν τώρα).

### DESIGN.md
- Δεν υπάρχει (5η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής → καμία ενέργεια.
