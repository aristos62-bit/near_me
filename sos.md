# NearMe — Επείγουσα Βοήθεια (SOS / Help Request)

> **Κατάσταση:** Πρόταση v2 — υπό έλεγχο από τον χρήστη. ΔΕΝ έχει ξεκινήσει καμία αλλαγή κώδικα.
> **Ημερομηνία:** 14 Αυγούστου 2026
> **Βάση:** Κώδικας τελευταίας έκδοσης (Flutter 3.44.4), oldsessions.md (Κεφάλαιο 10 — rebuild storms, Sessions 215-233), firestore_cost_optimization.md

---

## 1. Υπηρεσία

**Σκοπός:** Όταν ένας χρήστης βρίσκεται σε ανάγκη (σοβαρό περιστατικό ή επείγουσα εξυπηρέτηση), ενεργοποιεί το SOS και οι **γύρω του** στο Discovery τον βλέπουν άμεσα: κόκκινη κάρτα, πρώτη στη σειρά, με σύντομο μήνυμα για το τι συμβαίνει.

**Δύο ρόλοι:**

| Ρόλος | Τι κάνει |
|---|---|
| **Αιτών** (requester) | Ενεργοποιεί/απενεργοποιεί το SOS από την Ανακάλυψη, επιλέγει απόσταση (radius) και γράφει σύντομο μήνυμα |
| **Βοηθός** (helper) | Βλέπει τις κόκκινες κάρτες πρώτες στη λίστα αποτελεσμάτων, με το μήνυμα του αιτούντος |

**Βασική αρχή:** Είναι **προσωρινή, επείγουσα κατάσταση** — ξεχωριστή από τον σταθερό σκοπό προφίλ (`lookingFor`). Ενεργό μόνο όσο το χρειάζεσαι, με αυτόματο τερματισμό μετά από 60 λεπτά.

---

## 2. Αποφάσεις (εγκεκριμένες από τον χρήστη)

| # | Απόφαση | Λεπτομέρεια |
|---|---------|-------------|
| 1 | **Ποιος μπορεί να ζητήσει** | Όλα: `canUserCommunicate` (verified) + `isPublished` + γεωεντοπισμός (lat/lng) + **τουλάχιστον ένα** ανοιχτό κανάλι (`allowDirectChat` ή `showEmail` ή `showPhone` ή `allowVideoCall`) |
| 2 | **Αποθήκευση** | Στο ίδιο `users/{uid}/public/profile` (πεδίο `helpRequest`) — χωρίς νέο collection/query/index |
| 3 | **Τερματισμός** | Χειροκίνητο **και** αυτόματο TTL **60 λεπτά** |
| 4 | **Απόσταση** | Την επιλέγει ο **αιτών** (radiusKm) — μόνο όσοι είναι εντός του βλέπουν κόκκινη κάρτα |
| 5 | **Μήνυμα** | Σύντομο κείμενο (max 80 chars) που εμφανίζεται στην κόκκινη κάρτα |
| 6 | **Εικονίδιο** | `assets/icons/sos2.webp` (ήδη υπάρχει, ήδη στο pubspec assets) — στην AppBar της Ανακάλυψης δίπλα στο GpsStrengthIndicator |
| 7 | **Σκοπός `help`** | Μένει, **μόνο μετονομασία label** σε «Υποστήριξη» (το key `'help'` παραμένει) |
| 8 | **Feature flag** | `FeatureFlags.helpRequestEnabled = true` |
| 9 | **Priority** | Σταθερό partition (help-request πρώτοι) στο provider state — όχι στο grid |

---

## 3. Επανέλεγχος — Λειτουργίες που ΗΔΗ υπάρχουν (REUSE)

