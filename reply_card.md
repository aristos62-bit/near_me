# Reply Quote — Merged Quote Card (Ενοποιημένη κάρτα quote μέσα στο bubble)

**Έκδοση:** v1.0 · **Ημερομηνία:** 12 Αυγ 2026 · **Αρχείο πρότασης/οδηγός:** `reply_card.md`
**Κατάσταση:** ΠΡΟΣ ΕΓΚΡΙΣΗ (κανένα edit ακόμα)

---

## 1. Στόχος & εικόνα-στόχος

Σήμερα: 2 ξεχωριστές κάρτες — quote **πάνω** (με δικό `surfaceContainerHighest` bg) και το bubble **κάτω** (με δικό χρώμα).

Στόχος: **μία ενοποιημένη κάρτα**, όπου το quote είναι «ενσωματωμένο» στην κορυφή του bubble:
- Ίδιο χρώμα bg με το bubble (το bg του quote γίνεται διάφανο, φαίνεται το χρώμα του bubble).
- Ίδιο πλάτος με το bubble (σταματάει το σημερινό mismatch πλάτους).
- Διαχωρισμένο εσωτερικά με **γραμμή (divider)**.
- Στυλ WhatsApp/Telegram: accent bar αριστερά + sender nickname + preview κειμένου (+ thumbnail για media), tab στην κορυφή, tail κάτω.
- Το μακροπάτημα (long-press) στο quote **ξεκινάει το action bar** (σταθερή συμπεριφορά σε ΟΛΑ τα types).

---

## 2. Τι υπάρχει ΣΗΜΕΡΑ (ακριβής χάρτης αρχείων)

### 2.1 `lib/features/chat/widgets/message_bubble/reply_preview.dart` (120 γρ.)
- `ReplyPreview` (γρ. 4-68): **StatelessWidget** — η σημερινή «κάρτα quote».
  - Κατ' αρχάς `ConstrainedBox(maxWidth: maxWidth ?? ∞)` (γρ. 42-43, κάλυμμα από το SPoT bubbleMaxWidth, Session 222).
  - `Container` (γρ. 44-65): bg `surfaceContainerHighest.withAlpha(180)`, border-left `primary` 3px, radius 6, `margin bottom: 6`.
  - Media → `Row[ReplyMediaThumbnail 44px, Flexible(text)]` (Session 213) · αλλιώς μόνο text.
  - Preview κείμενο (γρ. 26-30): group → `@nickname` (media) ή `@nickname: preview` (text) · 1-1 → preview μόνο.
  - Χρώμα text: `onSurfaceVariant` **πάντα** (δεν κοιτάει `isMe`) — γρ. 36.
- `ReplyMediaThumbnail` (γρ. 70-120): 44×44 (`CachedNetworkImage`, ClipRRect 6, placeholder/errorWidget `surfaceContainerHighest.withAlpha(120)`).
  - SPoT `urlFor(replyTo)` (γρ. 82-90): image/gif → `content`, video → `thumbnailUrl`, μόνο media types.

### 2.2 `bubble_long_press_wrapper.dart` (65 γρ.)
- `GestureDetector(onLongPressStart)` → `MessageActionBar.show(...)` → dispatch (reply / reply_private / edit / delete / info / email / share). `canEdit` για media types = false.
- **Anchor (κρίσιμο):** το μενού ΔΕΝ ανοίγει στο σημείο πίεσης. Με βάση το `box = context.findRenderObject()` (το RenderObject του child-subtree): κατακόρυφο **κέντρο** του box + **αριστερή** ακμή (isMe) ή **δεξιά** ακμή (!isMe). `details.globalPosition` = fallback μόνο όταν box null/not-attached. → αναλυτικά στο §3.2.

### 2.3 Τα 5 bubble αρχεία — πού είναι σήμερα το quote

