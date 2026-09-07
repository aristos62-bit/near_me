## ΚΕΦΑΛΑΙΟ 10 — REBUILD STORMS: SETTLED / PENDING / REJECTED

> Το μεγαλύτερο διαρκές θέμα του project. Συγκεντρωτική κατάταξη όλων των rebuild-related fixes με την τελική τους κατάσταση.

### SETTLED ✅ (λύθηκαν & verified — ο κώδικας είναι ο ενεργός fix)

#### Root cause — Localizations (Session 224, fix6 · ΣΤΑΘΕΡΟ)
- **Σύμπτωμα:** 24-26 πλήρη `MSG_LIST BUILD`/sec με πανομοιότυπα hashes σε κάθε keyboard animation.
- **Αιτία:** `Localizations.localeOf(context)` μέσω `L10n.isGreek(context)` στο `build()` — ακόμα κι αν το locale δεν αλλάζει, τα rebuilds αλλάζουν ανά frame.
- **Fix:** `bool _cachedGreek` + ανάγνωση ΜΟΝΟ σε `didChangeDependencies()`. Zero InheritedWidget dependency στο build(). Verified: μηδέν storms, locale-switch 100% λειτουργικό.

#### Root cause — MediaQuery στο ChatMessagesList.build() (Session 221, fix3 · ΣΤΑΘΕΡΟ)
- **Σύμπτωμα:** 22-26 rebuilds σε κάθε keyboard open/close.
- **Αιτία:** `MediaQuery.sizeOf(context)` (screenH diagnostic + `width` για responsive padding) — viewInsets αλλάζει ανά frame.
- **Fix:** `LayoutBuilder` + `ResponsiveUtils.resolveWidth(context, constraints)` — **ZERO MediaQuery στο αρχείό** (grep-verified). Verified: μηδέν `MSG_LIST BUILD` από keyboard/scroll.

#### fix5 — SPoT width-cache (Session 222 · ΣΤΑΘΕΡΟ)
- ListView instance επιστρέφεται **identical** σε αλλαγή μόνο ύψους → `ListView REUSED ... itemBuilder NOT re-invoked (×25)`. Idle: 4+ λεπτά με 0 bursts.

#### Selectors rebuild (Session 221 · ΣΤΑΘΕΡΟ)
- `participantNicknames`/`participantAvatarUrls` έφτιαχναν νέο Map ανά build → Riverpod identity νόμιζε «άλλαξε». Fix: **cached-instance** (όπως `lastReadTimestamps`).

#### bubbleMaxWidth SPoT (Session 222 · ΣΤΑΘΕΡΟ)
- Υπολογιζόταν σε 4 αρχεία με ξεχωριστό LayoutBuilder καθένα. Fix: **ένας υπολογισμός** στο ChatMessagesList (`w * 0.75`), πέρασμα ως required param σε όλα τα 5 bubble types. Αφαιρέθηκαν όλα τα βubble-level LayoutBuilder.

#### Ιστορικά fixes (Sessions 70-203 · ΟΛΑ STABLE)
| Session | Fix |
|---|---|
| 70 | ChatScreen rebuild loop (5x/4s) — page keys + smart auth notifier + batch pagination |
| 137 | ProfileCards ~20× rebuilds — `ValueKey` + `select()` + `SearchResultsGrid` extraction |
| 174 | chatDocProvider cascade — cache + `DeepCollectionEquality` |
| 178 | ChatScreen storm — participantUidsProvider cache + `select()` |
| 179 | EmojiPicker storm — `EmojiPickerPanel` leaf widget |
| 188 | Exit animation storm + idle rebuilds — remove GoRouterState·from build, `ValueKey(msg['id'])` + `ValueKey('ds_$date')` |
| 189 | MainShell LayoutBuilder cascade — StatefulWidget + cached `isWide` |
| 192 | chatDocProvider.select() AsyncValue → return `Map` (deep comparison) |
| 193 | participantUidsProvider autoDispose cascade — remove autoDispose |
| 195 | decrypt lastMessage media FormatException — skip-decrypt gif/image/video |
| 196 | LayoutBuilder per-bubble → pre-computed `bubbleMaxWidth` |
| 197 | markAsRead σε build path → `initState` `addPostFrameCallback` |
| 198 | Keyboard cascade 26× — `_SafeInputArea` leaf widget |
| 199 | pending=true→false cascade — suppression σε chatDocProvider |
| 200 | messagesStream νέα list instances — `DeepCollectionEquality` cache (same reference) |
| 200 | `_obtainBubble` cascade — `_MessageBubbleSignature` + instance cache |
| 201 | EmojiOnlyBubble `_buildCounts` static leak — removed |
| 201 | markAsRead serverTimestamp όταν `unreadCount==0` — guard (skip write) |
| 203 | Bubble width = max στην αρχή — `IntrinsicWidth` wrapper |
| 216 | chatsProvider redundant emits — equality-check στο `.watch()` |

