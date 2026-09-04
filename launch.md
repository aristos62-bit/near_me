# NearMe — Launch Readiness & Action Plan

> **Έκδοση:** 1.1.0+1 · **Schema:** v15 · **Firebase:** `nearme-eu` (eur3 / europe-west1) · **Τελευταία ενημέρωση:** 04 Σεπ 2026
> **Κατάσταση:** Φάσεις 1-3 λειτουργικές, B1-B7 FIXED ✅ (26/08-03/09), C1-C4 FIXED ✅ (02-03 Σεπ 2026), **C5 FIXED ✅ (03 Σεπ 2026)**, βάση unit tests 93/93 ✅ (04 Σεπ), moderation scaffolding (flag OFF), **C6 + M1-M4 FIXED ✅ (04 Σεπ 2026)**, tests 106/106 ✅

**Changelog:**
- **04 Σεπ 2026 — C6 + M1-M4 DONE:** Θέματα αξιοπιστίας δικτύου/δεδομένων pre-launch. C6 `withTimeout` SPoT (`lib/core/utils/timeouts.dart`) + `createChat` + `TimeoutException → chat/network-error` · M2 FCM background `Firebase.initializeApp()` · M3β reactions cap `<100` (rules) · M4 cursor fix (merged sort) + over-fetch ×2 σε `_geoSearch`/`searchNearby` · M3α server `expiresAt` (client remove + rules block + νέο CF `onRequestCreated`) · M1 banner dismiss (ConsumerStatefulWidget + `_dismissed`). **Deployed:** rules + 17 functions (συμπ. `onRequestCreated`) ✅. **Tests:** +13 (timeouts ×5, app_exception ×5, banner ×3) → **106/106** ✅.
- **04 Σεπ 2026 — Unit tests βάση ✅:** 57 νέα pure-utility tests σε 3 αρχεία (`test/shared/age_validation_test.dart` ×16, `test/features/chat/system_message_formatter_test.dart` ×21, `test/core/geohash_utils_test.dart` ×20) πάνω στα 36 του Session 259 → **`flutter test` 93/93** ✅. Κανένα runtime αρχείο δεν άλλαξε.
- **03 Σεπ 2026 — C5 DONE:** Cleanup `audit_log` + `invites` στο `deleteGroup` + διόρθωση bug >500 μηνυμάτων (pagination). SPoT helper `deleteChatSubcollection` (`firestore_cleanup.dart`) + refactor `clearMessages`/`_deleteChatForEveryone`. Βάση τεστ: +`fake_cloud_firestore` + `test/repositories/firestore_cleanup_test.dart` ×6 → `flutter test` 36/36 ✅. Σημείωση: `flutter pub add` παρέσυρε firebase bumps (firebase_core 4.14, cloud_firestore 6.9, firebase_auth 6.6 κλπ) — εντός range, κρατήθηκαν.
- **03 Σεπ 2026 — B7 DONE:** Αφαίρεση `firebase-analytics` dependency (`build.gradle.kts:74`) — 1 γραμμή, `firebase-bom`+`crashlytics` παραμένουν. Data Safety "Analytics: Not collected" ευθυγραμμίστηκε.
- **03 Σεπ 2026 — C2/C3/C4 DONE:**
  - **C2** Relabel E2E → "Encrypted (AES-256-GCM)" (`error_messages.dart:143` + `chat_screen.dart:132-135` `_showEncryptionInfo`).
  - **C3** Rate limit chat messages (30/1min) + requests (10/1h) — CFs deployed europe-west1, wired provider (`chat_provider.dart`) + repository (`request_repository_impl.dart`), client debounce `chat_input_bar.dart`, flag `rateLimit`, fail-open.
  - **C4** Group avatar crop+compress 512px jpg 85 via `image_cropper` στο `group_settings_screen.dart` (UI-layer, όχι repository).
- **02 Σεπ 2026 — C1 DONE:** CF `expireStalePresence` sweeper (5min TTL, europe-west1). Heartbeat 60→30s απορρίφθηκε (client TTL 120s ήδη καλύπτει).
- **30 Αυγ 2026 — B3+B4+B6 DONE:** iOS Info.plist privacy strings (`NSLocationWhenInUse/NSPhotoLibrary*/NSPhotoLibraryAdd`) + `FirebaseCrashlyticsCollectionEnabled=false` + `ITSAppUsesNonExemptEncryption=false` (Session 251).
- **30 Αυγ 2026 — B5 DONE:** hosting privacy.html/terms + Settings tile + Data Safety draft (Session 252).
- **26 Αυγ 2026 — B1+B2 DONE:** ApplicationId `com.example.near_me` → `gr.nearme.app` (Session 241) + Release signing upload-keystore.jks + R8 minify (Session 242).

---

## 1. Τι υπάρχει σήμερα (υπάρχον)

### 1.1 Φάση 1 — Core & Privacy — DONE ✅

| Τομέας | Αρχείο:γραμμή | Κατάσταση |
|---|---|---|
| Drift 7 tables + migrations v2→v15 | `lib/data/local/database.dart:15,36,39` | DONE — v15 `crashReportsEnabled`, v7 leak fix `ownerUid`, v14 SPoT reconciliation |
| DatabaseService singleton + tryInit | `lib/data/local/database_service.dart:12` | DONE |
| Firebase init idempotent + Crashlytics order | `lib/core/firebase/firebase_init.dart:5` + `lib/main.dart:36,43` | DONE |
| Anonymous → Email/Phone upgrade | `lib/features/auth/providers/auth_provider.dart:33,164` + `phone_verify_provider.dart:22` | DONE — `linkWithEmail` fallback, 6s `_withAuthTimeout` `auth_repository_impl.dart:193` |
| Router guards `canUserCommunicate` | `lib/core/router/app_router.dart:56` + `lib/repositories/auth_repository.dart:9` | DONE |
| Profile CRUD + Privacy 14 toggles | `lib/repositories/profile_repository_impl.dart:44,260` + `privacy_settings_table.dart:3` | DONE |
| Publish/Unpublish + CF geoHash | `profile_repository_impl.dart:306,478` + `functions/src/index.ts:801` | DONE — `geoHash` immutable client `firestore.rules:97` |
| ConsentLog + Delete Account | `lib/data/local/tables/consent_log_table.dart:3` + `delete_account_screen.dart:1` + `auth_repository_impl.dart:57` CF `deleteUserData` | DONE — 8-item warning card |
| Feature flags 26 | `lib/core/config/feature_flags.dart:1` | DONE |
| DebugConfig 30+ flags + gating | `lib/core/debug/debug_config.dart:1` | DONE — `crashlyticsForwardInDebug=false` |
| i18n 100% + responsive | `lib/core/l10n/l10n.dart:1` + `responsive_utils.dart` | DONE |
| Security Rules 448L + Storage 47L + 22 indexes | `firestore.rules:1` + `storage.rules:1` + `firestore.indexes.json:1` | DONE |
| Crashlytics GDPR gating | `AndroidManifest.xml:61` native OFF + `app_settings_provider.dart:89` purge `deleteUnsentReports` | DONE — iOS plist missing (B6) |

