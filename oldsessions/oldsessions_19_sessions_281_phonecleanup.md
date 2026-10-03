## Session 281 — Phone cleanup μετά από unlink (+7 tests) — 03 Οκτ 2026

### Σκοπός
Μετά το επιτυχές unlink έμεναν Drift `phone` + public snapshot (υπόλειμμα απορρήτου). Νέος coordinator `clearLocalPhone` + warn-only κλήση στο success-branch.

### Υλοποίηση (με backups, χωρίς 2+4 παραβίαση — 1 αρχείο/βήμα)
- Νέο `lib/features/settings/utils/phone_unlink_cleanup.dart` (~45 γρ.): `getProfile` → early-return αν null/empty → `saveProfile(copyWith(phone: Value(null)))` → `publish()` αν published. Νέο αρχείο αναγκαίο (settings 499, profile_impl 744/765).
- `settings_screen.dart`: import ×2 + try/catch-warn κλήση πριν το success-snackbar + `mounted` (lint `use_build_context_synchronously`).
- Συμβόλαιο: το coordinator ΠΕΤΑΕΙ (repo-layer σύμβαση), πιάνει ο caller — διορθώθηκε αρχικό λάθος στα tests.

### Tests (+7)
- `phone_unlink_cleanup_test`: null-profile/phone · empty · clear±publish · throw→throwsException. Μαθήματα: `registerFallbackValue` για custom types · `hide isNull` conflict drift/matcher.
- Υπάρχοντα unlink tests αμετάβλητα (warn path).
- Backups `backups/settings_screen_pre_phone_cleanup_*`, test CRLF/UTF-8.

### Έλεγχος
- `flutter analyze` → 0 issues. `flutter test` → **925/925** (was 918).

### DESIGN.md
- Δεν υπάρχει (15η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής.
