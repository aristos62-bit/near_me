# NearMe — AGENTS.md

## ⚠️ ΑΠΟΛΥΤΟΙ ΚΑΝΟΝΕΣ (παραβίαση = απαράδεκτο)
1. **ΠΟΤΕ μην κάνεις edit σε αρχεία** χωρίς ρητή εντολή του χρήστη
2. Αν ο χρήστης σου πει να κάνεις edit τότε πρώτα παίρνεις back up το αρχείο και μετά το κάνεις edit και ΜΟΝΟ στο συγκεκριμένο αρχείο ΠΟΤΕ σε άλλο αν χρειάζεται να κάνεις και σε άλλο edit ΠΑΝΤΑ ρωτάς τον χρήστη αν θέλει η όχι.
3. **ΠΟΤΕ μην προχωράς σε αλλαγή** χωρίς πρώτα να την εξηγήσεις και να πάρεις OK
4. **ΠΑΝΤΑ προχωράμε ενα βημα τη φορα κανει ο χρηστης έλεγχους και ΜΟΝΟ αν πει "επόμενο" συνεχίζεις**
5. Πριν προτείνεις βελτίωση/διόρθωση, έλεγξε διεξοδικά αν θα επηρεαστεί άλλο τμήμα κώδικα.
6. Διάβασε το oldsessions.md για να θυμηθείς τι κάναμε στο προηγούμενο session
7. Αν δε θυμάσαι αυτούς τους κανόνες, σταμάτα και ρώτα

Γλώσσα επικοινωνίας: **Ελληνικά**. Όλες οι απαντήσεις στα ελληνικά.

## Τεχνολογίες (resolved — Μάιος 2026)

### Core
- Flutter 3.44.0 / Dart 3.12.0
- SDK constraint: ^3.12.0

### Resolved Packages (από pubspec.lock)

| Package | Έκδοση | Χρήση |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | State management |
| `riverpod` | 2.6.1 | Core Riverpod |
| `riverpod_annotation` | 2.6.1 | @riverpod annotation |
| `isar` | 3.1.0+1 | Local database |
| `isar_flutter_libs` | 3.1.0+1 | Isar native libs |
| `path_provider` | 2.1.5 | Isar directory |
| `firebase_core` | 4.9.0 | Firebase init |
| `firebase_auth` | 6.5.1 | Authentication |
| `cloud_firestore` | 6.4.1 | Cloud DB |
| `firebase_storage` | 13.4.1 | File storage |
| `firebase_messaging` | 16.2.2 | Push notifications |
| `cloud_functions` | 6.3.1 | Serverless functions |
| `geolocator` | 14.0.2 | GPS |
| `geoflutterfire_plus` | 0.0.34 | Geo Firestore queries |
| `go_router` | 17.2.3 | Navigation |
| `encrypt` | 5.0.3 | AES-256 encryption |
| `flutter_secure_storage` | 10.3.1 | Secure key storage |
| `local_auth` | 3.0.1 | Biometric lock |
| `intl` | 0.20.2 | i18n |
| `cached_network_image` | 3.4.1 | Image cache |
| `image_picker` | 1.2.2 | Pick photos |
| `freezed_annotation` | 2.4.4 | Immutable models |
| `json_annotation` | 4.9.0 | JSON serialization |
| `uuid` | 4.5.3 | UUID generation |
| `connectivity_plus` | 7.1.1 | Network status |
| `build_runner` | 2.4.13 | Code gen runner |
| `isar_generator` | 3.1.0+1 | Isar model generator |
| `riverpod_generator` | 2.4.0 | Riverpod code gen |
| `freezed` | 2.5.2 | Freezed code gen |
| `json_serializable` | 6.8.0 | JSON code gen |
| `flutter_lints` | 6.0.0 | Lint rules |

## Βασικές εντολές
- `flutter pub run build_runner build --delete-conflicting-outputs` — μετά από αλλαγή σε Isar models / freezed
- `flutter test` — widget tests
- `flutter analyze` — linting
- `flutter pub add <package>` — προσθήκη πακέτου
- `flutter run --dart-define=ENABLE_RELEASE_DEBUG=true` — run με debugs ανοιχτά (ακόμα και release)
- `flutter build apk --release --dart-define=ENABLE_RELEASE_DEBUG=true` — build με debugs

## Debug system
- **Master switch**: `lib/core/debug/debug_config.dart` — `DebugConfig.debugMode` (αυτόματα OFF σε release)
- **Release override**: `--dart-define=ENABLE_RELEASE_DEBUG=true` για να βλέπεις debugs και σε release
- **Κατηγορίες flags**: databaseLocal, firestoreRead/Write, authFlow, gps, provider*, service*, repository*, navigation*, ui*, consentLog*, chat*, storage*
- **Log levels**: `DebugConfig.log(flag, msg)` (υπόκειται σε flag), `warn(msg)` (debug mode μόνο), `error(msg)` (πάντα)
- **Περιορισμός**: κανένα αρχείο > 400 γραμμές

## Αρχιτεκτονική