### 1.2 Φάση 2 — Discovery — DONE (2 κίτρινα) ⚠️

| Τομέας | Αρχείο:γραμμή | Κατάσταση |
|---|---|---|
| Search repo geo fan-out 9 cells | `lib/repositories/firestore_search_repository.dart:74` | DONE — `searchPrecision` `geohash_utils.dart:182` |
| Filters 15 πεδία + Saved searches | `lib/features/discovery/providers/search_provider.dart:1` + `saved_search_table.dart:4` | DONE |
| DiscoveryScreen + Filters + PublicProfile + ResultsGrid | `lib/features/discovery/screens/discovery_screen.dart:38` etc. | DONE — `resizeToAvoidBottomInset:false`, `GpsStrengthIndicator`, `SosHelpButton` |
| Block/Report (local + Firestore sync) | `lib/repositories/block_repository_impl.dart:19` + `report_repository_impl.dart:13` + CF `onReportCreated:208` | DONE — search exclusion `search_provider.dart:72` |
| GlobalConnectivityBanner | `lib/shared/widgets/global_connectivity_banner.dart:1` + `lib/main.dart:611` Stack | DONE — Positioned `viewPadding.top`, leaf ConsumerWidget |
| Rate limit search 30/5min | `functions/src/index.ts:856` + `search_provider.dart:146` 4s fail-open `unawaited` | DONE — exemplar |

**Κίτρινα Φ2:**
- **F2-1** Pagination cursor/hasMore σε raw `firestore_search_repository.dart:161,235` — hasMore σε raw len, cursor από πρώτο shard. Με αυστηρά φίλτρα → endless spinner.
- **F2-2** Block δεν κόβει direct read `firestore.rules:82` — μόνο search exclusion. Σκόπιμο per spec ("will not appear in search") αλλά όχι hard invisibility.

### 1.3 Φάση 3 — Communication — PARTIAL (1 blocker: C1) ⚠️

| Τομέας | Αρχείο:γραμμή | Κατάσταση |
|---|---|---|
| 1-1 + Group chat (max 10) | `lib/repositories/chat_repository_impl.dart:69` + `group_chat_mixin.dart:262` | DONE — `participantPair`, `participantRoles` |
| Text/System/Image/Gif/Audio/Video (6 τύποι) | `lib/features/chat/widgets/message_bubble/message_bubble.dart:58` + `chat_input_bar.dart:235` | DONE — `stripExif` σε chat image `253`, 30s/50MB limits `310,314` |
| Mentions/Reactions/Reply/Edit/Delete | `chat_repository_message_actions.dart:10` + `mention_service` | DONE — edit 15m window rules `firestore.rules:290` |
| Requests send/respond/expire 48h | `lib/repositories/request_repository_impl.dart:30` + CF `expireStaleRequests:1125` | DONE |
| FCM push + suppression | `lib/core/notifications/fcm_service.dart:48` + `main.dart:193` | PARTIAL — βλ. MKT-7 |
| Presence 60s heartbeat | `lib/core/services/presence_service.dart:15` | PARTIAL — stale (C1) |
| Storage timeouts 15/30s | `lib/core/utils/storage_helpers.dart:9` | DONE — Timer+Completer για `putFile` |
| Message expiry + pagination 50 | `lib/repositories/chat_repository_impl.dart:392` + `chat_provider.dart:76` | DONE |

**Εκκρεμεί (Φ3):**
- **C1** Presence stale `presence_service.dart:81` — 60s heartbeat, όχι `onDisconnect`, μένει `isOnline:true` μετά από crash. (εκκρεμεί)

*(C2 E2E claim → relabel ✅ 03/09 · C3 rate limit ✅ 03/09 — λύθηκαν, βλ. Phase B παρακάτω.)*

### 1.4 Γενικά — Build/Store

| Τομέας | Κατάσταση |
|---|---|
| `pubspec.yaml:4` version 1.1.0+1, 33 deps, `flutter_launcher_icons` | OK |
| `android/app/build.gradle.kts:10` namespace `gr.nearme.app` | **FIXED B1** — Session 241 |
| `build.gradle.kts:30` release signing + R8 | **FIXED B2** — Session 242 |
| `AndroidManifest.xml:2` permissions FINE/COARSE/POST_NOTIFICATIONS/RECORD_AUDIO/CAMERA/BIOMETRIC | OK — disclosures needed |
| `ios/Runner/Info.plist:9` `Κοντά μου` + `project.pbxproj:385` `com.example.nearMe` | **BLOCKER B1/B3/B4** |
| `firebase.json:21` + `hosting` + `.firebaserc` + `eur3` | **FIXED B5** — `hosting/privacy.html` + `https://nearme-eu.web.app/privacy` deployed 30/08/2026 |
| `launch_background.xml` white placeholder, custom splash 3s `main.dart:172` | WARNING |
| `error_messages.dart:1` 210+ bilingual, 60 call-sites | DONE |
| `flutter analyze` clean | OK |

---

## 2. Τι λείπει / Τι πρέπει να γίνει

