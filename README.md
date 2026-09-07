# NearMe — Privacy-First Local Discovery App

> **Προσοχή:** Αυτό το README είναι προσαρμοσμένο για το έργο NearMe και όχι το default Flutter template. Οδηγεί νέους (και παλιούς) συνεργάτες βήμα-βήμα στο πώς τρέχουν, δοκιμάζουν και κάνουν build την εφαρμογή στην τρέχουσα κατάσταση (Φάσεις 1-3 πλήρεις).

Το **NearMe** είναι μια εφαρμογή τοπικής ανακάλυψης με έμφαση στο **απόρρητο και το local-first design**: το πλήρες προφίλ αποθηκεύεται μόνο στη συσκευή (Drift/SQLite στοπικό DB) και στο Firestore ανεβαίνει μόνο το «public snapshot» που επιλέγει ο χρήστης, πεδίο-προς-πεδίο (granular privacy).

---

## 🧱 Περιεχόμενα
- [Τεχνολογίες](#τεχνολογίες)
- [Απαιτήσεις](#απαιτήσεις)
- [Εγκατάσταση & Setup](#εγκατάσταση--setup)
- [Κοινές Εντολές](#κοινές-εντολές)
- [Code Generation](#code-generation)
- [Testing](#testing)
- [Debug System](#debug-system)
- [Firebase & Cloud Functions](#firebase--cloud-functions)
- [Αρχιτεκτονική](#αρχιτεκτονική)
- [Φάσεις Υλοποίησης](#φάσεις-υλοποίησης)
- [Πιστοποιητικά & Hosting](#πιστοποιητικά--hosting)
- [Άδεια](#άδεια)

---

## Τεχνολογίες

| Τομέας | Τεχνολογία |
|---|---|
| Framework | **Flutter 3.44.4 / Dart 3.12.2** (SDK constraint `^3.12.0`) |
| State management | **Riverpod 3** (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) |
| Τοπική βάση | **Drift** (SQLite) — 7 tables, schema v17 |
| Cloud DB | **Firebase Firestore** + **Firestore Security Rules** |
| Auth | Firebease **Anonymous-first** → Email/Phone upgrade (lazy) |
| Push | **Firebase Cloud Messaging** (FCM) |
| Serverless | **Cloud Functions** (gen1, Node 22, `europe-west1`) |
| GPS | `geolocator` + `geoflutterfire_plus` (geo Firestore queries) |
| Κρυπτογραφία | `encrypt` (AES-256) + `crypto` (SHA-256) · keys σε `flutter_secure_storage` |
| Ροή/Εικόνα | `video_player`, `cached_network_image`, `image_picker`, `image_cropper` |
| Άλλα | `go_router`, `intl`, `freezed`, `json_serializable`, `uuid`, `local_auth` (biometric), `connectivity_plus`, `geocoding` |

Πλήρης λίστα με εκδόσεις στο `pubspec.yaml`.

---

## Απαιτήσεις

- **Flutter 3.44.4** ή νεότερο (Dart 3.12.2)
- **Firebase CLI** (για deploy functions/rules/hosting)
- **Node.js 22** (για το `functions/` folder)
- Λογαριασμός Firebase με project **`nearme-eu`** (βλ. [Firebase](#firebase--cloud-functions))
- Πλατφόρμες: `android`, `ios`, `web`, `linux`, `macos`, `windows` (όλα παρόντα στο project)

---

## Εγκατάσταση & Setup

```bash
# 1. Κλωνοποίηση
git clone https://github.com/aristos62-bit/near_me.git
cd near_me

# 2. Εγκατάσταση Flutter dependencies
flutter pub get

# 3. (Αν δεν υπάρχουν) Παραγωγή codegen (Drift, freezed, riverpod generators)
dart run build_runner build --delete-conflicting-outputs

# 4. (Αν δεν υπάρχουν) Εγκατάσταση Cloud Functions dependencies
cd functions
npm install
cd ..
```

> **Σημείωση:** Το λέει και το AGENTS.md — **ποτέ μην κάνεις `edit` σε αρχεία χωρίς ρητή εντολή**. Πριν αλλάξεις κώδικα, διάβασε `nearme_blueprint.md` και `oldsessions.md` για το context των προηγούμενων sessions.

---

## Κοινές Εντολές

```bash
# Τρέξε την εφαρμογή (default — ανάπτυξη)
flutter run

# Τρέξε με debugs ενεργά ακόμα και σε release
flutter run --dart-define=ENABLE_RELEASE_DEBUG=true

# Build release APK (Android)
flutter build apk --release

# Build release με debugs ανοιχτά (debugging σε release)
flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true

# Lint / static analysis
flutter analyze

# Tests
flutter test
```

---

## Code Generation

Μετά από αλλαγή σε **Drift models**, **freezed** ή **riverpod generators** πρέπει να ξανατρέξεις τον builder:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Testing

Το project έχει **500 tests** που περνάνε (`flutter test`) και `flutter analyze` χωρίς warnings.

```bash
# Τρέξε τα πάντα
flutter test

# Τρέξε συγκεκριμένο φάκελο / αρχείο
flutter test test/repositories/
flutter test test/providers/unread_badge_provider_test.dart

# Coverage
flutter test --coverage
```

### Τρέχουσα κάλυψη (Session 271, πλήρες run)
| Περιοχή | Coverage |
|---|---|
| **Σύνολο** | **26.8%** (4204/15662, excl. generated) |
| repositories | **69.4%** |
| shared/widgets | **80.3%** |
| lib/providers | 72.2% |
| core/utils | 63.4% |
| core/theme | 59.3% |
| features/screens | ~1.5%-9.4% (μεγαλύτερο κενό) |
| data/remote · core/services | 0% · 3.3% |

**Δομή test:** `test/repositories/` (ισχυρή κάλυψη repos), `test/widgets/` (shared widgets), `test/providers/` (provider logic), `test/core/`, `test/shared/`, `test/utils/`, `test/models/`, `test/features/`.

> **Σημείωση για τους developers:** Το μεγαλύτερο κενό κάλυψης είναι τα **screens** (features). Οι επόμενες εκστρατείες testing επικεντρώνονται εκεί.

---

## Debug System

Το project έχει κεντρικό `debug_config.dart` που ελέγχει τα debug μηνύματα.

- **Master switch:** `DebugConfig.debugMode` (αυτόματα `OFF` σε release)
- **Release override:** `--dart-define=ENABLE_RELEASE_DEBUG=true`
- **Κατηγορίες flags:** `databaseLocal`, `firestoreRead/Write`, `authFlow`, `gps`, `provider*`, `service*`, `repository*`, `navigation*`, `ui*`, `consentLog*`, `chat*`, `storage*`
- **Log levels:** `DebugConfig.log(flag, msg)`, `warn(msg)`, `error(msg)`

---

## Firebase & Cloud Functions

- **Firebase project (default):** `nearme-eu` — location **eur3** (multi-region Europe)
- **Παλιό project:** `nearme-gr` (alias `old-nam5` στο `.firebaserc`, μετά τη migration 22 Αυγ 2026)
- **Cloud Functions region:** `europe-west1` (gen1, Node 22)
- **17 Cloud Functions deployed** (συμπ. `checkImageModeration`/`moderateImage` Vision moderation, `addGroupParticipant`/`leaveGroup`, `expireStaleRequests/Messages`, `computeGeoHash`, `checkSearchRateLimit`, `deleteUserData`, `onReportCreated`, `onRequestCreated` server `expiresAt`, 5 FCM)
- **Vision moderation:** `eu-vision.googleapis.com` (eur3)

> **Σημαντικό:** Οι client κλήσεις σε Cloud Functions πρέπει **πάντα** να χρησιμοποιούν `FirebaseFunctions.instanceFor(region: 'europe-west1')`, **ποτέ** το default instance.

```bash
# Deploy rules / functions / hosting
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only hosting
```

---

## Αρχιτεκτονική

```
lib/
├── core/               # config, theme, l10n, router, firebase_init, utils
├── data/
│   ├── local/          # Drift database (7 tables, schema v17)
│   └── remote/         # Firestore & Storage services
├── providers/          # Core providers (connectivity, database, unread_badge)
├── repositories/       # 8 abstract interfaces + implementations
├── features/
│   ├── auth/           # Anonymous → Email/Phone upgrade
│   ├── profile/        # profile_editor, privacy_editor, consent_log
│   ├── discovery/      # search, filters, public_profile_view
│   ├── chat/           # chat_list, chat_screen (1-1 + groups)
│   ├── requests/       # dashboard, send_request
│   ├── block/          # block/unblock
│   ├── report/         # report user
│   ├── video/          # Φάση 4
│   └── settings/       # settings, delete_account
└── shared/             # widgets, utils, models
```

### Βασικές αρχές
- **Privacy-first / Local-first**: πλήρες profile μόνο στο Drift · στο Firestore μόνο το public snapshot που επιλέγει ο χρήστης
- **Repository pattern**: abstract interface → swap implementations (π.χ. FirestoreSearch → TypesenseSearch χωρίς UI changes)
- **Feature flags**: κάθε feature wrapped σε `FeatureFlag.xxx` για σταδιακό rollout
- **Granular privacy**: κάθε πεδίο ξεχωριστό toggle ορατότητας
- **Anonymous-first auth**: Firebase Anonymous → Email/Phone upgrade lazy
- **Responsive**: mobile / tablet / desktop
- **Shared widgets & utils**: επαναλαμβανόμενα UI components και common logic σε κεντρικά σημεία
- **Unified error handling**: `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw `ScaffoldMessenger`/`AlertDialog`

---

## Φάσεις Υλοποίησης

| Φάση | Περιεχόμενο | Κατάσταση |
|---|---|---|
| **Φάση 1** | Core & Privacy (Drift schemas, Firebase init, Anonymous auth, Profile CRUD local, PrivacySettings, ConsentLog, GPS flow, i18n, Theme, Feature flags, Security Rules) | ✅ 100% |
| **Φάση 2** | Discovery (Firestore search, Filters, Dashboard, PublicProfile, Saved searches, Block/Report) | ✅ 100% |
| **Φάση 3** | Communication (Email/Phone verify, Request system, E2E chat, FCM push, Online presence, Rate limiting) | ✅ 100% |
| **Φάση 4** | Typesense, Video calls, AI matching, Groups, Verified badge, Premium, Web, Admin panel | 🔄 σε εξέλιξη |

---

## Πιστοποιητικά & Hosting

- **Hosting:** `https://nearme-eu.web.app/privacy` (200) · `firebase.json:21` `hosting.public` + `cleanUrls:true`
- **Privacy policy:** `hosting/privacy.html` (10.5KB) · **Terms:** `hosting/terms.html`
- **App signing:** release APK signed `gr.nearme.app` (CN=NearMe) · μέγεθος ~20.8MB (R8)
- **Email:** `soc.near.app@gmail.com`

---

## Άδεια

Ιδιωτικό έργο. Ο κώδικας καλύπτεται από τους κανόνες του `AGENTS.md` (ανάπτυξη ένα βήμα τη φορά, backups πριν κάθε αλλαγή). Για απορίες, δες `nearme_blueprint.md`.