| Ανάγκη | Ήδη υπάρχει | Πού |
|---|---|---|
| Έλεγχος «γύρω του» | `state.distances` map (Haversine + cache, Session 156) | search_provider.dart:83-105 |
| Radius έλεγχος βοηθού | `_passesFilters` radius filter | firestore_search_repository.dart:444-458 |
| Verification check | `AuthRepository.canUserCommunicate` | auth_repository.dart:9-18 |
| Offline guard | `ConnectivityGuard` / `_checkOnline` | Session 203 |
| Bilingual errors | `ErrorMessages.get(code, isGreek)` + `L10n.localizedMessage` | error_messages.dart |
| Dialogs/snackbars | `AppMessenger` (showConfirmDialog, showError κ.λπ.) | app_messenger.dart |
| Responsive | `ResponsiveUtils` + `EditorScaffold` pattern (no MediaQuery σε build) | Session 208 |
| Owner write σε δικό του public doc | update rule επιτρέπει νέο πεδίο (περιορισμός μόνο geoHash, age≥18) | firestore.rules:94-99 |
| Distance για την κάρτα | `ProfileCard` ήδη λαμβάνει `distanceKm` | profile_card.dart:13 |
| Asset | `assets/icons/sos2.webp` υπάρχει + `- assets/icons/` στο pubspec | pubspec.yaml:97 |

**Συμπέρασμα:** Δεν χρειάζεται νέο collection, νέο query, νέο index, Cloud Function, ή package. Όλη η λογική είναι client-side με δεδομένα που ήδη υπάρχουν (`distances` + `helpRequest` στο public doc).

---

## 4. Μοντέλο δεδομένων

### 4.1 Νέο freezed class

```dart
// lib/shared/models/public_profile.dart — νέο nested class
@freezed
abstract class HelpRequest with _$HelpRequest {
  const factory HelpRequest({
    @Default(false) bool active,
    String? message,           // max 80 chars
    @Default(10.0) double radiusKm,
    required DateTime updatedAt,
  }) = _HelpRequest;

  factory HelpRequest.fromJson(Map<String, dynamic> json) =>
      _$HelpRequestFromJson(json);
}
```

### 4.2 Νέο πεδίο στο PublicProfile

```dart
HelpRequest? helpRequest,   // nested object στο public doc
```

> **Μετά από αυτή την αλλαγή:** `dart run build_runner build --delete-conflicting-outputs`

### 4.3 Document shape στο Firestore

```
users/{uid}/public/profile
├── ... (υπάρχοντα πεδία: nickname, age, city, geoHash, lookingFor κ.λπ.)
└── helpRequest: {
      active: true,
      message: "Χρειάζομαι μεταφορά, είμαι στο κέντρο",
      radiusKm: 10.0,
      updatedAt: <Timestamp>
    }
```

**Δεν χρειάζεται νέο geoHash μέσα στο helpRequest** — για τον υπολογισμό απόστασης χρησιμοποιείται το υπάρχον `geoHash` του public doc.

---

## 5. Ροή — Αιτών (ποιος ζητά βοήθεια)

### 5.1 Είσοδος

`IconButton` στην AppBar της Ανακάλυψης (discovery_screen.dart:270-286), δίπλα στο `GpsStrengthIndicator`:

- `Image.asset('assets/icons/sos2.webp', width: 28, height: 28)` — με elevation/shadow για 3D look
- **Αν το SOS είναι ενεργό** → κόκκινο ring/ρίνγκ γύρω από το εικονίδιο (active state)
- Tooltip: «Επείγουσα Βοήθεια / Emergency Help» (bilingual)
- Guard: `FeatureFlags.helpRequestEnabled`

### 5.2 Bottom sheet (αντικατάσταση Activation UI)

`showModalBottomSheet` — responsive (ResponsiveUtils), SafeArea, `MediaQuery.viewInsetsOf` για keyboard (πρότυπο AppMessenger:35). **Event-driven — καμία MediaQuery dependency σε build.**

**Βήμα 1 — Eligibility check (SPoT util `help_request_config.dart`):**

```dart
// Ψευδο-λογική — όλες οι πηγές είναι πραγματικές:
bool canRequestHelp({
  required bool canComm,        // AuthRepository.canUserCommunicate(user)
  required bool isPublished,    // profile.isPublished (Drift)
  required bool hasGps,         // profile.latitudeExact != null
  required bool hasChannel,     // βλ. παρακάτω — από PublicProfile, ΟΧΙ local toggles
}) { ... }
```