### 2.1 Hard Blockers — Κόβουν upload (must fix) — ✅ DONE (B1-B7)

#### B1 — Placeholder ApplicationId / BundleId — FIXED ✅ (Session 241, 26 Αυγ 2026)

**Υπάρχει:** `android/app/build.gradle.kts:10` `namespace "com.example.near_me"`, `L21` `applicationId "com.example.near_me"` + `L20 TODO`, `android/app/google-services.json:12` `com.example.near_me`, `ios/project.pbxproj:385,564,586` `com.example.nearMe` (case mismatch), `ios/Runner/GoogleService-Info.plist:12` `com.example.nearMe`, `Info.plist:9` `CFBundleDisplayName Κοντά μου` vs `strings.xml:3` `NearMe`.

**Πρόβλημα:** Play Console + App Store Connect απορρίπτουν `com.example.*`. Το ID είναι immutable μετά το πρώτο upload.

**Προτάσεις:**

1. **Επιλογή ID:** `com.nearme.eu` (προτείνεται — ταιριάζει `nearme-eu` project) ή `app.nearme.eu` ή `gr.nearme.app`. Έλεγχος διαθεσιμότητας σε Play Console → Create app → package name check. Για iOS ίδιο string αλλά lowercase `com.nearme.eu` (όχι `nearMe`).
2. **Βήματα Android:**
   - `android/app/build.gradle.kts:10` → `namespace = "com.nearme.eu"`
   - `L21` → `applicationId = "com.nearme.eu"` + διαγραφή TODO L20
   - `android/app/src/main/res/values/strings.xml:3` → επιβεβαίωση `NearMe` ή `Κοντά μου`
   - Firebase Console → Project Settings → Add Android app → package `com.nearme.eu` → SHA-1/SHA-256 (από `keytool -list -v -keystore upload-keystore.jks`) → Download νέο `google-services.json` → αντικατάσταση `android/app/google-services.json`
   - `firebase.json` δεν χρειάζεται αλλαγή (projectId μένει `nearme-eu`)
3. **Βήματα iOS:**
   - Xcode → Runner → Signing & Capabilities → Bundle Identifier → `com.nearme.eu`
   - `ios/Runner.xcodeproj/project.pbxproj:385,564,586` θα ενημερωθεί αυτόματα (Debug/Release/Profile)
   - Firebase Console → Add iOS app → bundle `com.nearme.eu` → Download `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`
   - `ios/Runner/Info.plist:18` `CFBundleName` → `NearMe` (όχι `near_me`)
   - Έλεγχος `macos/Runner/Info.plist` ίδιο bundle αν υποστηρίζεται macOS
4. **Firestore/Storage rules:** κανένα hardcoded package check — safe.
5. **Επαλήθευση:** `flutter clean && flutter pub get && flutter analyze && flutter build apk --release` (θα αποτύχει μέχρι B2).

**Εναλλακτική:** Αν το `com.nearme.eu` είναι πιασμένο, δοκιμάστε `eu.nearme.app` — κρατήστε `eu` για GDPR signal.

---

#### B2 — Debug Signing σε Release — FIXED ✅ (Session 242, 26 Αυγ 2026)

**Υπάρχει:** `android/app/build.gradle.kts:30-34` `signingConfig = signingConfigs.getByName("debug")` + `L32 TODO`.

**Πρόβλημα:** Play Console: "You uploaded an APK signed with debug key" — απόρριψη.

**Προτάσεις:**

1. **Δημιουργία keystore (μία φορά):**
   ```powershell
   keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 4096 -validity 9125 -storetype JKS
   # CN=NearMe, OU=Mobile, O=NearMe EU, L=Athens, ST=Attica, C=GR
   ```
   Αποθήκευση εκτός repo: `C:\Users\Vaggelis\keys\upload-keystore.jks` + backup σε 1Password/Drive κρυπτογραφημένο.

2. **Δημιουργία `android/key.properties` (gitignore!):**
   ```properties
   storeFile=C:/Users/Vaggelis/keys/upload-keystore.jks
   storePassword=***
   keyAlias=upload
   keyPassword=***
   ```
   Προσθήκη στο `.gitignore`:
   ```
   android/key.properties
   android/app/upload-keystore.jks
   *.jks
   *.keystore
   ```

3. **Ενημέρωση `android/app/build.gradle.kts`:**
   ```kotlin
   val keystoreProperties = java.util.Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
   }
   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String?
               keyPassword = keystoreProperties["keyPassword"] as String?
               storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
               storePassword = keystoreProperties["storePassword"] as String?
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
               isMinifyEnabled = true
               isShrinkResources = true
               proguardFiles(
                   getDefaultProguardFile("proguard-android-optimize.txt"),
                   "proguard-rules.pro"
               )
           }
       }
   }
   ```

4. **Play App Signing:** Στο Play Console → Setup → App signing → επιλέξτε "Let Google manage" (προτείνεται) ή "Provide upload key". Ανεβάστε **μόνο** το upload key, όχι το app signing key αν το διαχειρίζεται η Google.

5. **Επαλήθευση:** `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` → `jarsigner -verify` + `keytool -printcert`.

**Εναλλακτική (CI):** Αν χρησιμοποιείτε GitHub Actions, αποθηκεύστε keystore ως base64 secret `ANDROID_KEYSTORE_BASE64` + `KEY_PROPERTIES` secret, decode στο workflow.

---

#### B3 — iOS Missing Privacy Strings (crash + reject) — FIXED ✅ (Session 251, 30 Αυγ 2026)

**Υπάρχει:** `ios/Runner/Info.plist:27` `NSFaceIDUsageDescription`, `L29` `NSMicrophoneUsageDescription`, `L31` `NSCameraUsageDescription`. **Λείπουν:** `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`.

**Πρόβλημα:** `geolocator ^14.0.2` + `image_picker ^1.2.2` crash χωρίς description. App Review reject.

**Προτάσεις:**

