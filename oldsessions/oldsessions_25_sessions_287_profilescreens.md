## Session 287 — Φάση Γ7 Profile screens (+22 tests) — 03 Οκτ 2026

### Σκοπός
Τα profile screens είχαν μόνο provider/repo/publish_payload tests (Γ7 ανοιχτό). Υλοποιήθηκε η τελική πρόταση: 0 νέα util-arch (μόνο 3 leaf widgets) + 7 διορθώσεις + 22 tests. Κανόνας 2+4 αναστάλθηκε από χρήστη.

### Υλοποίηση (backup `backups/profile_g7_20261003_215219/`, 6 αρχεία)
- `geohash_utils.dart` (+~15γρ.): νεκρός `precisionLabel` (0 callers) → δίγλωσσος + νέο `precisionDesc` (Γ7).
- `consent_action_config.dart` (+~12γρ.): νέο `dataTypeLabel` (φυσική θέση, όχι νέο αρχείο).
- ΝΕΑ `features/profile/widgets/`: `profile_avatar_header.dart` (~100), `profile_photo_gallery.dart` (~95), `profile_location_section.dart` (~200, κατέχει focus nodes + debounce timers + suggestions).
- `profile_editor_screen.dart` (683→474): εξαγωγές ×3 · dup `_genderLabels/_lookingForLabels` → `L10n` · email/phone `validator` με empty-guard (E1: τα πεδία είναι nullable, γυμνό validator θα μπλόκαρε το save) · `MediaQuery.padding` → `safeAreaPadding` (consistency).
- `privacy_editor_screen.dart` (292→262): flag `providerCreate`→`uiInteraction` · labels → `GeoHashUtils`.
- `consent_log_screen.dart` (240→228): error → `stream/load-error` · label → config · +3 `log(consentLogRead)` · `_dataTypeLabel` διαγράφηκε.
- `profile_screen.dart` (401→397): −build-log · error → `stream/load-error` · age → `ageFromBirthYear`+`ageLabel` (EN `yo`→`years`) · authState → settings-cache (μόνο User, το unread-int έμεινε).

### Αποσύρσεις (τεκμηριωμένες)
- Νέο `profile_labels.dart`: ΟΧΙ (επανάχρηση). `_cachedGreek`: ΟΧΙ (YAGNI). `_MenuItem`/`_formatTimestamp`/pagination/GPS/save: μένουν (blast-radius/0-κέρδος).
- Phone-gate, router, notifiers, timeouts, offline-gate: ανεπηρέαστα.

### Tests (+22 → 1000/1000)
- `geohash_utils_test` +2 (labels/descs el/en) · `consent_action_config_test` +2 (dataType).
- `profile_screen_test` (6): render/empty/banner, publish on + snackbar, offline verifyNever, signOut-cancel.
- `privacy_editor_screen_test` (4, GoRouter harness για success-pop): render, flip→save τιμή + pop-home, street→save, offline verifyNever.
- `consent_log_screen_test` (4): in-memory Drift + DI hook (F1, χωρίς mocks)· render, empty, filter, 55 rows loadMore.
- `profile_editor_screen_test` (4, GoRouter harness): render, nickname-required, invalid-email, **κενό-email-περνά (E1 regression)** + chat-sync verify + pop-home.
- Μαθήματα: `registerFallbackValue` για drift types · ListView χτίζει τεμπέλικα → ρητό drag-loop (το page-Scrollable δεν ξεχωρίζει: bio-field 2ο vertical· ancestor-κατεύθυνση ανάποδη· `AxisDirection.down` όχι `Axis`) · `_enterByLabel` (indices αλλάζουν) · FilterChip descendent (chip vs entry ίδιο κείμενο) · `scrollable:` θέλει Scrollable (όχι ListView) · GoRouter harness όπου success-pop · mocktail-locals-πρώτα · `+1` σε test env (Γ6).

### Έλεγχος
- `flutter analyze` → 0 issues. `flutter test` → **1000/1000** (was 978). Όλα τα αρχεία <500 γρ.

### Αρχιτεκτονική
- Καμία αλλαγή (flows/router/notifiers/repo/GPS/publish/flags αμετάβλητα) → **δεν** ενημερώθηκαν `nearme_blueprint.md` / `audit_report.md`.