### Δομή φακέλων (Planned)
```
lib/
├── core/               # config, theme, l10n, router, firebase_init, utils
├── data/
│   ├── local/          # Isar schemas + isar_service
│   └── remote/         # firestore_service, storage_service
├── repositories/       # search_repository, auth_repository, profile_repository, chat_repository, request_repository
├── features/
│   ├── auth/           # providers + screens
│   ├── profile/        # profile_editor, privacy_editor, consent_log
│   ├── discovery/      # search, filters, public_profile_view
│   ├── chat/           # chat_list, chat_screen
│   ├── requests/       # dashboard, send_request
│   ├── video/          # Φάση 4
│   └── settings/       # settings, delete_account
└── shared/             # widgets, public_profile model
```

### Αρχές
- **Privacy-first / Local-first**: Πλήρες profile αποκλειστικά στο Isar. Στο Firestore μόνο το public snapshot που επιλέγει ο χρήστης.
- **Repository pattern**: Abstract interface → swap implementations (π.χ. FirestoreSearch → Type senseSearch χωρίς UI changes)
- **Feature flags**: Κάθε feature wrapped σε `FeatureFlag.xxx` για σταδιακό rollout
- **Granular privacy**: Κάθε πεδίο ξεχωριστό toggle ορατότητας
- **Anonymous-first auth**: Firebase Anonymous → Email/Phone upgrade lazy
- **Responsive**: Κάθε screen λειτουργεί σωστά σε mobile/tablet/desktop
- **Shared widgets**: Επαναλαμβανόμενα UI components → shared widgets, όχι duplication
- **Shared utils**: Common logic (formatters, validators, helpers) → κεντρικά utils
- **Debug logging**: `DebugConfig.log()` σε κάθε operational action από την αρχή
- **Unified error handling**: `ErrorView`/`LoadingView`/`EmptyView` (από `app_state_widget.dart`) για async states — `AppMessenger.showSuccess/Error/Info/ConfirmDialog` για snack bars, dialogs, loading. Ποτέ raw ScaffoldMessenger, AlertDialog ή error/loading widgets ανά screen.

## Project facts
- GitHub: —
- Τοπικό path: `C:\Users\Vaggelis\Flutter Projects\near_me`
- IDE: Android Studio Panda 4 | 2025.3.4 Patch 1
- Multi-platform: android, ios, web, Linux, macOS, windows

## Σημειώσεις Blueprint Gaps
- **Delete Account Cloud Function** (blueprint §§1308-1321): Η client-side υλοποίηση στο `auth_repository_impl.dart` διαγράφει Firestore (public + status) + Isar + Auth user, αλλά **δεν** κάνει storage cleanup, request anonymization, ή chat anonymization — θα χρειαστεί Cloud Function πριν την ενεργοποίηση chat/storage (Φάση 3). Επιβεβαιώθηκε Session 22. Δεν απαιτεί άμεση δράση.

## Shared Widgets & Utils (τρέχουσα κατάσταση)
- `shared/widgets/gradient_header.dart` — GradientHeader (gradient header με icon, title, subtitle, child)
- `shared/widgets/save_button.dart` — SaveButton (FilledButton with loading state)
- `shared/widgets/app_state_widget.dart` — ErrorView / LoadingView / EmptyView
- `shared/widgets/form_section.dart` — FormSection (card section)
- `shared/widgets/form_toggle.dart` — FormToggle (SwitchListTile)
- `shared/widgets/chip_selector.dart` — ChipSelector (ChoiceChip group)
- `shared/widgets/profile_card.dart` — ProfileCard (για search results)
- `shared/widgets/online_indicator.dart` — OnlineIndicator (πράσινο/γκρι κουκκίδα)
- `shared/widgets/consent_badge.dart` — ConsentBadge (χρησιμοποιεί ConsentActionConfig)
- `shared/utils/consent_action_config.dart` — ConsentActionConfig (centralized action→icon/color/label ιδιότητες)
- `core/l10n/l10n.dart` — L10n (locale detection, isGreek(), formatters)
- `core/theme/responsive_utils.dart` — ResponsiveUtils + ResponsiveBuilder + ResponsivePadding

## Φάσεις Υλοποίησης (από blueprint)
1. **Φάση 1 — Core & Privacy**: Isar schemas, Firebase init, Anonymous auth, Profile CRUD (local), PrivacySettings editor, ConsentLog, Publish/Unpublish, GPS flow, i18n, Theme, Delete account, Feature flags, Security Rules
2. **Φάση 2 — Discovery**: Firestore search, Filters UI, Results dashboard, PublicProfile view, Saved searches, Block/Report
3. **Φάση 3 — Communication**: Email/Phone verify, Request system, E2E chat, FCM push, Online presence, Rate limiting
4. **Φάση 4+**: Typesense, Video calls, AI matching, Groups, Verified badge, Premium, Web, Admin panel

## Κάθε νέο chat — υποχρεωτική ανάγνωση
1. Διάβασε το `nearme_blueprint.md` για να καταλάβεις την αρχιτεκτονική, τις αποφάσεις σχεδιασμού, και τι κάνουμε
2. Διάβασε το `oldsessions.md` για να δεις την πρόοδο και τι έγινε στο προηγούμενο session
