## Session 282 — 1-1 message expiry + gif overflow fix — 03 Οκτ 2026

### Σκοπός
Επέκταση του P3.2 expiry στα 1-1 chats (απλό μοντέλο: οποιοσδήποτε participant, ισχύει για νέα μηνύματα και για τους 2) + fix RenderFlex overflow σε φωτογραφίες/GIFs. Σχεδιασμός με 4 περάσματα πρότασης (12 βήματα + επανέλεγχοι reuse/παρανοήσεων).

### Υλοποίηση (6 lib αρχεία + rules, όλα με backups)
- **`firestore.rules`** — νέο branch: participant σε 1-1 (`isGroupChat != true`) αλλάζει μόνο `messageExpiry`. Group branch (creator/admin) αμετάβλητο. Deployed `firebase deploy --only firestore:rules` → `nearme-eu` ✅ (compiled + released).
- **`chat_repository.dart`** — +1 interface `updateOneToOneMessageExpiry`.
- **`chat_repository_impl.dart`** — νέα μέθοδος (mirror group: read 6s → guards exists/όχι-group/participant/validValues → update 6s → system message, χωρίς audit) + sync `messageExpiry` στο 1-1 Drift branch (update + insert).
- **`chat_provider.dart`** — νέα `updateOneToOneMessageExpiry` στο `ChatActionsNotifier` (κλώνος pattern, `bool`).
- **Νέο `one_to_one_expiry_sheet.dart`** (~150γρ.) — dialog + dropdown (ίδιες 7 τιμές/labels, bilingual, `ConnectivityGuard`, `mounted`, reuse error codes).
- **`chat_screen.dart`** — menu item 1-1 + branch (μόνο με flag).
- **Νέο `expiry_banner.dart`** — εξαγωγή `_ExpiryBanner` → `chat_screen` 525→430 γρ. (<500 ✅).
- **Overflow fix `gif_image_bubble.dart`** — αιτία: `stretch` (στενό 288) + εικόνα χωρίς ύψος· το SDK (`constrainSizeAndAttemptToPreserveAspectRatio`) ξαναμεγαλώνει το ύψος αγνοώντας το maxHeight (πορτρέτο 3:4 → 384, overflow 184). Video αθώο (σταθερό AspectRatio). Fix: εικόνα σε `Flexible` + `SizedBox.expand` (cover) → σύνολο πάντα ≤200, quote-safe.

### Έλεγχοι
- `flutter analyze` → 0 issues (πλήρες + στοχευμένα). `flutter test` → **925/925** (+0, μηδέν regressions· bubble tests 15/15).
- Backups `backups/*_pre_1to1expiry_20261003.bak` + `*_pre_banner_extract_*` + `gif_image_bubble_pre_overflowfix_*`.

### DESIGN.md
- Δεν υπάρχει (7η επιβεβαίωση). Καμία αλλαγή αρχιτεκτονικής (ίδιο engine/sweeper/index/CF/flag) → καμία ενέργεια.