| Αρχείο | ReplyPreview | BubbleLongPressWrapper αγκαλιάζει το quote; | Sent χρώμα | Radius | Tail |
|---|---|---|---|---|---|
| `text_message_bubble.dart` | :221-227 **ΜΕΣΑ** στο wrapper | **ΝΑΙ** (γρ. 204-228: wrapper > Column[quote, Stack]) | `chatBubbleSent` #075E54 · κείμενο white | 20 / tails 8 | :280-289 |
| `gif_image_bubble.dart` | :179-185 **ΕΚΤΟΣ** wrapper | **ΟΧΙ** | `chatBubbleSent` #075E54 | 20 / 8 | :243-252 |
| `audio_message_bubble.dart` | :235-241 **ΕΚΤΟΣ** wrapper | **ΟΧΙ** | `primaryContainer` (ΔΙΑΦΟΡΕΤΙΚΟ!) | 16 / 4 | :314-323 |
| `video_message_bubble.dart` | :245-251 **ΕΚΤΟΣ** wrapper | **ΟΧΙ** | `#075E54` | 16 / 4 | :385-394 |
| `emoji_only_bubble.dart` | :109-115 **ΕΚΤΟΣ** wrapper | **ΟΧΙ** | χωρίς κάρτα (bare) · text `onSurface` και στα 2 (:90-92) | — | — |

### 2.4 `chat_input_bar.dart` (674 γρ.) — ξεχωριστή διαδρομή, ΔΕΝ αγγίζεται
- `_mediaPreview()` (:169-176): localized label preview (audio/gif/image/video/emoji/text-truncated-80) — ο label **αποθηκεύεται** ως `contentPreview` στο replyTo.
- `_buildReplyData()` (:178-210): χτίζει το `replyTo` map `{messageId, senderId, contentPreview, senderNickname, type, content(image/gif), thumbnailUrl(video)}`.
- `_buildReplyBanner()` (:416-486): το πάνω banner στο input — χρησιμοποιεί **δικό του** Container (:437-441) + `ReplyMediaThumbnail` (:449). Ξεχωριστό visual από τα in-bubble quotes.

### 2.5 `chat_messages_list.dart` (1104 γρ.) — ΔΕΝ πειράζεται
- SPoT `bubbleMaxWidth` (:945-948: `w = ResponsiveUtils.resolveWidth(...)`, `bubbleMaxWidth = w * 0.75`).
- fix5 ListView width-cache (:942-1051) + ValueKey(msgId) — τα rebuilds ελέγχονται από το index-based cache. Οποιαδήποτε αλλαγή εδώ = κίνδυνος regression → **κλειδωμένο**.
- `MessageBubble` dispatch (message_bubble.dart) — περνάει `bubbleMaxWidth`, `replyTo` (από `message['replyTo']`), callbacks. **Δεν αλλάζει υπογραφή** → η equality-cache (Session 200/222) μένει άθικτη.

---

## 3. Ευρήματα από τον επανέλεγχο (πώς διορθώνεται η αρχική πρόταση)

### 3.1 ⚠️ `IntrinsicWidth(Column[Quote,Divider,child])` ως SPoT core — ΑΠΟΡΡΙΠΤΕΤΑΙ
- **GIF/Image**: `CachedNetworkImage` χωρίς πλάτος → intrinsic = **ανάλυση εικόνας** → τεράστια widths / αστάθεια. Σήμερα ΔΕΝ έχει IntrinsicWidth.
- **Video**: έχει ήδη `SizedBox(width: bubbleMaxWidth)` → περιττό intrinsic pass.
- **Audio**: `Row` με `Expanded` → intrinsic μη ορισμένο.
- **Σωστή λύση:** πλάτος **ανά τύπο όπως σήμερα** (text: υπάρχον IntrinsicWidth · media: fixed) και το quote μπαίνει **μέσα στο ίδιο Container** ως stretch child (`crossAxisAlignment: stretch` στην εσωτερική Column) → παίρνει **αυτόματα** το πραγματικό πλάτος του bubble, **μηδέν νέα layout passes**, μηδέν νέο intrinsic.

