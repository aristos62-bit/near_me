## Session 283 — Shared SPoT message expiry — 03 Οκτ 2026

### Σκοπός
Ενοποίηση των 7 expiry τιμών (6 σημεία duplication) σε ένα pure SPoT, μετά από 3 περάσματα πρότασης (12 βήματα + επανέλεγχοι + rebuild-storm ανάλυση από Κεφ.10).

### Υλοποίηση (1 νέο + 5 edits, όλα με backups)
- **Νέο `features/chat/utils/message_expiry.dart`** (~55γρ., pure, μηδέν imports): `off` · `values` (κλειδωμένη σειρά) · `isValid` · `durationFor` · `display(v, greek)`. Pattern `SystemMessageFormatter`.
- **`group_chat_mixin.dart`** — `validValues` → `isValid`.
- **`chat_repository_impl.dart`** — `const validValues` → `isValid` · διαγραφή `_expiryDuration`, 2 call sites → `durationFor`.
- **`group_settings_screen.dart` + `one_to_one_expiry_sheet.dart`** — 7 items → `values.map` (το `'off'` label ειδική περίπτωση, ίδια συμπεριφορά).
- **`expiry_banner.dart`** — διαγραφή `_expiryDisplay`, κλήση `display`.
- Απορρίφθηκαν αιτιολογημένα: `L10n.autoLockSubtitle/blurSigmaLabel` reuse (άλλη σημασιολογία) · widget-list στο SPoT (material import σε pure) · `off` const παντού (diff noise) · literals στα tests (pin συμπεριφοράς).
- Rebuild storms: μηδενική επίδραση (κανένα νέο watch/listen/MediaQuery· ίδιο `select`· const identical reference).

### Έλεγχοι
- `flutter analyze` → 0 issues. `flutter test` → **934/934** (+9 νέα pure `message_expiry_test`, was 925).
- Backups `backups/*_pre_expiryspot_20261003.bak`.

### DESIGN.md / blueprint.md
- Δεν υπάρχει DESIGN.md (11η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής (pure refactor, ίδια payloads/rules/indexes/CF) → καμία ενημέρωση blueprint.