1. **Προσθήκη στο `ios/Runner/Info.plist` (πριν το `</dict>`):**
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Η τοποθεσία χρησιμοποιείται για εύρεση κοντινών προφίλ και εμφανίζεται μόνο με τη συγκατάθεσή σας. / Location is used to find nearby profiles and shown only with your consent.</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <!-- εναλλακτικά bilingual: κρατήστε μία γραμμή EL/EN όπως παραπάνω -->
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Επιλογή φωτογραφίας προφίλ και αποστολή εικόνων στο chat. / Pick profile photo and send images in chat.</string>
   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>Αποθήκευση φωτογραφιών. / Save photos.</string>
   ```

2. **Εναλλακτική localization:** Δημιουργία `ios/Runner/el.lproj/InfoPlist.strings` + `en.lproj/InfoPlist.strings` με ξεχωριστές μεταφράσεις. Προτείνεται για v1.1, όχι απαραίτητο για launch.

3. **Έλεγχος `NSLocationAlwaysUsageDescription`:** ΜΗΝ προσθέσετε — δεν χρησιμοποιείτε background location `AndroidManifest.xml` σωστά χωρίς `ACCESS_BACKGROUND_LOCATION`. Αν προστεθεί, Play/App Store ζητούν justification video.

4. **Επαλήθευση:** `flutter run -d ios` → trigger `LocationService.getCurrentLocation()` → dialog εμφανίζεται με το string. Χωρίς το key → crash log `This app has crashed because it attempted to access privacy-sensitive data without a usage description`.

---

#### B4 — Missing `ITSAppUsesNonExemptEncryption` — FIXED ✅ (Info.plist:41-42, ίσως μέρος Session 251)

**Υπάρχει:** `pubspec.yaml:43` `encrypt ^5.0.3` AES-256 + `crypto ^3.0.6` SHA-256. Δεν δηλώνεται στο `Info.plist`.

**Πρόβλημα:** App Store Connect → TestFlight → Export Compliance questionnaire block. Χωρίς το key, κάθε upload ζητά manual compliance.

**Προτάσεις:**

1. **Επιλογή Α — Exempt (προτείνεται):** Η χρήση AES-256 για **data-at-rest / chat encryption** με κλειδί που παράγεται στη συσκευή θεωρείται exempt (Category 5 Part 2, Note 4). Προσθήκη:
   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <false/>
   ```
   στο `ios/Runner/Info.plist`.

2. **Επιλογή Β — Non-exempt:** Αν χρησιμοποιείτε κρυπτογράφηση για **data-in-transit πέραν του TLS** με custom key exchange, δηλώστε `<true/>` και υποβάλετε ERN (Encryption Registration) στο BIS. Δεν χρειάζεται για το τρέχον `encrypt` + `flutter_secure_storage`.

3. **Εναλλακτική:** Δήλωση μέσω App Store Connect web UI (App Information → Encryption). Το plist key το παρακάμπτει.

4. **Επαλήθευση:** Upload TestFlight → δεν εμφανίζεται compliance dialog.

---

#### B5 — Privacy Policy — FIXED ✅ (30 Αυγ 2026)

**Υπήρχε:** `grep privacy_policy` 0, `glob **/*privacy*` μόνο `privacy_settings_table.dart`, `firebase.json:1` χωρίς `hosting`, `settings_screen.dart:139` χωρίς tile.

**Fix:** `firebase.json:21` hosting `public:hosting cleanUrls` + `hosting/privacy.html` (10.5KB GDPR, 4 precisions city/neighborhood/street(~150m)/hidden 3/5/7/0, `soc.near.app@gmail.com`, eur3/europe-west1, `deleteUserData:563`) + `hosting/terms.html` + `AppConfig.privacyPolicyUrl` + `settings/link-open-failed` + `SettingsScreen:211` tile (`ConnectivityGuard.ensure` + `launchUrl externalApplication`) → `firebase deploy --only hosting --project nearme-eu` → `https://nearme-eu.web.app/privacy` (200) + `https://nearme-eu.firebaseapp.com/privacy`. `flutter analyze` clean. Backup `backups/B5_privacy_20260830/`.

**Υλοποίηση (30/08/2026):**

1. `firebase.json:21` → `hosting {public:hosting, cleanUrls:true, Cache-Control:3600}` + `hosting/privacy.html` 10.5KB + `hosting/terms.html` 1.1KB → `firebase deploy --only hosting --project nearme-eu` → `https://nearme-eu.web.app/privacy` (200) + `https://nearme-eu.firebaseapp.com/privacy`

2. **Privacy Policy GDPR** — 4 precisions `city(3)/neighborhood(5)/street(7 ~150m)/hidden(0)` `privacy_editor_screen.dart:201` + `index.ts:787`, ποτέ raw lat/lng, OS geocoding `placemarkFromCoordinates` + Nominatim, `avatars/photos/chat_media/group_avatars`, AES-256-GCM `encryption_utils.dart:25`, `fcm_tokens`, Crashlytics OFF `AndroidManifest.xml:62` + `Info.plist`. Controller `soc.near.app@gmail.com` (SPoT `AppConfig.privacyContactEmail`), eur3/europe-west1, `deleteUserData:563` (10+ buckets), Rights, HDPA dpa.gr, Last updated 30 Aug 2026.

3. **In-app tile** `settings_screen.dart:211` (visible και σε anonymous, μετά Diagnostics) → `AppConfig.privacyPolicyUrl` + `ConnectivityGuard.ensure` + `launchUrl(externalApplication)` + `settings/link-open-failed` `error_messages.dart:302` + `DebugConfig.uiInteraction/warn`. `url_launcher ^6.3.2` `pubspec.yaml:72` reuse.

4. **Store Console:** Play → App content → Privacy Policy + App Store → App Information → paste `https://nearme-eu.web.app/privacy` (Data Safety draft: Location Approximate / Photos&Videos / messages encrypted YES / FCM token / Crash opt-in / Analytics Not collected).

---

#### B6 — iOS Crashlytics Collection ON πριν το Consent — FIXED ✅ (Session 251, 30 Αυγ 2026)