### 3.2 ⚠️ Long-press στο quote — η πραγματική μηχανική (2 ξεχωριστά πράγματα)

**(β) Θέση μενού (anchor) — ΑΝΕΞΑΡΤΗΤΗ από το σημείο πίεσης.**
Στο `bubble_long_press_wrapper.dart:37-46`:
```dart
final box = context.findRenderObject() as RenderBox?;
Offset anchor = details.globalPosition;              // FALLBACK ΜΟΝΟ
if (box != null && box.attached) {
  final topLeft = box.localToGlobal(Offset.zero);
  anchor = Offset(
    isMe ? topLeft.dx : topLeft.dx + box.size.width, // αριστερή ακμή (δικό) / δεξιά ακμή (άλλου)
    topLeft.dy + box.size.height / 2,                // κατακόρυφο ΚΕΝΤΡΟ του box
  );
}
```
- `box` = το RenderObject του **child-subtree** του wrapper (`findRenderObject()` επιστρέφει τον πρώτο render object κάτω από το wrapper, δηλ. το wrapped visual).
- Το μενού εμφανίζεται **πάντα** στο κατακόρυφο κέντρο του `box`, στην **αριστερή ακμή** (δικό μήνυμα) ή **δεξιά ακμή** (μήνυμα άλλου) — **όχι** στο σημείο πίεσης.
- Το `details.globalPosition` χρησιμοποιείται **μόνο ως fallback** όταν `box == null || !box.attached`.

**(α) Πυροδότηση (hit-test) — αυτό ΔΕΝ αλλάζει μόνο του.**
Το `GestureDetector` καλύπτει μόνο το `child` του wrapper:
- **text**: child = `Column[quote, Stack[bubble, tail]]` → το quote **είναι ήδη** μέσα στο long-press σήμερα.
- **gif / audio / video**: child = μόνο το bubble `Container` (quote τυπώνεται ΕΚΤΟΣ wrapper) → πάτημα στο quote **δεν κάνει τίποτα** σήμερα.
- **emoji**: child = `Column[Text, time]`, quote εκτός → ίδιο με τα media.

**Συνέπειες για το merge:**
- Media/emoji: το quote μπαίνει μέσα στο child → (α) γίνεται **πατήσιμο** (behavior change, εσκεμμένο), ΚΑΙ (β) το `box` μεγαλώνει (quote + μήνυμα) → το μενού βγαίνει στο κατακόρυφο κέντρο **ολόκληρης της κάρτας**, ελαφρώς χαμηλότερα από σήμερα (σήμερα = κέντρο μόνο του bubble). Στο text αυτό **ήδη ισχύει** (το box περιλαμβάνει ήδη το quote).
- Η αλλαγή (β) είναι καθαρά **αισθητική** (ίδια λογική με μηνύματα μεγαλύτερου ύψους) — καμία νέα λογική στο wrapper.

### 3.3 ⚠️ Χρώματα μέσα στο quote — κρίσιμο
- Σημερινό `ReplyPreview`: text `onSurfaceVariant` + border `primary` + placeholder `surfaceContainerHighest` — όλα «σκοτεινά πάνω σε ανοιχτό».
- Μετά το merge το quote μπαίνει πάνω σε **σκοτεινά sent χρώματα** (`#075E54`, `chatBubbleSent`, `primaryContainer`) → απαραίτητο **contrast-aware** χρωματισμό από `ThemeData.estimateBrightnessForColor(bubbleColor)` (framework — ΔΕΝ φτιάχνουμε νέο βοηθό, δεν υπάρχει άλλος στο project).
- Το audio sent = `primaryContainer` (διαφορετική απόχρωση) — επιβεβαίωση ότι ο χρωματισμός ΔΕΝ πρέπει να είναι σκληρό `isMe → white` αλλά με βάση τη φωτεινότητα του `bubbleColor`.

