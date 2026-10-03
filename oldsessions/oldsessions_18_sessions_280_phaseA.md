## Session 280 — Φάση Α closure: A.1 + A.2 + A.3 + phone re-enable — 03 Οκτ 2026

### Σκοπός
Κλείσιμο όλων των ανοιχτών Φάσης Α. Κανόνες: backups πριν κάθε edit, ένα βήμα τη φορά (2+4 ανεστάλησαν τμηματικά με ρητή εντολή), tests τα έτρεξε ο χρήστης στην κονσόλα.

### A.1 — try/catch σε unblock/block (3 sites)
- `blocked_users_screen.dart` tile + `public_profile_actions.dart` unblock + block branches: try/catch με `DebugConfig.error` + `showError('unknown')`. Success-paths byte-ίδια, 0 νέα keys/imports.
- Tests: fail-test στο tile (NOTE→πραγματικό) + 2 fail-tests στο public_profile (mock throws → system snackbar).
- Backups `backups/*_pre_A1_20261003_140000.dart`.

### A.2 — 5 mappings στο `_mapPhoneError`, 0 νέα keys
- `missing-phone-number`→`auth/invalid-phone-input` · `code-expired`→`auth/invalid-code` · `user-not-found`→`auth/user-not-found` · `invalid-credential`→`auth/invalid-credential` (συνέπεια με `toFriendlyMessage`) · captcha-τριάδα→`auth/invalid-verification`.
- Ρητά εκτός: `user-disabled` (non-disclosure), `user-mismatch`, `requires-recent-login`, `second-factor-*`.
- Tests: +5 στο υπάρχον pattern (`failed(code)`/link-throw).
- Backups `backups/*_pre_A2_20261003_150000.dart`.

### A.3 — key wipe στο deleteAccount
- `EncryptionUtils.clearAllKeys()` μετά το `clearAllTables`, warn-only (blueprint §19.7). Μοναδικό secure-storage περιεχόμενο = chat keys (grep). Νέα tests: κανένα (αδύνατα σε VM — static `FirebaseAuth.instance` στο `clearTokens`, αποδεδειγμένο).
- Παρατηρήσεις χωρίς αλλαγή: λείπει `deleteToken()` παντού · `go('/auth')` vs blueprint `/goodbye` · blueprint «Firebase tokens» stale.
- Backup `backups/auth_repository_impl_pre_A3_20261003_170000.dart`.

### Phone re-enable + SHA (nearme-eu)
- Flag `phoneVerificationEnabled` → true (1 γραμμή). Μόνη πύλη κώδικα (settings:170)· route `/settings/phone-verify` υπήρχε.
- SHA: λάθος project στην αρχή (nearme-gr/com.example) → σωστό (nearme-eu/gr.nearme.app), 4 fingerprints (debug+release × SHA-1/SHA-256 από `signingReport`) · Phone method enabled · json ήδη nearme-eu (re-download περιττό).
- Tests: phone-section presence + unlink flows (5) στο settings_screen_test.
- Backup `backups/feature_flags_pre_phone_enable_20261003_160000.dart`.

### Έλεγχος
- `flutter analyze` → 0 issues (project + ανά αρχείο σε κάθε βήμα).
- `flutter test` → **918/918** (906 + A.1×3 + A.2×5 + settings-phone×4).
- Test `.dart` CRLF / UTF-8 no BOM, ελληνικά επαληθευμένα.
- Μαθήματα: nested `when` ποτέ · autoDispose→listen-pattern · dialog-pop χωρίς controller · lazy-ListView→viewport/ensureVisible · `any(named:)` overlap→exact · `go` vs `push` stack · `(_,_)` lint · EventChannel-skip.

### Backups (σύνολο Φάσης Α)
- `backups/*_pre_C6c_*`, `*_pre_S277_*`, `*_pre_S278_*`, `*_pre_A1_*`, `*_pre_A2_*`, `*_pre_A3_*`, `*phone_enable*`, `*_pre_S280_*`.

### DESIGN.md
- Δεν υπάρχει (14η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής σε όλη τη Φάση Α → καμία ενέργεια.