**Υπάρχει:** `android/app/src/main/AndroidManifest.xml:61` `firebase_crashlytics_collection_enabled=false` ✅. `ios/Runner/Info.plist` **χωρίς** αντίστοιχο key. `lib/main.dart:302` `_applyCrashConsent` + `app_settings_provider.dart:89` gating σωστά, αλλά iOS native συλλέγει πριν το Dart.

**Πρόβλημα:** GDPR παράβαση σε iOS — window πριν το `_applyCrashConsent`.

**Προτάσεις:**

1. **Προσθήκη στο `ios/Runner/Info.plist`:**
   ```xml
   <key>FirebaseCrashlyticsCollectionEnabled</key>
   <false/>
   ```
   (σημείωση: key είναι `FirebaseCrashlyticsCollectionEnabled` — όχι `firebase_crashlytics_collection_enabled` όπως στο Android)

2. **Επαλήθευση:** Cold start με consent OFF → `DebugConfig.log` `main.dart:307` `Crashlytics collection=false` + `deleteUnsentReports` — iOS logs δεν δείχνουν upload.

3. **Εναλλακτική:** Αν θέλετε opt-out αντί για opt-in (όχι GDPR), αφήστε το true — αλλά τότε Data Safety δηλώνει "Collected by default".

---

### 2.2 High Priority — Διορθώστε πριν το public launch (C1-C5 ✅ DONE, μένει C6)

#### C1 — Presence Stale (60s heartbeat, όχι onDisconnect) — FIXED ✅ (Session 255, 2 Σεπ 2026)

**Υπάρχει:** `lib/core/services/presence_service.dart:26` `_start` → `Timer.periodic 60s` `L81`, `setOffline` `L84` με `Future.wait` δύο docs, `main.dart:193` `builder Stack` lifecycle.

**Πρόβλημα:** Αν crash/battery kill, `setOffline` δεν καλείται — `isOnline:true` μένει για πάντα. Play "Deceptive behavior" αν δείχνετε ψευδώς online. Firestore δεν έχει `onDisconnect` (μόνο RTDB).

**Προτάσεις (3 επιλογές, προτείνεται 1+2):**

1. **Επιλογή 1 — CF TTL sweeper (προτείνεται, 30 λεπτά):**
   ```typescript
   // functions/src/index.ts — νέο scheduled
   export const expireStalePresence = onSchedule("every 5 minutes", async () => {
     const cutoff = Date.now() - 5 * 60 * 1000; // 5 min
     const snap = await admin.firestore().collectionGroup("status")
       .where("isOnline", "==", true).get();
     for (const doc of snap.docs) {
       const lastSeen = doc.data().lastSeen?.toMillis?.() ?? 0;
       if (lastSeen < cutoff) {
         await doc.ref.update({ isOnline: false });
         const uid = doc.ref.parent.parent!.id;
         await admin.firestore().doc(`users/${uid}/public/profile`).set({ isOnline: false }, { merge: true });
       }
     }
   });
   ```
   Προσθήκη `firestore.indexes.json` για `status.isOnline + lastSeen` αν χρειάζεται.

2. **Επιλογή 2 — Μείωση heartbeat 60s → 30s + `lastSeen` TTL check στο UI:**
   - `presence_service.dart:81` → `Duration(seconds: 30)`
   - `lib/features/discovery/providers/status_provider.dart:7` → `streamUserStatus` ήδη TTL 120s `profile_repository_impl.dart:739` — μειώστε σε 90s
   - UI `OnlineIndicator` `lib/shared/widgets/online_indicator.dart:1` → δείχνει online μόνο αν `isOnline==true && now - lastSeen < 90s`

3. **Επιλογή 3 — RTDB onDisconnect (βαρύτερη):**
   - Προσθήκη `firebase_database` dependency, `presence_service.dart` γράφει σε RTDB `status/{uid}` με `onDisconnect().set({isOnline:false})` + Cloud Function RTDB→Firestore mirror. Πιο αξιόπιστο αλλά +1 product, +κόστος.

**Επαλήθευση:** Kill app → 5 λεπτά → `users/{uid}/status/status` → `isOnline:false`.

**✅ Εφαρμόστηκε Επιλογή 1 (CF sweeper) — Session 255:**
- `functions/src/index.ts:1173-1204` — CF `expireStalePresence` (europe-west1, `pubsub.schedule('*/5 * * * *')`, `collectionGroup('status').where('isOnline','==',true)`, 5min cutoff, batch update status+public).
- Single-field auto-index (Firestore default) — απορρίφθηκε ρητός index.
- Heartbeat 60→30s **απορρίφθηκε** (client TTL 120s ήδη καλύπτει UI, 2× writes χωρίς όφελος).
- 0 Dart αλλαγές → 0 rebuild storm risk.

---

#### C2 — E2E Claim Ψευδές — FIXED ✅ (03 Σεπ 2026)

**Υπάρχει:** `lib/core/utils/encryption_utils.dart:25` `deriveKey = SHA256('near_me_e2e_key_'+chatId)`, `getKeyOrDerive:62`, `encryptMessage:88` `AES-GCM IV 12 bytes`, `chat_repository_impl.dart:255,341` encrypt/decrypt. Key στο `flutter_secure_storage` αλλά fallback derivable.

**Πρόβλημα:** Οποιοσδήποτε γνωρίζει `chatId` (via `participants arrayContains` read) μπορεί να παράγει ίδιο key offline. Play Data Safety "End-to-end encrypted" = ψευδής δήλωση → policy strike. Apple privacy questionnaire απορρίπτει.

**✅ Εφαρμόστηκε Επιλογή 1 (relabel) — `error_messages.dart:143` + `chat_screen.dart:132-135` `_showEncryptionInfo`:** marketing claim άλλαξε σε "Encrypted (AES-256-GCM)" (transit TLS / at rest), όχι "End-to-end". Play Data Safety πρέπει να δηλώνει "data encrypted in transit YES", όχι "end-to-end".

**Προτάσεις (3 επίπεδα):**