### 3.4 ✅ Το `borderRadius` ΔΕΝ αλλάζει καθόλου
- Top corners = `_bubbleRadius` πάντα · bottom = tail-logic. Το «άνω corners από quote» το δίνει το **υπάρχον** radius. Κανένα νέο corner logic.
- Video: σήμερα double-radius (Container :266-274 + ClipRRect ίδιο) — με το quote μέσα στο ClipRRect τα πάνω corners κλιπάρουν σωστά μόνα τους.

### 3.5 ✅ Banner ChatInputBar — ξεχωριστή διαδρομή, μένει ως έχει.

### 3.6 Emoji-only
- `textColor = onSurface` και στα δύο (:90-92). Όταν φτιάξουμε κάρτα **μόνο στην περίπτωση quote**, χρειάζεται προσαρμογή (π.χ. sent → λευκό/κατάλληλο αντίθεσης). Χωρίς quote → bare όπως σήμερα (καμία κάρτα).

### 3.7 ✅ Private Reply (Απάντηση ιδιωτικά — Session 211) — καλύπτεται ΑΥΤΟΜΑΤΑ
- **Flow:** long-press σε group msg → «Απάντηση ιδιωτικά / Reply privately» → `_onReplyPrivately` (`chat_messages_list.dart:556-605`) → `createChat(senderId)` → `pendingPrivateReplyProvider.set(chatId, msg, senderNicknameHint)` → push `/chat/$chatId`.
- **`ChatInputBar.initState`** (`chat_input_bar.dart:67-75`): `consumeFor(chatId)` → προσθέτει `_privateReplySenderNickname` στο quoted msg → `setReply`.
- **`_buildReplyData`** (`:195-199`): το `replyTo` που αποθηκεύεται στο Firestore έχει `senderNickname` (hint / nickname 1-to-1 / uid).
- **Rendering:** το αποθηκευμένο `replyTo` είναι συνηθισμένο map σε φυσιολογικό μήνυμα → ίδιο `MessageBubble` → με το merge θα render-άρει **αυτόματα** μέσω του νέου `BubbleQuoteSection`, **χωρίς καμία ειδική μεταχείριση**. Δεν υπάρχει ξεχωριστό render path για private replies.
- **Caveat (υπάρχουσα συμπεριφορά, ΔΕΝ την αλλάζω):** ο quote εμφανίζεται σε 1-to-1 (`isGroupChat=false`) → σήμερα **ΔΕΝ δείχνει** `@nickname` (gate `reply_preview.dart:27-30` = `isGroupChat`). Το `_privateReplySenderNickname` χρησιμοποιείται μόνο στο banner του input (`:433`). Αν θέλουμε «@Name» και στο 1-to-1 (Telegram-style), είναι **ξεχωριστή απόφαση**, εκτός scope του merge.
- **Rebuild:** το `pendingPrivateReplyProvider` (chat_provider.dart:780) είναι send-time μόνο (input) — ποτέ render-time → μηδέν επίδραση στη λίστα.