**⚠️ Πηγή του `hasChannel` (Εύρημα #3):** πρέπει να διαβάζεται από το **ήδη δημοσιευμένο** `PublicProfile` μέσω `publicProfileStreamProvider(uid)` (profile_provider.dart:26) — δηλαδή από τα 4 πεδία που βλέπουν πραγματικά οι βοηθοί:

```dart
bool hasChannel(PublicProfile? pub) =>
    pub?.allowDirectChat == true ||
    pub?.allowVideoCall == true ||
    (pub?.email != null && pub!.email!.isNotEmpty) ||
    (pub?.phone != null && pub!.phone!.isNotEmpty);
```

**Γιατί ΟΧΙ τα local privacy toggles:** το `PublicProfile` έχει `allowDirectChat`/`allowVideoCall` ως δικά του πεδία, αλλά **δεν έχει** `showEmail`/`showPhone` — αυτά είναι local Drift τιμές (privacy_settings_table.dart) που γίνονται `email`/`phone` (nullable string) **μόνο τη στιγμή του `publish()`** (profile_repository_impl.dart:339-340). Αν διαβάσουμε τα local toggles, μπορεί να επιτρέψουμε SOS ενώ το δημοσιευμένο προφίλ δεν έχει ακόμα το κανάλι ορατό (stale state: toggle άλλαξε, publish δεν έγινε). Διαβάζοντας το `publicProfileStreamProvider` συμφωνούμε 100% με ό,τι βλέπουν οι βοηθοί.

Αν λείπει κάτι → λίστα **«Τι χρειάζεται για να ζητήσεις βοήθεια»** με κουμπί διόρθωσης (Verify / Publish / GPS / Άνοιξε κανάλι).

**Βήμα 2 — Settings (αν OK):**
- Radius selector: **5 / 10 / 25 / 50 km**
- Message field: maxLength 80 + counter
- Κουμπί «Ενεργοποίηση»

**Βήμα 3 — Write:**

```dart
await _firestore
    .collection('users').doc(uid).collection('public').doc('profile')
    .update({
  'helpRequest': {
    'active': true,
    'message': msg,
    'radiusKm': radius,
    'updatedAt': DateTime.now().toIso8601String(),   // ← ISO8601 string, ΟΧΙ serverTimestamp
  }
});
```

**⚠️ Γιατί `toIso8601String()` και ΟΧΙ `FieldValue.serverTimestamp()` (Εύρημα #1):**
Το `updatedAt` του `PublicProfile` (και συνεπώς του `HelpRequest`) **δεν αποθηκεύεται ως Firestore Timestamp** — το generated `public_profile.g.dart` διαβάζει/γράφει ISO8601 string (γραμμές 38-40, 66):
```dart
updatedAt: json['updatedAt'] == null
    ? null
    : DateTime.parse(json['updatedAt'] as String),   // περιμένει String, ΟΧΙ Timestamp
...
'updatedAt': instance.updatedAt?.toIso8601String(),
```
Αν γράψουμε `FieldValue.serverTimestamp()`, το `HelpRequest.fromJson()` (ίδιο pattern, `DateTime.parse(json['updatedAt'] as String)`) θα δεχτεί **Timestamp object → type-cast exception**. Χειρότερα: το `fromJson` καλείται **χωρίς try/catch ανά έγγραφο** μέσα στο loop του `firestore_search_repository.dart:127-135` (`all.add(PublicProfile.fromJson(data))`) — ένα μόνο SOS-προφίλ θα έριχνε ΟΛΗ την αναζήτηση κάθε βοηθού (το μόνο εξωτερικό try/catch είναι γύρω από όλη τη function, :356). Το `toIso8601String()` είναι συνεπές με το parent `updatedAt` και με το client-side TTL (§5.4, όχι server-driven).

- **1 write** · owner · rules OK (καμία αλλαγή rules)
- Δεν τρέχει το `publish()` — στοχευμένο update μόνο στο `helpRequest`

### 5.3 Απενεργοποίηση

- Ίδιο κουμπί → αν ενεργό → `update({'helpRequest.active': false})` (ή `delete('helpRequest')`)
- Confirm dialog μέσω AppMessenger

### 5.4 Αυτόματο TTL (60 λεπτά)

- **Χωρίς Dart timers** (background-unsafe, Session 152 μάθημα)
- Στο άνοιγμα της Discovery: αν το **δικό σου** `helpRequest.updatedAt < now - 60min` → αυτόματο off (1 write) + ενημέρωση UI
- Οι βοηθοί αγνοούν flags με `updatedAt` εκτός TTL (βλ. §6)
- **Σύγκριση:** αφού το `updatedAt` είναι ISO8601 string, πάντα `DateTime.parse(h.updatedAt)` → σύγκριση ως `DateTime` (ποτέ string comparison)

---

## 6. Ροή — Βοηθός (όσοι βλέπουν)

### 6.1 Priority partition (στο provider)

Στο `SearchNotifier` — **μετά το fetch, πριν το set state** — και στα δύο: `search()` και στο τέλος του `loadMore()` (μετά το append, search_provider.dart:278):

```dart
List<PublicProfile> _prioritizeHelpRequests(List<PublicProfile> results) {
  final now = DateTime.now();
  final urgent = <PublicProfile>[];
  final rest = <PublicProfile>[];
  for (final p in results) {
    final h = p.helpRequest;
    final dist = state.distances[p.uid];          // ήδη υπολογισμένο
    final isUrgent = h != null && h.active
        && h.updatedAt != null
        && now.difference(h.updatedAt.toLocal()) <= ttl  // 60 min
        && dist != null && dist <= h.radiusKm;
    (isUrgent ? urgent : rest).add(p);
  }
  return [...urgent, ...rest];                    // stable partition
}
```

- Οι urgent πρώτοι, οι υπόλοιποι στην τωρινή σειρά (geoHash/__name__ — ίδια με σήμερα)
- **Cursor/σελιδοποίηση άθικτα** (partition δεν αλλάζει το cursor)
- Κανένα νέο `where` στο query → κανένα νέο index, ίδιο κόστος reads

### 6.2 Κόκκινη κάρτα (ProfileCard)

Η `ProfileCard` **ήδη** έχει `profile` και `distanceKm` — **καμία αλλαγή υπογραφής**:

- Αν `helpRequest.active && updatedAt εντός 60min && distanceKm <= radiusKm`:
  - Κόκκινο border / background tint (theme.colorScheme.error)
  - Ετικέτα «Χρειάζεται βοήθεια»
  - Το `message` (1-2 γραμμές, ellipsis)
- Pure read-only logic — καμία νέα reactive dependency → μηδέν rebuild storm

---

## 7. SPoTs / i18n / Errors / Debug

### 7.1 L10n (l10n.dart)

Νέα ομάδα labels (bilingual μέσω `isGreek`):
- «Επείγουσα Βοήθεια» / «Emergency Help»
- «Χρειάζεται βοήθεια» / «Needs help»
- «Απόσταση» / «Distance»
- «Μήνυμα» / «Message»
- «Ενεργοποίηση» / «Activate» · «Απενεργοποίηση» / «Deactivate»
- «Τι χρειάζεται για να ζητήσεις βοήθεια» / «What you need to request help»
- Μετονομασία `'help'` label: «Βοήθεια» → «Υποστήριξη» / «Help» → «Support» — σε **2 σημεία**:
  - `l10n.dart:110/120` (SPoT — καλύπτει profile_card:151 και profile_screen:157)
  - `profile_editor_screen.dart:73` (chip label)
  - Το **key `'help'` δεν αλλάζει** → συμβατότητα με παλιά δεδομένα

### 7.2 ErrorMessages (error_messages.dart)

Νέες codes:
- `help/not-verified` — «Πρέπει να επαληθεύσεις τον λογαριασμό σου»
- `help/not-published` — «Πρέπει να δημοσιεύσεις το προφίλ σου»
- `help/no-gps` — «Χρειάζεται τοποθεσία GPS»
- `help/no-channel` — «Άνοιξε τουλάχιστον ένα κανάλι επικοινωνίας»
- `help/activate-failed` / `help/deactivate-failed`
- `help/message-too-long` (guard — σπάνια χρειάζεται λόγω maxLength)
- `help/expired` — «Το αίτημα βοήθειας έληξε»

### 7.3 DebugConfig (debug_config.dart)

- Νέο flag: `static const bool helpRequest = true;`
- Logs σε: `repositoryCall/Result`, `firestoreWrite`, `uiInteraction`, `authGuard`, `helpRequest`

### 7.4 FeatureFlags (feature_flags.dart)

- `static const bool helpRequestEnabled = true;`

---

## 8. Προαπαιτούμενα / μπλοκαρίσματα (πριν την εφαρμογή)

1. **Backup** κάθε αρχείου που θα αγγίξω στο `backups/` (κανόνας AGENTS)
2. `dart run build_runner build --delete-conflicting-outputs` (freezed `HelpRequest`)
3. `flutter analyze` μετά από κάθε βήμα
4. Firestore rules / indexes / Cloud Functions: **καμία αλλαγή**
5. Χωρίς νέο package dependency

---

## 9. Edge cases & side effects

| Σενάριο | Συμπεριφορά / μέτρο |
|---|---|
| **publish() ξαναγράφει το doc** | **ΚΡΙΣΙΜΟ (Εύρημα #2):** αν ενεργό SOS, το `publish()` κάνει `.set()` πλήρη αντικατάσταση → θα σβήσει το `helpRequest`. **Πρέπει να μπει στο preserve idiom** (όπως isOnline/geoHash, profile_repository_impl.dart:369-392). **Το `publish()` καλείται από 4 σημεία** — όχι μόνο από edit profile/avatar:
  - `discovery_screen.dart:145` ← **auto-publish κατά το GPS sync (silent, background!)** — το πιο επικίνδυνο: τρέχει αυτόματα κάθε φορά που αλλάζει η τοποθεσία ενώ ο χρήστης κάθεται στο Discovery με ενεργό SOS, όχι μόνο σε manual edit
  - `privacy_editor_screen.dart:99`
  - `profile_screen.dart:283`
  - `profile_editor_screen.dart:450`
  - Αφού είναι όλα το **ίδιο** `publish()`, η διόρθωση σε **ένα σημείο** (το preserve στο `publish()`) καλύπτει και τα 4 — αλλά το κείμενο πρέπει να αναφέρει ρητά τη συχνότητα του silent auto-publish από GPS |
| unpublish | doc deleted → SOS εξαφανίζεται (σωστό) |
| Stale flag (εφαρμογή κλειστή 60+ min) | Βοηθοί τον αγνοούν (TTL στο search)· αιτών → auto-off στο άνοιγμα |
| Blocked users | `_excludeBlocked` ήδη τρέχει (search_provider:70) — η επείγουσα ανάγκη δεν προσπερνά block |
| Χωρίς GPS ο βοηθός | `distances` κενό → κανένα urgent (σωστό: χωρίς τοποθεσία δεν υπάρχει «γύρω») |
| Αιτών εκτός radius βοηθού | Δεν εμφανίζεται καν (υπάρχον radius filter στο search) |
| Χειροκίνητη πόλη χωρίς lat/lng | Δεν πληρεί γεωεντοπισμό → καθοδήγηση GPS |
| Ανώνυμος / unverified | `canUserCommunicate=false` → καθοδήγηση επαλήθευσης |
| Keyboard στο sheet | viewInsets + responsive (πρότυπο AppMessenger) |
| App backgrounded στο TTL | χωρίς timers — έλεγχος με `updatedAt` ανά search/άνοιγμα |
| Firestore κόστος | 1 write ανά activation, ~100 bytes — αμελητέο |
| `updatedAt` null (legacy doc) | Guard: αν null → μη-urgent (fail-safe) |

### 9.1 Προαιρετικό (Εύρημα #4) — try/catch ανά έγγραφο στο Firestore search

**Προϋπάρχον ρίσκο, ανεξάρτητο του SOS** — αλλά το SOS το ενεργοποιεί πρώτη φορά στην πράξη:

- Στο `firestore_search_repository.dart:127-135`, το `PublicProfile.fromJson(data)` καλείται **χωρίς try/catch ανά έγγραφο** μέσα στο loop. Ένα μόνο κατεστραμμένο/malformed doc ρίχνει ΟΛΗ την αναζήτηση (το εξωτερικό try/catch είναι μόνο γύρω από όλη τη function, :356).
- **Πρόταση:** περιτύλιξη κάθε `fromJson` σε try/catch → αν αποτύχει ένα doc, skip + log `warn` (όχι crash όλου του search).
- **Χαμηλού ρίσκου, προαιρετικό** — επηρεάζει τo αίτημα μόνο αν ο χρήστης το εγκρίνει.

---

## 10. Rebuild storm (Κεφάλαιο 10 — νέος έλεγχος)

- **0 νέο `MediaQuery` σε build** — το sheet χρησιμοποιεί viewInsets event-driven (όχι dependency). Κανόνας Session 221/224
- **0 νέο `Localizations.localeOf` σε build** — `L10n.isGreek(context)` μόνο όπου ήδη γίνεται (Session 224 fix6 pattern)
- **Partition στο provider** (state change) → 1 rebuild grid ανά search/loadMore — ίδιο με το σημερινό flow
- **ProfileCard**: read-only logic (`profile.helpRequest`), καμία νέα reactive dependency → το υπάρχον `(×2)` από `userStatusProvider` (Sessions 215/155) **παραμένει ως σχεδιασμένο**
- **SOS εικονίδιο**: `Image.asset` static — κανένα rebuild
- **SearchResultsGrid**: η λίστα έρχεται ήδη ταξινομημένη από το provider — το `Wrap` δεν αλλάζει κώδικα

---

## 11. Αρχεία που θα αγγίξω (κατά σειρά εφαρμογής)

| # | Αρχείο | Αλλαγή |
|---|--------|--------|
| 1 | `lib/shared/models/public_profile.dart` | + `HelpRequest` freezed + πεδίο `helpRequest` |
| 2 | (generated) `public_profile.freezed.dart` / `.g.dart` | build_runner |
| 3 | `lib/core/config/feature_flags.dart` | + `helpRequestEnabled = true` |
| 4 | `lib/core/debug/debug_config.dart` | + flag `helpRequest` |
| 5 | `lib/core/utils/error_messages.dart` | + 7 codes |
| 6 | `lib/core/l10n/l10n.dart` | + helpRequest labels + μετονομασία `'help'` |
| 7 | `lib/features/profile/screens/profile_editor_screen.dart` | label «Υποστήριξη» |
| 8 | `lib/repositories/profile_repository_impl.dart` | preserve `helpRequest` στο publish |
| 9 | ΝΕΟ `lib/shared/utils/help_request_config.dart` | SPoT: TTL, radius options, maxLength, eligibility check |
| 10 | ΝΕΟ `lib/features/discovery/widgets/help_request_sheet.dart` | bottom sheet (eligibility + settings + activate) |
| 11 | `lib/features/discovery/screens/discovery_screen.dart` | SOS IconButton στην AppBar |
| 12 | `lib/features/discovery/providers/search_provider.dart` | priority partition σε search() + loadMore() |
| 13 | `lib/shared/widgets/profile_card.dart` | κόκκινη κάρτα + μήνυμα (read-only) |

**Σημείωση:** Κάθε βήμα: backup → edit → `flutter analyze`. Ένα βήμα τη φορά, με έλεγχο του χρήστη.

---

## 12. Εκκρεμεί για σένα (πριν την εφαρμογή)

1. Έλεγχος αυτού του αρχείου (σωστό / λάθος / προσθήκες)
2. Αν είσαι ΟΚ → εντολή «επόμενο» → ξεκινάω Βήμα 1 (backup + model + build_runner)