1. **Επιλογή 1 — Αλλαγή marketing claim (άμεσο, 5 λεπτά, προτείνεται για v1):**
   - Αφαιρέστε "E2E" από description, screenshots, `chat_screen.dart:125` E2E banner, Data Safety.
   - Αντικαταστήστε με: "Messages encrypted in transit (TLS) and at rest (AES-256-GCM)" — αληθές.
   - `lib/core/l10n/l10n.dart` + `chat_screen.dart:125` `_showE2EInfo` → αλλαγή κειμένου σε "Encrypted (AES-256)" όχι "End-to-end".

2. **Επιλογή 2 — Per-chat random key + Firestore wrap (1-2 μέρες):**
   - `createChat:141` → `generateKey = 256-bit random` (όχι derive), `storeKey` local + Firestore `chats/{id}.wrappedKeys: {uid: encryptWithUserPublicKey(randomKey)}` — αλλά χρειάζεται per-user public key (π.χ. `encrypt` RSA ή `crypto` ECDH). Πολύπλοκο για v1.

3. **Επιλογή 3 — Signal-style ECDH + SecureStorage only (1 εβδομάδα):**
   - Κάθε χρήστης δημιουργεί `ECDH keypair` στο `flutter_secure_storage` κατά το `signUp` (`auth_repository_impl.dart:214`).
   - `createChat` → `sharedSecret = ECDH(myPrivate, otherPublic)` → `key = HKDF(sharedSecret, chatId)` → `storeKey` (όχι derivable από chatId μόνο).
   - Χρειάζεται `cryptography` package + public key publish σε `users/{uid}/public/keys`.

**Σύσταση:** Για launch v1 → Επιλογή 1 (relabel) — **✅ ΕΦΑΡΜΟΣΘΗΚΕ**. Για v1.2 → Επιλογή 3 (πραγματικό ECDH).

---

#### C3 — Καμία Rate Limit σε Chat/Messages/Requests — FIXED ✅ (03 Σεπ 2026, deployed)

**Υπήρχε:** `functions/src/index.ts:11` `SEARCH_RATE_LIMIT 30/5min` μόνο για search. `firestore.rules:268` `allow create messages if isParticipant` χωρίς count.

**Πρόβλημα:** Spam flood → Firestore bill shock (50 msgs × 1000 users), Play Spam policy.

**✅ Εφαρμόστηκε (πλήρες — server + client + deploy):**
- **Server (deployed ✓):** `checkMessageRateLimit` (30 msgs/1min → `users/{uid}/rateLimits/messages`) + `checkRequestRateLimit` (10 req/1h → `users/{uid}/rateLimits/requests`) transaction fail-open + `deleteUserData` cleanup + constants `MESSAGE_RATE_*`/`REQUEST_RATE_*` στο `functions/src/index.ts`.
- **Client:** flag `rateLimit` `debug_config.dart`· key `chat/message-rate-limited` `error_messages.dart`· helper `_checkMessageRateLimit` wired σε `sendMessage` + `sendMediaMessage` στο `chat_provider.dart` (μετά `_checkOnline`, πριν `state=loading`)· `_checkRequestRateLimit` στο `request_repository_impl.dart` (πριν pre-checks). Fail-open παντού (offline→true, 4s timeout→true, CF error→true· μόνο `resource-exhausted` μπλοκάρει).
- **Client debounce:** `chat_input_bar.dart` `_lastSendAt` guard <1s στο `_send()`.
- **Σημείωση topology:** chat → provider-level (`ChatActions`, γιατί `sendMediaMessage` κάνει expensive storage/Vision uploads πριν το batch)· requests → repository-level (`sendRequest`). `editMessage` σκόπιμα ΔΕΝ rate-limit (δεν κάνει νέο upload).

**Προτάσεις:**

1. **CF rate limiter για messages (αντιγραφή search pattern, 1 ώρα):**
   ```typescript
   const MSG_RATE_LIMIT = 30; // 30 msgs / 1 min per uid
   const MSG_WINDOW_MS = 60_000;
   export const checkMessageRateLimit = onCall({ region: REGION }, async (req) => {
     const uid = req.auth!.uid;
     // ίδιο transaction με search: read users/{uid}/rateLimits/messages, check window, increment, throw resource-exhausted
   });
   ```
   Κλήση πριν από `sendMessage` `chat_repository_impl.dart:203`:
   ```dart
   final cf = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('checkMessageRateLimit');
   await cf.call().timeout(Duration(seconds: 4), onTimeout: () => true); // fail-open
   ```

2. **Firestore rules fallback (χωρίς CF):**
   ```javascript
   // firestore.rules — προσθήκη helper
   function isNotRateLimited() {
     return !exists(/databases/$(database)/documents/users/$(request.auth.uid)/rateLimits/messages)
       || get(/databases/$(database)/documents/users/$(request.auth.uid)/rateLimits/messages).data.count < 30;
   }
   // messages create: && isNotRateLimited()
   ```
   Αλλά rules `get()` κοστίζει — CF προτείνεται.

3. **Client debounce:**
   - `lib/features/chat/widgets/chat_input_bar.dart:118` `_send` → `if (_lastSend != null && DateTime.now().difference(_lastSend!) < Duration(seconds: 1)) return;`

4. **Requests rate limit:** Ίδιο pattern — 10 requests / hour per uid.

**Επαλήθευση:** Spam 40 msgs / 1 min → 31st → `resource-exhausted` + `AppException` → `ErrorMessages.get('chat/rate-limited')`.

---

#### C4 — Group Avatar EXIF Leak — FIXED ✅ (03 Σεπ 2026)

**Υπήρχε:** `lib/features/chat/widgets/chat_input_bar.dart:253` `stripExif` OK για chat image. `lib/repositories/group_chat_mixin.dart:750` `readAsBytes` χωρίς strip για group avatar.

**Πρόβλημα:** GPS metadata σε group avatar → privacy leak (Play Data Safety).