### 3.8 🔴 ΚΡΙΣΙΜΟ: `crossAxisAlignment: stretch` σπάει το hug-content πλάτος του text bubble
- **Πρόβλημα:** Όταν ένα `Column` έχει `crossAxisAlignment: stretch` και ο γονιός δίνει loose constraint με πεπερασμένο maxWidth (`Container(constraints: BoxConstraints(maxWidth: bubbleMaxWidth))`), το Column **δεν** υπολογίζει πλάτος από τα παιδιά — παίρνει tight πλάτος = `bubbleMaxWidth` και το περνάει **tight σε ΟΛΑ τα παιδιά**, συμπ. του `IntrinsicWidth`.
- Το `IntrinsicWidth` με tight constraint κάνει `constraints.constrain()` → επιστρέφει το fixed max → **εξαφανίζεται το hug-content**: ένα σκέτο «Ναι» θα γέμιζε 75% της οθόνης = το ακριβές bug του Session 203. Το πρόβλημα προέρχεται από την ύπαρξη του `stretch` στο outer Column — όχι από τα παιδιά του.
- **Γιατί media δεν επηρεάζονται:** gif/audio/video ήδη γεμίζουν όλο το `bubbleMaxWidth` (fixed-size image / Expanded Row / AspectRatio) — δεν έχουν shrink-to-fit συμπεριφορά να χαθεί.
- **Διόρθωση (ΜΟΝΟ text + emoji-card):** το `IntrinsicWidth` τυλίγει **ολόκληρο** το outer Column (`Quote + Divider + Content`) και όχι μόνο το content:
  - Χωρίς quote: `IntrinsicWidth(Column[content])` — **ακριβώς όπως σήμερα**, μηδέν αλλαγή.
  - Με quote: `IntrinsicWidth(Column(stretch)[QuoteSection, Divider, content])` — το intrinsic pass (max quote/content intrinsic) αποφασίζει το πλάτος ΕΞΩ από το stretch, και το stretch μέσα απλώς κάνει το quote να γεμίσει ΑΥΤΟ το πλάτος (όχι το πλήρες maxWidth).
- **Δεν παραβιάζει τον κανόνα §3.1:** αφορά μόνο text (και emoji-card), όπου content = `Text`/`Text.rich` με καλά ορισμένο intrinsic — όχι εικόνα χωρίς explicit width. Τα media παραμένουν χωρίς IntrinsicWidth.

---

## 4. Σχεδιασμός — Υλοποίηση

### 4.1 Νέο shared widget: `BubbleQuoteSection` (ΣΤΟ `reply_preview.dart`, ΟΧΙ νέο αρχείο)
```dart
class BubbleQuoteSection extends StatelessWidget {
  final Map<String, dynamic>? replyTo;
  final Color bubbleColor;      // για contrast-derived χρώματα
  final bool isGroupChat;
  final double? thumbnailSizeAtBubble; // όχι απαραίτητο — προεπιλογή 44

  const BubbleQuoteSection({...});

  @override
  Widget build(BuildContext context) {
    // Αν replyTo == null → return const SizedBox.shrink();
    // Διαφορετικά: Column(mainAxisSize: min) [ ReplyStrip(flattened), Divider ]
  }
}
```
- **Flatten του quote:** ΚΑΝΕΝΑ δικό bg / radius / margin. Μένει μόνο:
  - `border-left: accent 3px` (accent = π.χ. `primary` σε ανοιχτό / `white.withAlpha(180)` σε σκοτεινό).
  - Content: `Row[ReplyMediaThumbnail (reuse, με contrast placeholder), Flexible(Column[sender bold?, preview 2 γρ. ellipsis])]` ή μόνο text.
  - Text/sender χρώματα από `ThemeData.estimateBrightnessForColor(bubbleColor)`.
  - Το preview κείμενο: επαναχρησιμοποιεί την υπάρχουσα λογική `@nickname` (group) / preview (γρ. 26-30 του reply_preview) — χωρίς νέα l10n, το `contentPreview` είναι ήδη localized στο send-time.
- `Divider`: ύψος 1px, χρώμα contrast (π.χ. `white.withAlpha(60)` στο sent / `onSurfaceVariant.withAlpha(60)` στο recv).
- Το `ReplyPreview` (card) **παραμένει** ως έχει αν χρειαστεί σε κάποιο αλλού; — έλεγχος: μετά τη μετατροπή ΔΕΝ υπάρχει άλλο in-bubble σημείο που να το θέλει. **Αν δεν χρησιμοποιείται πλέον πουθενά, αφαιρείται** (η `ReplyMediaThumbnail` μένει για το banner του input).

### 4.2 Ανά bubble — επεμβάσεις

