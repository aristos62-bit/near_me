# NearMe — Επείγουσα Βοήθεια (SOS / Help Request)

> **Κατάσταση:** Πρόταση v3 — επανελέγχθηκε 14/8 (bugs #1-#6 + δευτερεύουσες ενσωματωμένες, rules validation εγκεκριμένο §9.2). ΔΕΝ έχει ξεκινήσει καμία αλλαγή κώδικα.
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
| 10 | **Rules validation** | ΕΓΚΕΚΡΙΜΕΝΟ — targeted rule για το `helpRequest` (active is bool, radiusKm 1-50, message ≤ 80, updatedAt is string, isVerified) — μόνο όταν γράφεται το πεδίο (§9.2) |

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
| Owner write σε δικό του public doc | update rule επιτρέπει νέο πεδίο (περιορισμός μόνο geoHash, age≥18) — **προστίθεται targeted validation για το `helpRequest` (ΕΓΚΕΚΡΙΜΕΝΟ, §9.2)** | firestore.rules:94-99 |
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
    DateTime? updatedAt,       // nullable — αποθήκευση σε UTC: now.toUtc().toIso8601String() (το parent είναι local-no-offset, αλλά το SOS συγκρίνεται cross-device → χρειάζεται UTC, BUG 4)
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
      updatedAt: "2026-08-14T15:00:00.000Z"   // ISO8601 string σε UTC (Z) — ΟΧΙ Firestore Timestamp
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
  required bool hasVisibleLocation,  // published geoHash != null (Β3) — από το ίδιο publicProfileStreamProvider
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

Αν λείπει κάτι → λίστα **«Τι χρειάζεται για να ζητήσεις βοήθεια»** με κουμπί διόρθωσης (Verify / Publish / GPS / Άνοιξε κανάλι / **Κάνε την τοποθεσία ορατή**).

**⚠️ `hasVisibleLocation` (Β3):** ο έλεγχος γίνεται στο published `geoHash != null`. Με `geoPrecision='hidden'` το `computeGeoHash` **σβήνει** το geoHash (functions/src/index.ts:837) → το SOS θα ήταν ενεργό αλλά αόρατο σε όλους (distances κενό → ποτέ urgent) ενώ ο αιτών θα νόμιζε ότι λειτουργεί. Ο έλεγχος γίνεται μέσω του ίδιου `publicProfileStreamProvider` (όχι νέο stream).

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
    'updatedAt': DateTime.now().toUtc().toIso8601String(),   // ← ISO8601 string σε UTC (Z) — ΟΧΙ serverTimestamp, ΟΧΙ local-no-offset (BUG 4)
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

- **1 write** · owner · rules OK — το νέο πεδίο περνάει από το υπάρχον update rule + validation §9.2
- Δεν τρέχει το `publish()` — στοχευμένο update μόνο στο `helpRequest`
- **Repository + consent log (Β8):** το write γίνεται μέσω νέας μεθόδου `profile_repository_impl.setHelpRequest(...)` (ΟΧΙ raw `_firestore.update()` στο widget) + `_db.logConsent(uid, 'help_request_activate'/'deactivate', 'public')` για συνέπεια με publish/unpublish
- **Edge case (Β4):** το `.update()` ρίχνει `not-found` αν το doc δεν υπάρχει (π.χ. unpublish σε άλλη συσκευή ενώ το local `isPublished` είναι ακόμα true) → mapping σε `help/not-found` (ή re-publish πριν το update)

### 5.3 Απενεργοποίηση

- Ίδιο κουμπί → αν ενεργό → **`FieldValue.delete('helpRequest')`** (καθαρός καθαρισμός — δεν μένει stale object στο doc)
- Confirm dialog μέσω AppMessenger

### 5.4 Αυτόματο TTL (60 λεπτά)

- **Χωρίς Dart timers** (background-unsafe, Session 152 μάθημα)
- Στο άνοιγμα της Discovery: αν το **δικό σου** `helpRequest.updatedAt < now - 60min` → αυτόματο off (1 write) + ενημέρωση UI
- Οι βοηθοί αγνοούν flags με `updatedAt` εκτός TTL (βλ. §6)
- **Σύγκριση:** αφού το `updatedAt` είναι ISO8601 string, πάντα `DateTime.parse(h.updatedAt)` → σύγκριση ως `DateTime` (ποτέ string comparison)
- **Ζώνη ώρας (BUG 4):** γράφουμε σε **UTC** (`now.toUtc().toIso8601String()` → καταλήγει σε `Z`). Το `DateTime.parse` ενός string με `Z` δίνει το **ίδιο instant για όλους** τους βοηθούς ανεξαρτήτως ζώνης. Αν γράφαμε local-no-offset (π.χ. `15:00` Αθήνας χωρίς `Z`), ο βοηθός σε άλλη ζώνη θα το ερμήνευε ως **δικό του** τοπικό → λάθος duration: βοηθοί δυτικά → «μόνιμα urgent», βοηθοί ανατολικά → «ποτέ urgent». Το parent `updatedAt` έχει το ίδιο idiom αλλά συγκρίνεται μόνο στο ίδιο device (merge στο `getProfile`) → εκεί είναι ακίνδυνο· στο SOS η σύγκριση είναι cross-device, γι' αυτό αλλάζουμε σε UTC μόνο εδώ.

---

## 6. Ροή — Βοηθός (όσοι βλέπουν)

### 6.1 Priority partition (στο provider)

Στο `SearchNotifier` — **μετά το fetch, πριν το set state** — και στα δύο: `search()` και στο τέλος του `loadMore()` (μετά το append, search_provider.dart:278):

```dart
List<PublicProfile> _prioritizeHelpRequests(
  List<PublicProfile> results,
  Map<String, double> distances,   // φρέσκο map της τρέχουσας κλήσης — ΟΧΙ state.distances (BUG 1)
) {
  final now = DateTime.now();
  final urgent = <PublicProfile>[];
  final rest = <PublicProfile>[];
  for (final p in results) {
    final h = p.helpRequest;
    final dist = distances[p.uid];               // ήδη υπολογισμένο, από το τρέχον batch
    final isUrgent = h != null && h.active
        && h.updatedAt != null          // πραγματικός guard (updatedAt nullable)
        && now.difference(h.updatedAt!) <= ttl  // 60 min — instant compare (UTC storage)
        && dist != null && dist <= h.radiusKm;   // null guard (BUG 2)
    (isUrgent ? urgent : rest).add(p);
  }
  return [...urgent, ...rest];                    // stable partition
}
```

- **Κλήση με το φρέσκο distances (BUG 1):** στο `search()` → `_prioritizeHelpRequests(filtered, distances)` (το τοπικό map, πριν το set state)· στο `loadMore()` → `_prioritizeHelpRequests(all, allDistances)` (μετά το append). **Ποτέ** `state.distances`: στη `search()` το state μόλις μπήκε σε loading (:164) με `distances = {}` → θα κατέληγε κανένα urgent· στο `loadMore()` (:255) κρατά το **παλιό** map χωρίς τις αποστάσεις του νέου batch.

- Οι urgent πρώτοι, οι υπόλοιποι στην τωρινή σειρά (geoHash/__name__ — ίδια με σήμερα)
- **Cursor/σελιδοποίηση άθικτα** (partition δεν αλλάζει το cursor)
- Κανένα νέο `where` στο query → κανένα νέο index, ίδιο κόστος reads
- **`searchNearby()` (:190-233) (BUG 5):** σήμερα καλείται μόνο εσωτερικά (κανένα UI caller) — αν μελλοντικά χρησιμοποιηθεί, το ίδιο partition (με το φρέσκο distances) πρέπει να μπει κι εκεί

### 6.2 Κόκκινη κάρτα (ProfileCard)

Η `ProfileCard` **ήδη** έχει `profile` και `distanceKm` — **καμία αλλαγή υπογραφής**:

- Αν `helpRequest.active && updatedAt εντός 60min && distanceKm != null && distanceKm <= radiusKm` (null-guard: `distanceKm` είναι `double?` — η σύγκριση χωρίς guard δεν κάνει compile):
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
- Μετονομασία `'help'` label: «Βοήθεια» → «Υποστήριξη» / «Help» → «Support» — **2 edits** (SPoT + editor), **5 σημεία εμφάνισης** (Β1):
  - `l10n.dart:110/120` (SPoT) → προπαγανδίζεται σε ΟΛΑ: `profile_card:151`, `profile_screen:157`, **`search_filters_screen:290`, `saved_searches_screen:107`, `public_profile_view_screen:210`**
  - `profile_editor_screen.dart:73` (δικό του map, ξεχωριστό από το SPoT — δεν καλύπτεται από την αλλαγή στο l10n)
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
- `help/not-found` — «Δεν βρέθηκε το δημοσιευμένο προφίλ» (update not-found, Β4)
- `help/hidden-location` — «Κάνε την τοποθεσία σου ορατή για να ζητήσεις βοήθεια» (geoPrecision=hidden, Β3)

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
4. Firestore rules: **ΕΓΚΕΚΡΙΜΕΝΗ αλλαγή** — targeted validation του `helpRequest` (§9.2). Indexes / Cloud Functions: **καμία αλλαγή**
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
| `updatedAt` null (legacy doc) | Guard: αν null → μη-urgent (fail-safe) — **εφικτό γιατί το πεδίο είναι nullable** (αν ήταν required, το `fromJson` θα έκανε `null as String` → crash → σπασμένη αναζήτηση όλων, ίδιο ρίσκο με το Εύρημα #1) |
| `geoPrecision='hidden'` | Published `geoHash` απών → SOS ενεργό αλλά αόρατο (distances κενό) — eligibility μπλοκάρει με `hasVisibleLocation` + «Κάνε την τοποθεσία ορατή» (Β3) |
| `updatedAt` στο μέλλον (hacked client) | `now.difference` αρνητικό → `<= ttl` → μόνιμα urgent — αποτρέπεται server-side με validation rule (§9.2) |

### 9.1 try/catch ανά έγγραφο στο Firestore search (Εύρημα #4) — ΕΓΚΕΚΡΙΜΕΝΟ

**Γιατί έχει νόημα (όχι απλώς «καλή πρακτική»):** Το SOS είναι η πρώτη λειτουργία που εισάγει non-trivial nested object (`HelpRequest`) στο `fromJson`. Μέχρι σήμερα όλα τα πεδία του `PublicProfile` είναι flat strings/bools/ένα nullable DateTime — πρακτικά αδύνατο να ρίξουν exception στο parsing. Με το nested object (typed `DateTime`/`double`) το ρίσκο parsing failure αυξάνεται ουσιαστικά για πρώτη φορά — δηλαδή το ενεργοποιεί η ίδια η αλλαγή που κάνουμε.

**Και τα 3 σημεία κλήσης (επιβεβαιωμένα στον κώδικα):**
- `firestore_search_repository.dart:135` — `_generalSearch` (`all.add`)
- `firestore_search_repository.dart:216` — `collectionGroup`/`_geoSearch` (`all.add`)
- `firestore_search_repository.dart:307` — `searchNearby` (`results.add`)

Ένα κατεστραμμένο `helpRequest` σε ΟΠΟΙΟΔΗΠΟΤΕ προφίλ θα έριχνε σφάλμα και στις 3 μεθόδους.

**Επιπλέον σημείο (BUG 6):** το `profile_repository_impl.dart:580` (`getPublicProfile`) κάνει `PublicProfile.fromJson(doc.data()!)` **χωρίς try/catch** — χρησιμοποιείται από `send_request_screen.dart:36` και `blocked_users_screen.dart:96`. Ένα malformed `helpRequest` εκεί θα έριχνε αυτά τα screens (το exception τυλίγεται σε `AppException.firestore`). Να χρησιμοποιήσει το υπάρχον `_safePublicProfileFromJson` (ή ισοδύναμο try/catch → null). Τα άλλα σημεία του repo (:36, :554, :612) έχουν ήδη try/catch.

**Μηδενικό side effect στη σελιδοποίηση (επιβεβαιωμένο):** το `hasMore` και το `cursorOut` υπολογίζονται πάντα από το **raw `snapshot.docs`**, ποτέ από τη λίστα με τα parsed αντικείμενα:
```dart
// _generalSearch — γρ. 219-220
final hasMore = snapshot.docs.length >= effectiveLimit;  // raw snapshot
final cursorOut = ... snapshot.docs.last.id ...;          // raw snapshot
// searchNearby — γρ. 333-334
final hasMore = snapshots.any((s) => s.docs.length >= 50); // raw
```
Skip ενός malformed doc → καμία επίπτωση σε cursor/pagination.

**Τι αλλάζει:**
- Σήμερα: 1 χαλασμένο doc → throw σε όλη τη function → εξωτερικό catch (:356 και αντίστοιχα) → γενικό σφάλμα, 0 αποτελέσματα.
- Με τη διόρθωση: skip + `DebugConfig.warn` log → όλα τα άλλα αποτελέσματα κανονικά.

**Trade-off:** «κρύβει» σιωπηλά ένα malformed doc αντί να σκάσει δυνατά — γι' αυτό το `DebugConfig.warn` είναι υποχρεωτικό (όχι silent skip), ώστε να φαίνεται στα logs αν συμβεί ποτέ.

**Εμβέλεια:** ξεχωριστό βήμα **#14** στη λίστα αρχείων (§11), μετά τα κύρια SOS βήματα — απομονωμένο αν κάτι πάει στραβά.

### 9.2 Validation rule για το `helpRequest` (ΕΓΚΕΚΡΙΜΕΝΟ — BUG 3)

Το update rule (:94-99) δεν επικυρώνει καθόλου το `helpRequest` — ένας owner (ακόμα και ανώνυμος, γιατί το `allow create` δεν απαιτεί `isVerified`) θα μπορούσε μέσω SDK να γράψει `radiusKm: 999999`, `updatedAt` στο μέλλον (μόνιμο urgent, αρνητικό `difference` → `<= ttl`) ή τεράστιο `message` (φούσκωμα doc/read cost). Προσθήκη στο `allow update` — ο περιορισμός ισχύει **μόνο όταν γράφεται το πεδίο**, άρα δεν σπάει τα υπόλοιπα update (και οι legit αιτούντες είναι πάντα verified):

```js
&& (!('helpRequest' in request.resource.data)
    || (request.resource.data.helpRequest.active is bool
        && request.resource.data.helpRequest.radiusKm is number
        && request.resource.data.helpRequest.radiusKm >= 1
        && request.resource.data.helpRequest.radiusKm <= 50
        && request.resource.data.helpRequest.message is string
        && request.resource.data.helpRequest.message.size() <= 80
        && request.resource.data.helpRequest.updatedAt is string
        && isVerified()))
```

**Περιορισμός:** τα rules **δεν μπορούν** να ελέγξουν την *πρόσφατη* τιμή του `updatedAt` (ISO string) — ο έλεγχος TTL παραμένει client-side (§5.4)· το rule σφραγίζει μόνο shape/τύπο/εύρος/verification (αποτρέπει spam radius/message και το απροσδιόριστο μέλλον). **Εφαρμογή:** ξεχωριστό βήμα μετά το sos.md — backup `firestore.rules` → edit → deploy.

---

## 10. Rebuild storm (Κεφάλαιο 10 — νέος έλεγχος)

- **0 νέο `MediaQuery` σε build** — το sheet χρησιμοποιεί viewInsets event-driven (όχι dependency). Κανόνας Session 221/224
- **0 νέο `Localizations.localeOf` σε build** — `L10n.isGreek(context)` μόνο όπου ήδη γίνεται (Session 224 fix6 pattern)
- **Partition στο provider** (state change) → 1 rebuild grid ανά search/loadMore — ίδιο με το σημερινό flow
- **ProfileCard**: read-only logic (`profile.helpRequest`), καμία νέα reactive dependency → το υπάρχον `(×2)` από `userStatusProvider` (Sessions 215/155) **παραμένει ως σχεδιασμένο**
- **SOS εικονίδιο**: `Image.asset` static — το κόκκινο ring (active state, §5.1) διαβάζει το δικό σου `publicProfileStreamProvider` → είναι reactive, αλλά σε **leaf widget** (απομονωμένο `ConsumerWidget`) ώστε να μην ξαναχτίζει το grid (διόρθωση αντίφασης με το «κανένα rebuild»)
- **SearchResultsGrid**: η λίστα έρχεται ήδη ταξινομημένη από το provider — το `Wrap` δεν αλλάζει κώδικα

---

## 11. Αρχεία που θα αγγίξω (κατά σειρά εφαρμογής)

| # | Αρχείο | Αλλαγή |
|---|--------|--------|
| 1 | `lib/shared/models/public_profile.dart` | + `HelpRequest` freezed + πεδίο `helpRequest` |
| 2 | (generated) `public_profile.freezed.dart` / `.g.dart` | build_runner |
| 3 | `lib/core/config/feature_flags.dart` | + `helpRequestEnabled = true` |
| 4 | `lib/core/debug/debug_config.dart` | + flag `helpRequest` |
| 5 | `lib/core/utils/error_messages.dart` | + 9 codes (help/*) |
| 6 | `lib/core/l10n/l10n.dart` | + helpRequest labels + μετονομασία `'help'` |
| 7 | `lib/features/profile/screens/profile_editor_screen.dart` | label «Υποστήριξη» |
| 8 | `lib/repositories/profile_repository_impl.dart` | preserve `helpRequest` στο publish + νέα μέθοδος `setHelpRequest(...)` με consent log (Β8) |
| 9 | ΝΕΟ `lib/shared/utils/help_request_config.dart` | SPoT: TTL, radius options, maxLength, eligibility check |
| 10 | ΝΕΟ `lib/features/discovery/widgets/help_request_sheet.dart` | bottom sheet (eligibility + settings + activate) |
| 11 | `lib/features/discovery/screens/discovery_screen.dart` | SOS IconButton στην AppBar |
| 12 | `lib/features/discovery/providers/search_provider.dart` | priority partition σε search() + loadMore() |
| 13 | `lib/shared/widgets/profile_card.dart` | κόκκινη κάρτα + μήνυμα (read-only) |
| 14 | `lib/repositories/firestore_search_repository.dart` | **ΕΓΚΕΚΡΙΜΕΝΟ (Εύρημα #4):** try/catch ανά έγγραφο στα 3 σημεία `fromJson` (:135, :216, :307) → skip + `DebugConfig.warn`, χωρίς side effect σε hasMore/cursor |
| 15 | `firestore.rules` | **ΕΓΚΕΚΡΙΜΕΝΟ (BUG 3):** targeted validation του `helpRequest` στο `allow update` (§9.2) — ξεχωριστό βήμα, backup + deploy |

**Σημείωση:** Κάθε βήμα: backup → edit → `flutter analyze`. Ένα βήμα τη φορά, με έλεγχο του χρήστη.

---

## 12. Εκκρεμεί για σένα (πριν την εφαρμογή)

1. ✅ Επανέλεγχος 14/8: bugs #1-#6 + δευτερεύουσες B1-B8 ενσωματώθηκαν στο αρχείο· rules validation εγκεκριμένο (§9.2)
2. Αν είσαι ΟΚ → εντολή «επόμενο» → ξεκινάω Βήμα 1 (backup + model + build_runner)