**✅ Εφαρμόστηκε (UI-layer, όχι repository):** Ο cropper χρειάζεται πλατφόρμα → `group_settings_screen.dart` `_pickAndUploadAvatar`: μεταξύ picker και `updateGroupAvatar(chatId, cropped)` μπαίνει `ImageCropper.platform.cropImage(maxWidth/maxHeight:512, compressFormat: ImageCompressFormat.jpg, compressQuality:85)` → `CroppedFile` συμβατό με `(image as dynamic).readAsBytes()`. Επαναχρησιμοποίηση του υπάρχοντος `image_cropper` pattern (profile/chat), όχι νέος helper. +1 `DebugConfig.log(storageUpload)`. `group_chat_mixin.dart` +1 debug log bytes μετά strip (`N → M bytes after strip`).

**Αρχική πρόταση (για ιστορικό):**
```dart
// group_chat_mixin.dart:750 — πριν το uploadBytesWithTimeout
final stripped = await ImageUtils.stripExif(avatarBytes); // ή flutter_image_compress
await StorageHelpers.uploadBytesWithTimeout(..., stripped);
```
Σημείωση: `ImageUtils.stripExif` = `compressWithList(quality:100)` → ΔΕΝ downscale (API μόνο `minWidth/minHeight`). Γι' αυτό χρησιμοποιήθηκε το ImageCropper (downscale 512px) αντί για strip-only.

**Επαλήθευση:** Upload avatar με GPS → download → `exiftool` → no GPS.

---

#### C5 — Audit Log Leak μετά από deleteGroup — ✅ DONE (Session 259, 03 Σεπ 2026)

**Υπάρχει:** `lib/repositories/group_chat_mixin.dart` `deleteGroup` → deletes `messages` + `chats` doc, αλλά **δεν** καθάριζε τα subcollections `audit_log` και `invites`, και είχε pre-existing bug: τα messages διαγράφονταν σε ΕΝΑ batch χωρίς pagination → αποτυχία σε ομάδες με >500 μηνύματα.

**Πρόβλημα:** Orphan docs χρεώνονται, GDPR retention.

**Λύση (υλοποιημένη):**
- Νέο SPoT helper `deleteChatSubcollection` σε `lib/core/utils/firestore_cleanup.dart` (batching 500, flag `fatal`, debug flags).
- `deleteGroup` → `deleteChatSubcollection(audit_log)` + `(invites)` + `(messages)` (non-fatal) → `deleteAllChatMedia` → parent `chats/{chatId}` delete **τελευταίο**.
- Refactor DRY: `clearMessages` + `_deleteChatForEveryone` χρησιμοποιούν τον ίδιο helper.
- **Τεστ:** +`fake_cloud_firestore` dev dependency, `test/repositories/firestore_cleanup_test.dart` ×6 · +57 pure-utility tests (Session 260) · +13 tests C6/M1-M4 (Session 261) → `flutter analyze` clean, `flutter test` **106/106** ✅.

---

#### C6 — FirestoreService Stub

**Υπάρχει:** `lib/data/remote/firestore_service.dart:1` `class FirestoreService { const FirestoreService(); }` — αχρησιμοποίητο. Όλα via `FirebaseFirestore.instance` direct, χωρίς central timeout.

**Πρόβλημα:** `chat_repository_impl.dart:103` parallel profile fetch χωρίς timeout → zombie socket 45s (search έχει 4s `search_provider.dart:175`).

**Πρόταση:**

1. **Επιλογή Α — Extend FirestoreService (προτείνεται):**
   ```dart
   class FirestoreService {
     static Future<T> withTimeout<T>(Future<T> f, {Duration timeout = const Duration(seconds: 8)}) =>
       f.timeout(timeout, onTimeout: () => throw TimeoutException('Firestore timeout'));
   }
   ```
   Χρήση: `await FirestoreService.withTimeout(Future.wait([profileFetch, blockCheck]))`

2. **Επιλογή Β — Per-call timeout:** Προσθήκη `.timeout(Duration(seconds: 8))` σε κάθε `FirebaseFirestore.instance` call — verbose.

---

### 2.3 Medium Priority — Warnings (μπορούν post-launch αλλά καλό πριν)

#### M1 — GlobalConnectivityBanner OK no-op

**Υπάρχει:** `lib/shared/widgets/global_connectivity_banner.dart:38` `onPressed: (){}`.

**Προτάσεις:**
- Επιλογή A: `onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner()` (dismiss)
- Επιλογή B: `onPressed: () => AppSettings.openWirelessSettings()` (android) / `openAppSettings` (iOS) via `geolocator` permission helper
- Επιλογή C: Αφαίρεση `actions` εντελώς — banner auto-hide όταν `ONLINE` (ήδη κάνει).

#### M2 — FCM Gaps

**Υπάρχει:** `lib/core/notifications/fcm_service.dart:98` `setBadge` iOS only, `L184` `_onBackgroundHandler` χωρίς `Firebase.initializeApp`, `lib/main.dart:473` foreground snackbar only.

**Προτάσεις:**
- `fcm_service.dart:184` → `await Firebase.initializeApp();` στο background isolate
- `98` → προσθήκη `flutter_app_badger` για Android badge ή αφαίρεση badge logic
- Foreground: προσθήκη `flutter_local_notifications` channel `high_importance` για heads-up banner (προαιρετικό — snackbar αποδεκτό για v1)

#### M3 — Firestore Notes

**Υπάρχει:** `request_repository_impl.dart:80` `expiresAt` client-controlled, `firestore.rules:295` `reactions` unbounded, `chat_repository_impl.dart:1169` `listAll` 1k limit.

**Προτάσεις:**
- `expiresAt` → CF `onCreate` override σε `now + 48h` (server authoritative)
- `reactions` → rules `reactions.size() < 100`
- `listAll` → paginated `list(maxResults: 1000, pageToken: nextPageToken)` loop

#### M4 — Pagination F2-1

**Προτάσεις:**
- Over-fetch: `effectiveLimit * 2` + post-filter loop μέχρι `hasMore` post-filter
- Cursor: `cursorOut` από last doc του **merged sorted** list (όχι first shard) — `allDocs.sort((a,b)=>a.geoHash.compareTo(b.geoHash))` + last

#### M5 — Saved Search Center Re-anchoring