Κανόνας (**ρητός διαχωρισμός stretch — ισχύει ΠΑΝΤΑ, με ή χωρίς quote**):

- **text & emoji-card (content-hugging):**
  `Container(maxWidth, padding, decoration) > IntrinsicWidth(Column(mainAxisSize: min, crossAxisAlignment: stretch)[QuoteSection?, Divider?, content+time])`
  - Το `crossAxisAlignment: stretch` μπαίνει **ΠΑΝΤΑ μέσα στο `IntrinsicWidth`** — το intrinsic pass αποφασίζει το πλάτος, το stretch απλώς γεμίζει το quote σε ΑΥΤΟ το πλάτος (όχι στο full maxWidth). Βλ. §3.8.
  - Χωρίς quote → `IntrinsicWidth(Column(stretch)[content])` = μοναδικό child → stretch void → **ακριβώς η σημερινή δομή**, μηδέν αλλαγή. Ναι, το `stretch` παραμένει στον κώδικα και χωρίς quote — είναι ασφαλές γιατί είναι εντός IntrinsicWidth.
- **media (gif/audio/video) (fixed-width):**
  `Container(fixed constraints) > Column(mainAxisSize: min, crossAxisAlignment: stretch)[QuoteSection?, Divider?, content]`
  - **Χωρίς `IntrinsicWidth`** — τα media ήδη γεμίζουν το πλάτος (fixed image / Expanded Row / AspectRatio), δεν υπάρχει hug-content να χαθεί → stretch μόνο του, κανένας κίνδυνος.
- Το `Divider` μπαίνει **μόνο όταν υπάρχει quote**. `bubbleMaxWidth`/radius/tail/χρώματα ΜΕΝΟΥΝ όπως σήμερα.

> ⚠️ **ΠΡΟΣΟΧΗ στο emoji:** η κάρτα emoji+quote είναι **content-hugging** (υπάρχει μόνο με quote) — αν έμπαινε σε plain `Column(stretch)` με `Container(maxWidth)`, το «😂» + κοντό quote θα έκανε κάρτα πλάτους maxWidth (Session-203 σε κάρτα). Γι' αυτό ακολουθεί το **text pattern**: `IntrinsicWidth(Column(stretch))`. ΜΟΝΟ τα media (gif/audio/video) είναι exempt χωρίς wrapper.

| Bubble | Νέο εσωτερικό | Σημειώσεις |
|---|---|---|
| **text** `:231-289` | `Container(maxWidth, padding, decoration) > IntrinsicWidth(Column(stretch)[QuoteSection?, Divider?, content+time])` | Το `IntrinsicWidth` τυλίγει ΟΛΟ το outer Column (βλ. §3.8). No-quote → `IntrinsicWidth(Column[content+time])` = σημερινή δομή, μηδέν αλλαγή. Το content μένει plain `Column(crossAxisAlignment: end, [text, time])` (όχι δεύτερο IntrinsicWidth). **Πρέπει να επαληθευτεί με BUBBLE_W (no-quote και quote).** |
| **gif/image** `:202-240` | `Container(maxWidth, maxHeight 200, clip) > Column(stretch)[QuoteSection?, Divider?, CachedNetworkImage]` | **ΧΩΡΙΣ IntrinsicWidth** (media-exempt, §4.2) · no-quote: Column[image] ≡ σημερινό Container[image] (ίδια constraints) · quote: εικόνα μικραίνει (WhatsApp-style). Καμία αλλαγή hug-width (fixed). |
| **audio** `:256-312` | `Container > Column(stretch)[QuoteSection?, Divider?, Row(play/progress/time)]` | **ΧΩΡΙΣ IntrinsicWidth** (media-exempt) · Row ήδη fills maxWidth → ίδιο αποτέλεσμα |
| **video** `:266-382` | `Container > Column(stretch)[QuoteSection?, Divider?, ClipRRect(Column[GestureDetector(AspectRatio...)])]` | **ΧΩΡΙΣ IntrinsicWidth** (media-exempt) · ή το QuoteSection μέσα στο ίδιο το ClipRRect-Column · fixed width |
| **emoji** `:109-115` | Μόνο αν `replyTo != null`: `Container(bubbleColor, radius) > IntrinsicWidth(Column(stretch)[QuoteSection, Divider, emoji+time])` + tail | Ίδιος κανόνας με text: stretch **ΠΑΝΤΑ εντός** `IntrinsicWidth` (βλ. warning §4.2 + §3.8). Χωρίς quote → bare όπως σήμερα |