#### «Φυσιολογικό» (δεν χρειαζόταν fix — Session 222 · ΚΛΕΙΣΙΜΟ ΘΕΜΑΤΟΣ)
- Τα `ReplyPreview ×N` στα bursts = **sliver-level relayout των ορατών bubbles** (τα ίδια Elements, όχι νέα ListView/items). Bounded, μόνο σε αλληλεπίδραση, idle=0, όχι leak/loop. **Δεν εφαρμόστηκε επεμβατική βελτιστοποίηση** (ρίσκο > όφελος).

---

### PENDING ⏳ (εκκρεμούν — όχι ενεργά σφάλματα)

| Θέμα | Πηγή |
|---|---|
| ~~`ChatScreen` ξαναφτιάχνει `_messagesList` σε video play/fail (chat_screen.dart:134,150,161) — σκοτώνει το fix5 width-cache~~ → **✅ ΚΛΕΙΣΕ (Session 232: videoPlaybackProvider)** | Session 222 |
| ~~Device test νέων διακριτικών logs (Log A/B/C: item, ReplyPreview id/h, inst) + ανάλυση — ζητήθηκε από χρήστη~~ → **✅ ΕΛΗΞΕ (13 Αυγ)** | Session 221 |
| ~~`join_confirmation_screen.dart:72` + `fcm_service.dart:89,166` — deep links χωρίς `extra` (group-capable)~~ → **✅ ΚΛΕΙΣΕ (Session 232: ChatScreen cold-path chatDoc lookup με `!mounted` re-check)** | Session 218 |
| ~~`AppMessenger.showLoading/hideLoading` — dead code (δεν καλούνται πουθενά· τα media sends χρησιμοποιούν `_isLoading` spinner)~~ → **✅ ΚΛΕΙΣΕ (Session 232)** | Session 225 |

---

### REJECTED / REVERTED ❌ (δοκιμάστηκαν & απορρίφθηκαν — παραμένουν μόνο ως ιστορικό)

| # | Προσέγγιση | Αιτία απόρριψης |
|---|---|---|
| 1 | **fix4 — memoization ολόκληρου ListView** (Session 221, backup `..._memo.bak`) | REVERTED: στο relayout ο `itemBuilder` ξανακαλείται ούτως ή άλλως για τα ορατά items (sliver child cycle) — το memoized ListView δεν σταματάει τα bubble rebuilds. Plus: τα `ReplyPreview ×26` ήταν **aggregate** χωρίς msgId/instance — δεν μας έλεγαν ποια εστία. |
| 2 | **fix2 — cached width μέσω `didChangeDependencies()`** (Session 221, backup `..._fix2.bak`) | Απέτυχε: η κλήση `MediaQuery.sizeOf()` στη `didChangeDependencies` δηλώνει κι αυτή MediaQuery dependency → το keyboard συνέχισε να ξαναχτίζει. |
| 3 | **Option A (skip-write) & C (debounce)** για chatsProvider redundant emits (Session 216) | A = invasive (4 σημεία, false-negative risk σε timestamps)· C = προσθέτει latency στο live chat. Επιλέχθηκε ο equality-check. |
| 4 | **`select()`/grid-level fixes για ProfileCard (×2)** (Session 215) | Αναλύθηκε & απορρίφθηκε: το `(×2)` προέρχεται από `userStatusProvider` (design του online-flicker fix #155), όχι από το grid — το `select()` θα εισήγαγε risk στο loadMore spinner. |
| 5 | **Firebase init retry screen** (Session 219, full REVERT) | Πλήρες revert: το init **δεν** απαιτεί δίκτυο (bundled `google-services.json`)· το «Retry» που έβλεπε ο χρήστης ήταν το υπάρχον offline UX του Discovery. Ο κώδικας δεν άφησε κανένα ίχνος. |

### Μάθημα (Session 221-224, κρατάμε για το μέλλον)
1. **ΠΟΤΕ** `MediaQuery.sizeOf/viewInsetsOf/viewPaddingOf` σε `build()` αν το widget πρέπει να είναι σταθερό — η dependency είναι σε ΟΛΟ το MediaQueryData.
2. Διάγνωση πριν από fix: **SIG-diagnostic** (hash/identity των watches) + αποκλεισμοί (parent rebuild, provider emits, setState, MediaQuery) πριν οτιδήποτε speculative.
3. **Ποτέ speculative fix σε aggregate logs** — πρώτα διακριτικά (msgId/instance/identityHashCode).
4. Το σωστό pattern του codebase: επιμέρους equality-caches (identical reference) + `LayoutBuilder`· «no MediaQuery rebuild cascade».

---