**Υπάρχει:** `lib/repositories/saved_search_repository.dart:80` store `city/country + radius` χωρίς lat/lng. `saved_search_provider.dart:54` apply → current GPS center.

**Πρόταση:** UX hint "Αναζήτηση κοντά στην τρέχουσα τοποθεσία" ή migration `savedLat/Lng` (v16).

---

### 2.4 Low Priority — Polish (v1.1)

| Θέμα | Αρχείο:γραμμή | Πρόταση |
|---|---|---|
| Diagnostics logs σε prod | `lib/features/chat/screens/chat_list_screen.dart:72` `LayoutBuilder REBUILT` | Τυλίξτε σε `if (DebugConfig.debugMode)` ή `DebugConfig.log` ήδη gated — OK, αλλά string alloc |
| Dead video props | `lib/features/chat/widgets/message_bubble/video_message_bubble.dart:46` TODO | Διαγραφή `videoPlayer/onPlayVideo/isLoadingUrl` — use `videoPlaybackProvider` |
| `anonymous_home_screen.dart:4` placeholder | `lib/features/auth/screens/anonymous_home_screen.dart:4` | Διαγραφή — χρησιμοποιείται `anonymous_info_screen` |
| Splash 3s + white launch | `lib/main.dart:172` + `launch_background.xml:1` | Μείωση σε 1.5s + `flutter_native_splash: ^2.4.0` με `image: assets/icons/near_me.png` |
| `web/manifest.json:8` default | `web/manifest.json:8` | `"NearMe — Privacy-first local discovery"` + `background_color` align |
| `CFBundleName near_me` | `ios/Runner/Info.plist:18` | `NearMe` |
| Analytics dep | `android/app/build.gradle.kts:74` | **DONE** ✅ — αφαιρέθηκε (Session 258, 03/09) |
| ProGuard | `build.gradle.kts:30` | `isMinifyEnabled true` + `proguard-rules.pro` (βλ. B2) |
| `TODO chat_repository.dart:108` domain model | `lib/repositories/chat_repository.dart:108` | Replace `DocumentSnapshot` με `Chat` model — tech debt |

---

## 3. Προτεινόμενο Roadmap

### Phase A — Store Blockers — ✅ DONE (B1-B7)

```
[x] B1  ApplicationId → gr.nearme.app + regenerate Firebase configs   ✅ DONE S241
[x] B2  Keystore + release signing + R8 minify                        ✅ DONE S242
[x] B3  Info.plist NSLocation/Photo strings                            ✅ DONE S251
[x] B4  ITSAppUsesNonExemptEncryption=false                            ✅ DONE (Info.plist:41)
[x] B5  Hosting privacy.html + Settings tile + Data Safety             ✅ DONE S252
[x] B6  FirebaseCrashlyticsCollectionEnabled=false (iOS)               ✅ DONE S251
[x] B7  Remove firebase-analytics line 74                      ✅ DONE S258 (03/09)
[ ]     flutter clean → pub get → build_runner → analyze → build appbundle --obfuscate --split-debug-info
```

### Phase B — High Fixes — ✅ DONE (C1-C5), μένει C6

```
[x] C1  CF expireStalePresence + heartbeat 30s          ✅ DONE S255 (sweeper only, heartbeat rejected)
[x] C2  Relabel E2E → "Encrypted" (5 min) — proper ECDH για v1.2   ✅ DONE S257
[x] C3  CF checkMessageRateLimit (αντιγραφή search)     ✅ DONE S257 (deployed)
[x] C4  stripExif σε group avatar                       ✅ DONE S257
[x] C5  audit_log + invites delete σε deleteGroup (+bug>500) ✅ DONE S259 + τεστ
[ ] C6  FirestoreService.withTimeout                    (εκκρεμεί)
```

### Phase C — Medium (1 μέρα) — NICE

```
[ ] M1  Banner dismiss
[ ] M2  FCM background init
[ ] M3  expiresAt server authoritative
[ ] M4  Pagination over-fetch
[ ] R8  isMinifyEnabled + proguard
[ ]     flutter_native_splash + splash 1.5s
```

### Phase D — Post-launch (v1.1)

```
[ ] Data export (GDPR Art.20) — Drift export + share_plus
[ ] RTDB onDisconnect presence
[ ] ECDH real E2E
[ ] App Check enforcement (firestore.rules: request.app)
[ ] Typesense (FeatureFlag.typesenseEnabled)
```

---

## 4. Data Safety Draft (Play Console)

- **Location Approximate:** Collected, not shared, optional, until delete — `profile_repository_impl.dart:446` GeoHash
- **Photos & Videos:** Collected, until delete — `storage.rules:4` 5MB/50MB
- **App activity (messages):** Collected, encrypted in transit YES — `chats/{id}/messages`
- **Device IDs (FCM token):** Collected — `users/{uid}/fcm_tokens`
- **Crash logs:** Collected opt-in only — `AndroidManifest.xml:61` OFF default
- **Analytics:** Not collected ✅ (B7 DONE, SDK αφαιρέθηκε)
- **Data encrypted in transit:** YES (Firebase TLS)
- **Data deleted:** YES — `functions/src/index.ts:575` deleteUserData

**iOS Privacy Labels** mirror same.

---

## 5. Εντολές Επαλήθευσης

```powershell
# Μετά τα B1-B6
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
# iOS
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
# Firebase
firebase deploy --only firestore:rules,storage,hosting
# Test
adb install build/app/outputs/bundle/release/app-release.aab --test
# Crashlytics mapping
# Play Console → Pre-launch report → Deobfuscated trace check
```

---

## 6. Εκτίμηση

| Phase | Χρόνος | Blocker; |
|---|---|---|
| A Store Blockers | 0 μέρες | ✅ DONE (B1-B7) |
| B High Fixes | 0 μέρες | ✅ DONE (C1-C5) — μόνο C6 απομένει |
| C Medium | ~1 μέρα | NICE — M1-M4 (εκκρεμεί) |
| D Post-launch | 2-4 εβδομάδες | v1.1 |

**Μετά το A+B → GO για internal track ✅. Μετά το A+B+C → polished launch με zero known warnings.**