**Long-press:** Η ανατομία (wrapper) ΔΕΝ αλλάζει — αφού το quote γίνει child του ίδιου Container που είναι child του wrapper, το media/emoji quote μπαίνει αυτόματα μέσα στο hit-test του long-press (αλλαγή για media/emoji· text το έχει ήδη). Το **anchor του μενού** συνεχίζει να υπολογίζεται όπως σήμερα (κατακόρυφο κέντρο του child-subtree, αριστερή/δεξιά ακμή) — μόνο που το box γίνεται ψηλότερο (quote + μήνυμα) → το μενού εμφανίζεται στο κέντρο **ολόκληρης της κάρτας** (ελαφρώς χαμηλότερα, καθαρά αισθητικό). Καμία αλλαγή κώδικα στο wrapper.

### 4.3 Αλλαγές αρχείων (συνοπτικά)
1. `lib/features/chat/widgets/message_bubble/reply_preview.dart` — flatten + `BubbleQuoteSection` + contrast colors.
2. `lib/features/chat/widgets/message_bubble/text_message_bubble.dart`
3. `lib/features/chat/widgets/message_bubble/gif_image_bubble.dart`
4. `lib/features/chat/widgets/message_bubble/audio_message_bubble.dart`
5. `lib/features/chat/widgets/message_bubble/video_message_bubble.dart`
6. `lib/features/chat/widgets/emoji_only_bubble.dart`

ΔΕΝ αλλάζει: `chat_messages_list.dart`, `message_bubble.dart`, `chat_input_bar.dart`, `bubble_long_press_wrapper.dart`.

---

## 5. Φάσεις (1 βήμα → 1 backup → 1 `flutter analyze` → έλεγχος από εσένα)

1. **Φάση 1 — SPoT QuoteSection** `reply_preview.dart`: flatten + contrast + `BubbleQuoteSection` (χωρίς ακόμα αλλαγές στα bubbles — το νέο widget υπάρχει, τα bubbles συνεχίζουν με το `ReplyPreview`).
2. **Φάση 2 — Text (pilot):** ενσωμάτωση + **BUBBLE_W anti-regression** (no-quote πλάτος) + quote σε text/gif/photo/video/audio sent & recv.
3. **Φάση 3 — GIF/Image** · 4. **Audio** · 5. **Video** · 6. **Emoji** (μόνο όταν reply).
7. **Φάση 7 — Regression:** forward, reactions, delete, edit (text), gallery tap, video play, audio play — στα ίδια μηνύματα.

### Backup naming (βλ. backups/)
`backups/reply_quote_<phase>_<yyyyMMdd_HHmmss>/` (ή `.bak` single-file, όπως στα προηγούμενα sessions).

---

## 6. Edge cases & θωράκιση

- **Group + nickname:** quote δείχνει `@Name` — διατηρείται (λογική reply_preview :26-30, μεταφερμένη στο strip).
- **Αποτυχία thumbnail:** fallback 44px errorWidget (ήδη υπάρχει, μένει).
- **Emoji-only quote:** δείχνει το emoji ως preview — ίδια λογική `_mediaPreview` (`isEmoji → content.trim()`).
- **Dark mode / sent χρώματα:** contrast-aware χρώματα ΑΠΟ τo `bubbleColor` (όχι σκληρό isMe→white) — καλύπτει chatBubbleSent / primaryContainer / #075E54.
- **Πλάτος:** text/emoji → `IntrinsicWidth` γύρω από **ολόκληρο** το outer Column (`Quote + Divider + Content`, βλ. §3.8) · media → fixed. Το quote stretch-άρεται στο πλάτος του bubble — ΔΕΝ ξεφεύγει πια. **ΠΟΤΕ IntrinsicWidth γύρω από media.**
- **i18n:** το `contentPreview` αποθηκεύεται localized κατά τον αποστολέα — **γνωστός περιορισμός**, ΔΕΝ αλλάζει σε αυτό το fix.
- **Διαγραμμένο quoted msg:** κενό `contentPreview` → quote δείχνει μόνο sender/divider. Αν το content είναι κενό, το strip πρέπει να έχει min-height ώστε να μη «εξαφανίζεται» — μικρή λεπτομέρεια στο strip layout.
- **Private reply (1-to-1):** renders κανονικά από το νέο `BubbleQuoteSection` (ίδιο path). `isGroupChat=false` → χωρίς `@nickname` (υπάρχουσα συμπεριφορά, εκτός scope) — βλ. §3.7.
- **Rebuilds:** πριν/μετά με `MSG_LIST` + `BUBBLE_W` logs στο ίδιο reply σενάριο.

---

## 7. Rebuild-storm guard (μητρικοί κανόνες — Sessions 221-224)

1. **ΠΟΤΕ** `MediaQuery.*` / `L10n.isGreek(context)` / `Localizations` μέσα σε `build()` των bubble/quote widgets. Μόνο `Theme.of` (δεν επηρεάζεται από keyboard).
2. **ΠΟΤΕ** νέο `IntrinsicWidth` γύρω από media (κόστος + αστάθεια intrinsic εικόνας). Επιτρέπεται ΜΟΝΟ στο text/emoji: `IntrinsicWidth(Column(stretch)[Quote, Divider, Content])` — το intrinsic pass έξω από το stretch (βλ. §3.8).
3. **ΠΟΤΕ** αλλαγή στην υπογραφή του `MessageBubble` / στο `chat_messages_list` itemBuilder (θα σπάσει την equality-cache & το fix5 ListView-reuse).
4. Νέα widgets: **Stateless**, χωρίς state, providers, listeners, streams.
5. Το `crossAxisAlignment: stretch` μέσα σε ήδη-ταιριασμένο Container = μηδέν νέοι layout passes — η μόνη επιτρεπτή προσθήκη στην κάρτα.

---

## 8. Ορισμοί επιτυχίας (DoD)

- `flutter analyze` clean (0 issues) — επαλήθευση σε **κάθε** φάση.
- Μία κάρτα: quote και message με **ίδιο bg** και **ίδιο πλάτος**, διαχωρισμένα με divider.
- Long-press στο quote ανοίγει action bar σε ΟΛΑ τα types (media/emoji — νέα συμπεριφορά hit-test· text ήδη). Η θέση του μενού παραμένει η σημερινή λογική (κατακόρυφο κέντρο της κάρτας, αριστερή/δεξιά ακμή).
- Sent & recv colors σωστά σε όλα τα types (text/gif/image/audio/video/emoji).
- Χωρίς quote → τα bubbles δείχνουν **ακριβώς όπως σήμερα** (πλάτος, χρώματα, tail, corner). **Κρίσιμο:** text no-quote → `BUBBLE_W` = hug-content (π.χ. «Ναι» ≈ μικρό, ΟΧΙ `bubbleMaxWidth`) — anti-§3.8/203.
- Καμία νέα rebuild storm (logs `MSG_LIST`/`BUBBLE_W` ίδια ή καλύτερα από πριν).
- Regression: forward, reactions, delete, edit-text, gallery, video play, audio play.