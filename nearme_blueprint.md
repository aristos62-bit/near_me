# NearMe — Project Blueprint & Αποφάσεις Σχεδιασμού

> **Έκδοση:** 1.1  
> **Ημερομηνία:** Μάιος 2026  
> **Κατάσταση:** Σχεδιασμός — έτοιμο για ανάπτυξη Φάσης 1  
> **v1.1:** Προσθήκη ανάλυσης Firestore περιορισμού + client-side filtering στρατηγική

---

## Πίνακας Περιεχομένων

1. [Περιγραφή Εφαρμογής](#1-περιγραφή-εφαρμογής)
2. [Βασικές Αρχές Σχεδιασμού](#2-βασικές-αρχές-σχεδιασμού)
3. [Αρχετυπικοί Χρήστες (Personas)](#3-αρχετυπικοί-χρήστες-personas)
4. [Technology Stack](#4-technology-stack)
5. [Αρχιτεκτονική Δεδομένων](#5-αρχιτεκτονική-δεδομένων)
   - 5a. [Isar Local Schema](#5a-isar-local-schema-κινητό-μόνο)
   - 5b. [Firestore Public Schema](#5b-firestore-public-schema)
   - 5c. [Firebase Storage](#5c-firebase-storage)
6. [Firestore Security Rules](#6-firestore-security-rules)
7. [Ασφάλεια — 5-Layer Model](#7-ασφάλεια--5-layer-model)
8. [Κρίσιμες Αποφάσεις Σχεδιασμού](#8-κρίσιμες-αποφάσεις-σχεδιασμού)
9. [Search Architecture](#9-search-architecture--απόφαση)
10. [Γεωγραφία & Privacy](#10-γεωγραφία--privacy)
11. [Authentication Flow](#11-authentication-flow)
12. [Chat & Encryption](#12-chat--encryption)
13. [Video Calls](#13-video-calls)
14. [Feature Flags](#14-feature-flags)
15. [Flutter App Structure](#15-flutter-app-structure)
16. [Packages](#16-packages)
17. [Roadmap Φάσεων](#17-roadmap-φάσεων)
18. [Κόστος Εκτίμηση](#18-κόστος-εκτίμηση)
19. [GDPR & Consent](#19-gdpr--consent)
20. [Μελλοντικές Επεκτάσεις](#20-μελλοντικές-επεκτάσεις)

---

## 1. Περιγραφή Εφαρμογής

**NearMe** είναι μια Flutter εφαρμογή ανταλλαγής πληροφοριών μεταξύ χρηστών για:

- Κοινή ενοικίαση / συγκατοίκηση
- Κοινή έξοδο
- Φιλία / κοινά ενδιαφέροντα
- Networking (φοιτητές, gamers, προγραμματιστές κ.λπ.)

### Βασική φιλοσοφία

> **"Ο χρήστης ελέγχει πλήρως τι υπάρχει online — και μπορεί να το κατεβάσει ανά πάσα στιγμή."**

Το πλήρες profile ζει **αποκλειστικά** στο κινητό (Isar). Στο cloud ανεβαίνει **μόνο** το public snapshot που ο ίδιος ο χρήστης επιλέγει, και μόνο όσο το θέλει.

---

## 2. Βασικές Αρχές Σχεδιασμού

| Αρχή | Περιγραφή |
|---|---|
| **Privacy-first** | Κανένα δεδομένο στο cloud χωρίς ρητή συγκατάθεση |
| **Local-first** | Το full profile ζει στο Isar — ποτέ δεν φεύγει αυτόματα |
| **Granular control** | Κάθε πεδίο χωριστά: on/off ορατότητα |
| **Reversible** | Ο χρήστης μπορεί να κατεβάσει τα πάντα με ένα toggle |
| **Transparent** | ConsentLog: ο χρήστης βλέπει τι έχει κοινοποιήσει πότε |
| **Extensible** | Repository pattern, Feature flags, Schema versioning |
| **Multilingual** | flutter_localizations + device locale auto-detect |
| **Adaptive theme** | Dark/Light από system settings (MediaQuery.platformBrightness) |
| **Real-time** | Riverpod streams + Firestore listeners όπου χρειάζεται |
| **Responsive** | Κάθε screen λειτουργεί σωστά σε mobile/tablet/desktop (LayoutBuilder, breakpoints) |
| **Shared widgets** | Κάθε επαναλαμβανόμενο UI component γίνεται shared widget — όχι duplication |
| **Shared utils** | Common logic (formatters, validators, helpers) σε κεντρικά utils, όχι copy-paste |
| **File size limit** | Κανένα αρχείο δεν ξεπερνά τις 400 γραμμές — enforced από την αρχή |
| **Schema versioning** | Αλλαγές σε Isar schemas → νέο schemaVersion + migration, όχι placeholder πεδία |
| **Debug logging** | `DebugConfig.log()` σε κάθε operational action — init, read, write, stream, error |
| **Unified error handling** | `ErrorView`/`LoadingView`/`EmptyView` από `app_state_widget.dart` για async states (loading/error/empty). `AppMessenger.showSuccess/Error/Info/ConfirmDialog` για snackbars, dialogs, loading overlay. Ποτέ raw `ScaffoldMessenger`, `AlertDialog` ή error/loading widgets ανά screen. |

---

## 3. Αρχετυπικοί Χρήστες (Personas)

### Persona 1: Ο Αναζητητής
Ψάχνει ενεργά κάποιον (συγκάτοικο, φίλο, συνεργάτη).

**Χρειάζεται:**
- Φίλτρα αναζήτησης με ακρίβεια (ηλικία, περιοχή, ενδιαφέροντα, φύλο)
- Εμφάνιση φωτογραφιών και bio
- Εύκολη αποστολή αιτήματος chat
- Αποθήκευση αγαπημένων profiles
- Dashboard με τα αποτελέσματα

**Ανησυχεί για:**
- Ψεύτικα profiles
- Spam αιτήματα
- Αποκάλυψη των δικών του δεδομένων

---

### Persona 2: Ο Διαθέσιμος
Έχει ανεβάσει public profile και περιμένει αιτήματα.

**Χρειάζεται:**
- Πλήρη έλεγχο του τι φαίνεται (ανά πεδίο)
- On/Off toggle σαν διακόπτης
- Εμφάνιση ποιος είδε το profile
- Εύκολη αποδοχή / απόρριψη αιτημάτων
- Notifications για νέα αιτήματα

**Ανησυχεί για:**
- Harassment / ανεπιθύμητα μηνύματα
- Να τον βρουν συνάδελφοι ή οικογένεια
- Διαρροή τηλεφώνου / email

---

### Persona 3: Ο Προστατευμένος
Πολύ προσεκτικός με την ιδιωτικότητά του. Θέλει να χρησιμοποιεί την εφαρμογή αλλά με ελάχιστο digital footprint.

**Χρειάζεται:**
- Βεβαίωση ότι τίποτα δεν ανεβαίνει στο cloud χωρίς άδειά του
- Ιστορικό συγκατάθεσης (ConsentLog)
- Εύκολη πλήρη διαγραφή λογαριασμού
- Ανώνυμη περιήγηση χωρίς εγγραφή

**Ανησυχεί για:**
- Screenshots χωρίς άδεια
- Τρίτες χρήσεις δεδομένων
- Ακριβής γεωγραφικός εντοπισμός

---

## 4. Technology Stack

| Layer | Τεχνολογία | Λόγος επιλογής |
|---|---|---|
| Framework | Flutter (latest stable) + Dart | Cross-platform, performance |
| State Management | Riverpod 2 (`@riverpod`, AsyncNotifier) | Type-safe, testable, real-time streams |
| Local Database | Isar | Fast NoSQL, schema versioning, offline-first |
| Navigation | GoRouter | Deep links, declarative routing |
| Cloud Auth | Firebase Authentication | Email, phone, anonymous — όλα σε ένα |
| Cloud Database | Cloud Firestore | Real-time, offline support, security rules |
| Cloud Storage | Firebase Storage | Photos, avatars |
| Push Notifications | Firebase Cloud Messaging (FCM) | iOS + Android unified |
| Cloud Functions | Firebase Functions | Triggers, moderation, email, rate limiting |
| Geo Search (v1) | geoflutterfire_plus | Firestore native, μηδενικό κόστος |
| Search (v2) | Typesense (self-hosted) | Compound filters, full-text, €10/μήνα |
| Video Calls | Agora RTC ή flutter_webrtc | Opt-in μόνο για επιλεγμένα profiles |
| Encryption | encrypt (AES-256) | E2E chat encryption |
| Secure Storage | flutter_secure_storage | Tokens, chat keys |
| i18n | flutter_localizations + intl | Auto από device locale |
| Images | cached_network_image + image_picker | Cache + upload |

---

## 5. Αρχιτεκτονική Δεδομένων

### Αρχή διαχωρισμού

```
ΚΙΝΗΤΟ (Isar)                    FIREBASE (Cloud)
─────────────────                ─────────────────────────
UserProfile (full)      ──→      users/{uid}/public (snapshot)
PrivacySettings         ──→      users/{uid}/status
BlockedUser             ──→      users/{uid}/blocked/{targetUid}
ConsentLog              (local only)
ChatHistory (cache)     ←──      chats/{chatId}/messages
SearchFilters (saved)   (local only)
AppSettings             (local only)
```

---

### 5a. Isar Local Schema (κινητό μόνο)

```dart
// ============================================================
// UserProfile — το πλήρες ιδιωτικό profile
// ΠΟΤΕ δεν ανεβαίνει ολόκληρο στο cloud
// ============================================================
@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  // Ταυτοποίηση
  late String uid;               // Firebase UID (μετά login)
  late String nickname;          // εμφανιζόμενο όνομα
  String? fullName;              // προαιρετικό, ποτέ public by default
  String? email;
  String? phone;

  // Προφίλ
  late String bio;
  late int birthYear;
  late String gender;            // 'male' | 'female' | 'other' | 'prefer_not'
  late List<String> interests;   // ['gamer', 'programmer', 'student', ...]
  late List<String> occupations;
  late String lookingFor;        // 'roommate' | 'social' | 'friendship' | 'networking'

  // Γεωγραφία
  late String city;
  late String country;
  double? latitudeExact;         // ΠΟΤΕ δεν πηγαίνει στο Firestore
  double? longitudeExact;        // ΠΟΤΕ δεν πηγαίνει στο Firestore
  String? manualLocationText;    // fallback αν δεν δώσει GPS

  // Επικοινωνία
  late bool allowVideoCall;
  late bool allowDirectChat;

  // Status
  late bool isPublished;
  late DateTime createdAt;
  late DateTime updatedAt;
}

// ============================================================
// PrivacySettings — ποια πεδία φαίνονται δημόσια
// ============================================================
@collection
class PrivacySettings {
  Id id = Isar.autoIncrement;
  late String uid;

  // Ορατότητα ανά πεδίο (default: συντηρητικό)
  bool showNickname = true;
  bool showFullName = false;       // default OFF
  bool showAge = true;
  bool showGender = true;
  bool showCity = true;
  bool showExactLocation = false;  // default OFF — μόνο GeoHash
  bool showPhone = false;          // default OFF
  bool showEmail = false;          // default OFF
  bool showInterests = true;
  bool showOccupation = true;
  bool showBio = true;
  bool showLookingFor = true;
  bool allowVideoCall = false;     // default OFF — opt-in
  bool allowDirectChat = true;

  // Geo precision level
  // 'city' | 'neighborhood' (~2.5km) | 'hidden'
  String geoPrecision = 'neighborhood';
}

// ============================================================
// ConsentLog — ιστορικό ενεργειών για GDPR & εμπιστοσύνη
// ============================================================
@collection
class ConsentLog {
  Id id = Isar.autoIncrement;
  late String uid;
  late String action;      // 'published' | 'unpublished' | 'sent_request' |
                           // 'shared_location' | 'uploaded_photo' | 'deleted_account'
  late String dataType;    // 'profile' | 'location' | 'photo' | 'chat_key'
  String? details;         // προαιρετικές λεπτομέρειες
  late DateTime timestamp;
}

// ============================================================
// ChatCache — τοπικό backup chat history
// ============================================================
@collection
class ChatCache {
  Id id = Isar.autoIncrement;
  late String chatId;
  late String otherUid;
  late String otherNickname;
  late DateTime lastMessageAt;
  late bool hasUnread;
}

// ============================================================
// SavedSearch — αποθηκευμένες αναζητήσεις
// ============================================================
@collection
class SavedSearch {
  Id id = Isar.autoIncrement;
  late String label;
  String? city;
  String? country;
  int? minAge;
  int? maxAge;
  String? gender;
  late List<String> interests;
  String? lookingFor;
  double? radiusKm;
  late DateTime createdAt;
}

// ============================================================
// AppSettings — τοπικές ρυθμίσεις εφαρμογής
// ============================================================
@collection
class AppSettings {
  Id id = Isar.autoIncrement;
  String locale = 'system';            // 'system' | 'el' | 'en' | ...
  String themeMode = 'system';         // 'system' | 'light' | 'dark'
  bool notificationsEnabled = true;
  bool biometricLockEnabled = false;
  bool screenshotPreventionEnabled = true;
  int autoLockMinutes = 5;
  late DateTime updatedAt;
}

// ============================================================
// BlockedUser — λίστα μπλοκαρισμένων χρηστών
// (synced με Firestore users/{uid}/blocked/{targetUid})
// ============================================================
@collection
class BlockedUser {
  Id id = Isar.autoIncrement;
  late String uid;               // current user (owner)
  late String blockedUid;        // blocked target
  late DateTime blockedAt;
  String? reason;
}
```

---

### 5b. Firestore Public Schema

```
/users/{uid}/
│
├── public                    ← ΜΟΝΟ αυτό διαβάζουν οι άλλοι
│   ├── nickname: string
│   ├── age: int?             (αν showAge == true)
│   ├── gender: string?       (αν showGender == true)
│   ├── city: string?         (αν showCity == true)
│   ├── geoHash: string?      (precision ανάλογα geoPrecision)
│   │                          π.χ. 'sx3q' = ~2.5km² περιοχή
│   ├── interests: string[]
│   ├── occupations: string[]
│   ├── lookingFor: string
│   ├── bio: string?
│   ├── avatarUrl: string?
│   ├── photoUrls: string[]   (max 5)
│   ├── allowVideoCall: bool
│   ├── allowDirectChat: bool
│   ├── isVisible: bool       ← master switch
│   └── updatedAt: timestamp
│
└── status
    ├── isOnline: bool
    ├── lastSeen: timestamp
    └── isVisible: bool       ← αντίγραφο για queries

/chats/{chatId}/
├── participants: string[]    [uid1, uid2]
├── createdAt: timestamp
├── isActive: bool
└── messages/{msgId}/
    ├── senderId: string
    ├── content: string       ← AES-256 encrypted
    ├── type: string          'text' | 'image' | 'system'
    ├── timestamp: timestamp
    └── isRead: bool

/requests/{reqId}/
├── fromUid: string
├── toUid: string
├── type: string              'chat' | 'video' | 'email'
├── status: string            'pending' | 'accepted' | 'declined' | 'expired'
├── message: string?          προαιρετικό μήνυμα
├── createdAt: timestamp
└── expiresAt: timestamp      (48h αν δεν απαντηθεί)

/reports/{reportId}/
├── reporterUid: string
├── reportedUid: string
├── reason: string            'spam' | 'harassment' | 'fake_profile' | 'inappropriate' | 'other'
├── details: string?
├── createdAt: timestamp
├── status: string             'pending' | 'processed' | 'banned' | 'rate_limited' |
│                              'duplicate' | 'self_report' | 'already_banned' | 'invalid'
└── processedAt: timestamp?   (τίθεται από Cloud Function)

/banned/{uid}/
├── bannedAt: timestamp
├── reason: string
├── reportsCount: number
└── bannedBy: string          'system'

/users/{uid}/blocked/{blockedUid}/
├── blockedAt: timestamp
└── reason: string?
```

---

### 5c. Firebase Storage

```
/avatars/{uid}/profile.jpg          ← 400x400 max, compressed
/photos/{uid}/{photoIndex}.jpg      ← max 5 photos, 1024x1024 max
```

**Κανόνες Storage:**
- Ανάγνωση: μόνο authenticated users
- Εγγραφή: μόνο ο ίδιος ο χρήστης στο δικό του path
- Max size: 5MB ανά αρχείο

---

## 6. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ─────────────────────────────────────────────────────────
    // Helper functions
    // ─────────────────────────────────────────────────────────

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return request.auth.uid == uid;
    }

    function isParticipant(chatData) {
      return request.auth.uid in chatData.participants;
    }

    function isPubliclyVisible(uid) {
      return get(/databases/$(database)/documents/users/$(uid)/public).data.isVisible == true;
    }

    function notBanned() {
      // Ελέγχει αν ο χρήστης ΔΕΝ είναι banned (Cloud Function το θέτει)
      return !exists(/databases/$(database)/documents/banned/$(request.auth.uid));
    }

    // ─────────────────────────────────────────────────────────
    // Users
    // ─────────────────────────────────────────────────────────

    match /users/{uid} {
      // Κανένας δεν διαβάζει το root document απευθείας
      allow read, write: if false;

      match /public/{doc} {
        // Διαβάζουν ΜΟΝΟ authenticated + isVisible == true
        allow read: if isAuthenticated()
                    && notBanned()
                    && resource.data.isVisible == true;
        // Γράφει ΜΟΝΟ ο ίδιος
        allow write: if isOwner(uid) && notBanned();
      }

      match /status/{doc} {
        // Ο ίδιος γράφει, authenticated διαβάζουν
        allow read: if isAuthenticated();
        allow write: if isOwner(uid);
      }
    }

    // ─────────────────────────────────────────────────────────
    // Collection group (απαραίτητο για collectionGroup('public') queries)
    // ─────────────────────────────────────────────────────────

    match /{path=**}/public/{doc} {
      allow read: if isAuthenticated()
                  && notBanned()
                  && resource.data.isVisible == true;
      // Το write ελέγχεται από το match /users/{uid}/public/{doc}
    }

    // ─────────────────────────────────────────────────────────
    // Chats
    // ─────────────────────────────────────────────────────────

    match /chats/{chatId} {
      allow read: if isAuthenticated()
                  && isParticipant(resource.data);
      allow create: if isAuthenticated()
                    && request.auth.uid in request.resource.data.participants
                    && request.resource.data.participants.size() == 2;
      allow update: if isAuthenticated()
                    && isParticipant(resource.data);

      match /messages/{msgId} {
        allow read: if isAuthenticated()
                    && isParticipant(
                         get(/databases/$(database)/documents/chats/$(chatId)).data
                       );
        allow create: if isAuthenticated()
                      && request.auth.uid == request.resource.data.senderId
                      && isParticipant(
                           get(/databases/$(database)/documents/chats/$(chatId)).data
                         );
        // Τα μηνύματα ΔΕΝ επεξεργάζονται — μόνο isRead update επιτρέπεται
        allow update: if isAuthenticated()
                      && request.resource.data.diff(resource.data).affectedKeys()
                           .hasOnly(['isRead']);
        // ΔΕΝ διαγράφονται μηνύματα (ατομικά)
        allow delete: if false;
      }
    }

    // ─────────────────────────────────────────────────────────
    // Requests
    // ─────────────────────────────────────────────────────────

    match /requests/{reqId} {
      // Διαβάζει: sender ή receiver
      allow read: if isAuthenticated()
                  && (request.auth.uid == resource.data.fromUid
                   || request.auth.uid == resource.data.toUid);
      // Δημιουργεί: μόνο ο sender, μόνο για visible profile
      allow create: if isAuthenticated()
                    && request.auth.uid == request.resource.data.fromUid
                    && isPubliclyVisible(request.resource.data.toUid)
                    && notBanned();
      // Ενημερώνει status: μόνο ο receiver
      allow update: if isAuthenticated()
                    && request.auth.uid == resource.data.toUid
                    && request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['status']);
      allow delete: if false;
    }

    // ─────────────────────────────────────────────────────────
    // Reports
    // ─────────────────────────────────────────────────────────

    match /reports/{reportId} {
      allow create: if isAuthenticated()
                    && request.auth.uid == request.resource.data.reporterUid;
      allow read: if false;   // μόνο Cloud Functions / Admin SDK
      allow update, delete: if false;
    }

    // ─────────────────────────────────────────────────────────
    // Banned users (γράφεται μόνο από Admin SDK)
    // ─────────────────────────────────────────────────────────

    match /banned/{uid} {
      allow read: if isAuthenticated() && isOwner(uid);
      allow write: if false;  // μόνο Cloud Functions
    }
  }
}
```

### Required Composite Indexes

Για να λειτουργούν τα collection group queries, απαιτούνται composite indexes στο Firestore. Βλ. `firestore.indexes.json` για την πλήρη λίστα. Κύρια indexes:

| Collection | Fields | Scope | Χρήση |
|---|---|---|---|
| `public` | `isVisible` ↑, `geoHash` ↑ | COLLECTION_GROUP | Geo αναζήτηση |
| `public` | `isVisible` ↑, `city` ↑ | COLLECTION_GROUP | Αναζήτηση ανά πόλη |
| `public` | `city` ↑, `isVisible` ↑, `geoHash` ↑ | COLLECTION_GROUP | Πόλη + radius |
| `public` | `isVisible` ↑, `updatedAt` ↓ | COLLECTION_GROUP | Ταξινόμηση κατά ημερομηνία |
| `messages` | `senderId` ↑, `timestamp` ↑ | COLLECTION | Ανάγνωση μηνυμάτων |
| `requests` | `toUid` ↑, `status` ↑, `createdAt` ↓ | COLLECTION | Dashboard εισερχομένων |
| `requests` | `fromUid` ↑, `status` ↑, `createdAt` ↓ | COLLECTION | Dashboard εξερχομένων |

Deploy: `firebase deploy --only firestore`

---

## 7. Ασφάλεια — 5-Layer Model

Κάθε layer είναι ανεξάρτητο — η παραβίαση ενός δεν αρκεί.

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 5 — Behaviour (Cloud Functions)                          │
│  Rate limiting, auto-ban σε abuse, content moderation AI        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Layer 4 — Transport (TLS 1.3 + AES-256 E2E chat)        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  Layer 3 — Data (Firestore Security Rules)          │  │  │
│  │  │  read μόνο αν isVisible, write μόνο owner           │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │  Layer 2 — Auth (Firebase Authentication)     │  │  │  │
│  │  │  │  Anonymous → Email/Phone verify, token mgmt   │  │  │  │
│  │  │  │  ┌─────────────────────────────────────────┐  │  │  │  │
│  │  │  │  │  Layer 1 — Device (Isar + Secure Store) │  │  │  │  │
│  │  │  │  │  Full profile, chat keys, biometric lock │  │  │  │  │
│  │  │  │  │  Screenshot prevention, auto-lock        │  │  │  │  │
│  │  │  │  └─────────────────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 1 — Device
- `Isar` με schema versioning — full profile ποτέ δεν φεύγει αυτόματα
- `flutter_secure_storage` για Firebase tokens και chat encryption keys
- Biometric lock (opt-in): `local_auth` package
- Screenshot prevention: `FlutterWindowManager.addFlags(FLAG_SECURE)` (Android) / iOS equivalent
- Auto-lock μετά από N λεπτά αδράνειας (configurable)

### Layer 2 — Authentication
- Anonymous auth → περιήγηση χωρίς λογαριασμό
- Upgrade σε email ή phone verification όταν θέλει να επικοινωνήσει
- Silent token refresh (χωρίς re-login)
- Logout = διαγραφή local tokens + unpublish profile

### Layer 3 — Data Rules
- Βλέπε Section 6 (Firestore Security Rules)
- Κάθε read/write ελέγχεται server-side

### Layer 4 — Transport
- TLS 1.3 σε όλες τις Firebase κλήσεις (default)
- AES-256 encryption για chat messages (βλέπε Section 12)
- Chat encryption keys: παράγονται on-device, αποθηκεύονται στο flutter_secure_storage

### Layer 5 — Behaviour (Cloud Functions)
- **Rate limiting:** max 10 reports/ώρα ανά reporter (Cloud Function `onReportCreated`)
- **Duplicate check:** αποτροπή πολλαπλών reports από τον ίδιο reporter για τον ίδιο χρήστη
- **Auto-ban trigger:** 5 reports → Cloud Function → set `banned/{uid}` document
- **Auto-unpublish:** auto-ban → `users/{uid}/public/profile` → `isVisible = false`
- **Self-report protection:** απόρριψη αν reporterUid === reportedUid
- **Already-banned check:** skip processing αν ο χρήστης είναι ήδη banned
- **Audit trail:** κάθε report παίρνει `status` (processed, banned, rate_limited, duplicate, κλπ.) + `processedAt` timestamp
- **Content moderation:** Firebase Extensions (Perspective API) για κείμενο (Φάση 3+)
- **Request expiry:** Cloud Function ελέγχει κάθε 6 ώρες και expire-αρει requests > 48h (Φάση 3)
- **Account deletion:** Cloud Function διαγράφει όλα τα cloud δεδομένα (Φάση 3)

#### Υλοποίηση: `onReportCreated` Cloud Function
```typescript
// functions/src/index.ts
// Trigger: firestore.document('reports/{reportId}').onCreate()

export const onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const { reporterUid, reportedUid, reason } = snap.data();
    // 1. Validate + self-report check
    // 2. Existing ban check
    // 3. Rate limit (≥10 reports/1h από ίδιο reporter)
    // 4. Duplicate check (ίδιος reporter + reportedUid)
    // 5. Report count → if ≥5: write banned/{uid} + unpublish
    // 6. Update report status + audit log
  });
```

**Deploy:** `firebase deploy --only functions` (απαιτεί Blaze plan)
**Runtime:** Node.js 22 (1st Gen), region: us-central1

---

## 8. Κρίσιμες Αποφάσεις Σχεδιασμού

### ✅ Απόφαση Α: Authentication — Anonymous + Lazy Upgrade

**Τι επιλέξαμε:** Ο χρήστης ξεκινά ανώνυμα (Firebase Anonymous Auth) και αναβαθμίζει σε verified (email ή phone) μόνο όταν θέλει να επικοινωνήσει.

**Λόγος:** Μέγιστη ευκολία χρήσης, χωρίς friction στην αρχή. Το Isar αποθηκεύει δεδομένα από την πρώτη στιγμή — η Firebase εγγραφή γίνεται lazy.

**Υλοποίηση:**
```dart
// Ροή:
// 1. App launch → Firebase.signInAnonymously()
// 2. Χρήστης δημιουργεί profile → αποθηκεύεται ΜΟΝΟ στο Isar
// 3. Χρήστης θέλει να επικοινωνήσει → ζητά email/phone verification
// 4. Successful verify → linkWithCredential() στον ήδη anonymous account
// 5. isAnonymous = false → unlock chat/requests features
```

**Feature flags για anonymous restrictions:**
```dart
// Anonymous μπορεί:   περιηγηθεί, δει profiles, αποθηκεύσει locally
// Anonymous δεν μπορεί: στείλει request, ανοίξει chat, ανεβάσει profile
if (user.isAnonymous) {
  // Εμφάνιση prompt "Επαλήθευσε τον λογαριασμό σου για να συνεχίσεις"
}
```

---

### ✅ Απόφαση Β: Γεωγραφία — GPS με fallback manual

**Τι επιλέξαμε:**
1. Ζητά GPS permission με πλήρη εξήγηση γιατί
2. Αν δοθεί → χρησιμοποιούμε `geolocator` για lat/lng
3. Αν αρνηθεί → text field για χειροκίνητη εισαγωγή πόλης/περιοχής
4. **Σε καμία περίπτωση** δεν αποθηκεύεται το ακριβές lat/lng στο Firestore

**GeoHash privacy levels:**
```dart
enum GeoPrecision {
  city,          // ~100km² — geohash 3 chars, π.χ. 'sx3'
  neighborhood,  // ~2.5km² — geohash 5 chars, π.χ. 'sx3q7' (DEFAULT)
  hidden,        // δεν εμφανίζεται καθόλου στο Firestore
}
```

**Στο Firestore αποθηκεύεται μόνο το GeoHash** — ποτέ raw lat/lng. Ο χρήστης επιλέγει precision level στο Privacy Editor.

---

### ✅ Απόφαση Γ: Search — Υβριδικό Firestore v1 → Typesense v2

**Τι επιλέξαμε:** Repository Pattern που επιτρέπει swap χωρίς αλλαγή UI.

**Λόγος απόρριψης Algolia:** Πολύ ακριβό σε scale. 100k users → €800–1500/μήνα vs €60/μήνα για Typesense.

**Φάση 1 (0–5k users):** Firestore native + geoflutterfire_plus
- Μηδενικό κόστος
- Μηδενική πολυπλοκότητα infra
- Περιορισμός: 1 range filter ανά query

**Φάση 2 (5k+ users ή όταν χρειαστούν compound filters):** Typesense self-hosted
- Hetzner VPS CX11: €3.8/μήνα
- Full-text search, geo, compound filters, typo tolerance
- Cloud Function sync: `onWrite users/{uid}/public → typesense.upsert()`

**Repository Pattern implementation:**
```dart
// Abstract interface — ΠΟΤΕ δεν αλλάζει
abstract class SearchRepository {
  Future<List<PublicProfile>> search(SearchFilters filters);
  Future<List<PublicProfile>> searchNearby(LatLng center, double radiusKm);
}

// Φάση 1 implementation
class FirestoreSearchRepository implements SearchRepository { ... }

// Φάση 2 implementation
class TypesenseSearchRepository implements SearchRepository { ... }

// Provider — αλλάζει μόνο εδώ για swap
@riverpod
SearchRepository searchRepository(SearchRepositoryRef ref) {
  if (FeatureFlags.typesenseEnabled) {
    return TypesenseSearchRepository();
  }
  return FirestoreSearchRepository();
}
```

---

## 9. Search Architecture — Απόφαση

### Σύγκριση επιλογών

| Κριτήριο | Firestore native | Algolia | Typesense self-hosted |
|---|---|---|---|
| Compound filters | Περιορισμένο (1 range) | Πλήρες | Πλήρες |
| Full-text search | Όχι | Άριστο | Άριστο |
| Geo radius query | Ναι (geoflutterfire) | Ναι | Ναι |
| Sort by distance | Όχι | Ναι | Ναι |
| Typo tolerance | Όχι | Ναι | Ναι |
| Real-time sync | Native | Με webhooks | Με webhooks |
| Infra complexity | Μηδενική | Managed (SaaS) | Self-host (VPS) |
| GDPR | Firebase (Google) | EU region διαθέσιμο | Full control |
| Κόστος 1k users | ~€0 | ~€0 | ~€0 |
| Κόστος 10k users | €20–50/μήνα | €50–100/μήνα | €10–20/μήνα |
| Κόστος 100k users | €200–400/μήνα | €400–900/μήνα | €30–60/μήνα |
| **Βαθμολογία** | **5/10 (αρκεί v1)** | **8/10 (ακριβό)** | **9/10 (best value)** |

---

### Γιατί δεν κάνουμε τα φίλτρα "ένα τη φορά" — Ο περιορισμός του Firestore

> **Ερώτηση που τέθηκε κατά τον σχεδιασμό:**  
> *"Γιατί να μην εφαρμόζουμε τα φίλτρα διαδοχικά (πρώτα ηλικία, μετά περιοχή, μετά interests) αντί για compound query;"*

#### Η απάντηση: Το πρόβλημα δεν είναι η λογική — είναι το Firestore backend

Το Firestore έχει έναν **αρχιτεκτονικό** (όχι απόδοσης) περιορισμό: επιτρέπει **μόνο ένα πεδίο** με range operator (`>`, `<`, `>=`, `<=`) ανά query. Αν προσπαθήσεις να βάλεις δύο range filters σε διαφορετικά πεδία, πετά **runtime error** — δεν εκτελείται καθόλου.

```dart
// ❌ ΑΔΥΝΑΤΟ — Firestore runtime error
firestore.collection('users/public')
  .where('age', isGreaterThan: 20)       // range filter #1 στο 'age'
  .where('age', isLessThan: 30)
  .where('distanceKm', isLessThan: 10)   // range filter #2 σε άλλο πεδίο → CRASH
  .where('interests', arrayContains: 'gamer');

// ✅ ΕΠΙΤΡΕΠΕΤΑΙ — ένα range + equality filters
firestore.collection('users/public')
  .where('age', isGreaterThan: 20)       // range: μόνο σε ένα πεδίο
  .where('age', isLessThan: 30)
  .where('gender', isEqualTo: 'male')    // equality: OK
  .where('interests', arrayContains: 'gamer'); // arrayContains: OK
```

Ακόμα και αν ο χρήστης επέλεγε φίλτρα "ένα τη φορά", η εφαρμογή θέλει να τα συνδυάζει όλα μαζί στο αποτέλεσμα. Ένα "ηλικία 20–30" query και ένα "εντός 10km" query δίνουν **δύο ξεχωριστές λίστες** — δεν υπάρχει τρόπος να πεις στο Firestore "δώσε μου την τομή τους" σε ένα call.

---

#### Η λύση για Φάση 1: Firestore + Client-side filtering

Αντί να προσπαθήσουμε να κάνουμε το Firestore να κάνει κάτι που δεν μπορεί, χρησιμοποιούμε μια **υβριδική στρατηγική**:

```
Βήμα 1 — Firestore query (1 range filter μόνο):
  Χρησιμοποιούμε το πιο "επιλεκτικό" φίλτρο ως anchor
  → συνήθως geoHash (περιοχή) ή age range
  → επιστρέφει N records (π.χ. 100–300 profiles)

Βήμα 2 — Client-side filter (στη μνήμη του κινητού):
  Από τα N records κρατάμε μόνο αυτά που περνούν ΟΛΑ τα φίλτρα
  → ηλικία εντός range
  → απόσταση εντός X km (υπολογισμός από GeoHash)
  → interests περιέχει τα επιλεγμένα
  → lookingFor ταιριάζει
  → gender ταιριάζει
```

```dart
// Παράδειγμα υλοποίησης στο FirestoreSearchRepository
Future<List<PublicProfile>> search(SearchFilters filters) async {

  // Βήμα 1: Firestore query — anchor στο geoHash (1 range μόνο)
  Query query = firestore
      .collection('users')
      .doc('public')  // subcollection group query
      .where('isVisible', isEqualTo: true);

  // Προσθέτουμε ΜΟΝΟ ένα range filter στο Firestore
  if (filters.geoHash != null) {
    final bounds = GeoHashUtils.getBounds(filters.geoHash!, filters.radiusKm ?? 10);
    query = query
        .where('geoHash', isGreaterThanOrEqualTo: bounds.lower)
        .where('geoHash', isLessThanOrEqualTo: bounds.upper);
  }

  final snapshot = await query.limit(300).get();  // max 300 για client filter
  final all = snapshot.docs.map(PublicProfile.fromFirestore).toList();

  // Βήμα 2: Client-side filtering — εφαρμόζουμε ΟΛΑ τα φίλτρα
  return all.where((profile) {
    // Ηλικία
    if (filters.minAge != null || filters.maxAge != null) {
      final age = DateTime.now().year - profile.birthYear;
      if (filters.minAge != null && age < filters.minAge!) return false;
      if (filters.maxAge != null && age > filters.maxAge!) return false;
    }

    // Φύλο
    if (filters.gender != null && filters.gender != 'all') {
      if (profile.gender != filters.gender) return false;
    }

    // Interests (OR logic: αρκεί ένα να ταιριάζει)
    if (filters.interests != null && filters.interests!.isNotEmpty) {
      final hasMatch = filters.interests!
          .any((i) => profile.interests.contains(i));
      if (!hasMatch) return false;
    }

    // lookingFor
    if (filters.lookingFor != null) {
      if (profile.lookingFor != filters.lookingFor) return false;
    }

    // Video call
    if (filters.allowVideoCall == true) {
      if (!profile.allowVideoCall) return false;
    }

    return true;  // Πέρασε όλα τα φίλτρα
  }).toList();
}
```

#### Πότε αυτή η προσέγγιση δουλεύει καλά

| Visible profiles | Records που φέρνει | Client filter χρόνος | Κόστος reads |
|---|---|---|---|
| 0–1k | ~50–200 | <10ms | Δωρεάν |
| 1k–5k | ~100–300 | <20ms | ~€0.01/search |
| 5k–20k | ~300–500 | ~50ms | ~€0.05/search |
| 20k+ | 500+ | >100ms | Αρχίζει να κοστίζει |

**Όριο χρησιμότητας: ~5.000–10.000 visible profiles.** Μετά από αυτό, το migration σε Typesense γίνεται αναγκαίο.

#### Γιατί αυτό είναι αποδεκτό για Φάση 1

Στην πράξη, η εφαρμογή **δεν θα έχει 10.000 visible profiles** στα πρώτα στάδια. Επιπλέον, το geo anchor filter (geoHash) είναι ήδη πολύ επιλεκτικό — σε μια πόλη σαν την Αθήνα, ένα neighborhood radius 5km επιστρέφει πολύ λιγότερα από 300 profiles ακόμα και με 50.000 εγγεγραμμένους χρήστες.

#### Το migration path είναι έτοιμο

Όταν έρθει η ώρα, αλλάζουμε **μόνο** το `searchRepository` provider:

```dart
// ΠΡΙΝ (Φάση 1)
@riverpod
SearchRepository searchRepository(ref) => FirestoreSearchRepository();

// ΜΕΤΑ (Φάση 2) — η UI δεν αλλάζει καθόλου
@riverpod
SearchRepository searchRepository(ref) => TypesenseSearchRepository();
```

---

### SearchFilters model

```dart
@freezed
class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    String? city,
    String? country,
    String? geoHash,
    double? radiusKm,
    int? minAge,
    int? maxAge,
    String? gender,           // null = all
    List<String>? interests,  // OR logic
    String? lookingFor,
    bool? allowVideoCall,
    bool? allowDirectChat,
    bool? isOnlineNow,
    @Default(20) int limit,
    DocumentSnapshot? lastDocument,  // pagination
  }) = _SearchFilters;
}
```

---

## 10. Γεωγραφία & Privacy

### Ροή GPS permission

```
App ζητά GPS
     │
     ├── Αποδέχτηκε → geolocator.getCurrentPosition()
     │                → αποθήκευση lat/lng ΜΟΝΟ στο Isar
     │                → μετατροπή σε GeoHash ανάλογα precision
     │                → GeoHash → Firestore (αν published)
     │
     └── Αρνήθηκε  → Text field "Πόλη / Συνοικία"
                     → Geocoding API για approximate coordinates
                     → Ίδια ροή GeoHash
```

### GeoHash precision table

| Επίπεδο | GeoHash chars | Εμβαδό | Χρήση |
|---|---|---|---|
| Χώρα | 2 | ~1250km² | Πολύ broad |
| Πόλη | 3–4 | ~40–150km² | Για "ίδια πόλη" |
| Συνοικία | 5 | ~2.5km² | **Default** |
| Δρόμος | 6 | ~0.1km² | Πολύ ακριβές — ΔΕΝ χρησιμοποιείται |

**Κανόνας:** Ποτέ precision > 5 chars στο Firestore.

---

## 11. Authentication Flow

```
┌──────────────────────────────────────────────────────────────┐
│                      App Launch                              │
└──────────────────────────────┬───────────────────────────────┘
                               │
               ┌───────────────┴────────────────┐
               │                                │
        Firebase user;                   Κανένας user
        exists (returning)               (new install)
               │                                │
               ▼                                ▼
       Load Isar profile              signInAnonymously()
       → Home screen                  → Onboarding flow
                                      → Δημιουργία Isar profile
                                              │
                                    ┌─────────┴──────────┐
                                    │  Θέλει να στείλει  │
                                    │  request / chat;   │
                                    └─────────┬──────────┘
                                              │
                                    Prompt: "Επαλήθευσε"
                                              │
                                    ┌─────────┴──────────┐
                                    │                    │
                               Email verify         Phone verify
                                    │                    │
                                    └────────┬───────────┘
                                             │
                               linkWithCredential()
                               isAnonymous = false
                               → Unlock all features
```

---

## 12. Chat & Encryption

### E2E Encryption Architecture

```
Χρήστης Α                              Χρήστης Β
    │                                      │
    │  1. Δημιουργία chat                  │
    │     → παράγει AES-256 key            │
    │     → αποθηκεύει key στο             │
    │       flutter_secure_storage         │
    │                                      │
    │  2. Στέλνει message                  │
    │     → encrypt(message, key)          │
    │     → Firestore.add(encrypted)       │
    │                                      │
    │                     3. Λαμβάνει message
    │                        → Firestore listener
    │                        → decrypt(encrypted, key)
    │                        → εμφάνιση
```

**Σημαντική επιλογή:** Το key δεν ανεβαίνει **ποτέ** στο Firestore. Αν χαθεί η συσκευή, το history χάνεται. **Αυτό είναι feature, όχι bug** — μέγιστη privacy.

### Key generation

```dart
import 'package:encrypt/encrypt.dart';

final key = Key.fromSecureRandom(32);  // AES-256
final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

// Encrypt
final iv = IV.fromSecureRandom(12);
final encrypted = encrypter.encrypt(plaintext, iv: iv);
final stored = '${iv.base64}:${encrypted.base64}';

// Decrypt
final parts = stored.split(':');
final decrypted = encrypter.decrypt64(parts[1], iv: IV.fromBase64(parts[0]));
```

### Chat features

- Real-time listeners (Firestore onSnapshot)
- Read receipts (isRead flag)
- Message expiry (opt-in: μηνύματα διαγράφονται μετά από X μέρες)
- Online presence indicator
- Typing indicator (ephemeral, Firestore status document)

---

## 13. Video Calls

**Opt-in μόνο:** Ο χρήστης ρητά ενεργοποιεί `allowVideoCall = true` στο Privacy Settings.

**Υλοποίηση:** Agora RTC Engine ή flutter_webrtc (απόφαση στη Φάση 4).

**Ροή:**
1. Χρήστης Α στέλνει video request (type: 'video')
2. Χρήστης Β λαμβάνει push notification
3. Αποδέχεται → Cloud Function παράγει ephemeral Agora token
4. Και οι δύο συνδέονται με το token
5. Token λήγει μετά το call — ποτέ δεν αποθηκεύεται

---

## 14. Feature Flags

Κάθε μεγάλο feature τυλίγεται σε `FeatureFlag` από την αρχή.

```dart
class FeatureFlags {
  // Search
  static const bool typesenseEnabled = false;  // v1: false, v2: true

  // Communication
  static const bool videoCallEnabled = false;   // Φάση 4
  static const bool groupChatEnabled = false;   // Φάση 4+

  // Discovery
  static const bool aiMatchingEnabled = false;  // Φάση 4+
  static const bool verifiedBadgeEnabled = false;

  // Monetization
  static const bool premiumTierEnabled = false;

  // Future
  static const bool groupEventsEnabled = false;
  static const bool webVersionEnabled = false;
}
```

**Χρήση παντού:**
```dart
if (FeatureFlags.videoCallEnabled) {
  // εμφάνιση video call option
}
```

**Μελλοντικά:** Remote config (Firebase Remote Config) για server-side flag control χωρίς release.

---

## 15. Flutter App Structure

```
lib/
├── core/
│   ├── config/
│   │   ├── feature_flags.dart
│   │   └── app_config.dart
│   ├── debug/
│   │   └── debug_config.dart       # 33 debug flags, 3 log levels, release override
│   ├── theme/
│   │   ├── app_theme.dart          # dark/light από system
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   └── responsive_utils.dart   # ResponsiveUtils, ResponsiveBuilder, ResponsivePadding
│   ├── l10n/
│   │   └── l10n.dart               # locale detection, isGreek(), formatters
│   ├── router/
│   │   ├── app_router.dart         # GoRouter
│   │   └── main_shell.dart         # Adaptive shell (NavigationRail / NavigationBar)
│   ├── firebase/
│   │   └── firebase_init.dart
│   └── utils/
│       ├── geohash_utils.dart
│       ├── encryption_utils.dart   # Phase 3 (chat)
│       ├── app_exception.dart      # AppException.database/firestore/auth/...
│       └── app_messenger.dart      # showSuccess/Error/Info/ConfirmDialog/Loading
│
├── data/
│   ├── local/                      # Isar
│   │   ├── schemas/
│   │   │   ├── user_profile.dart
│   │   │   ├── privacy_settings.dart
│   │   │   ├── consent_log.dart
│   │   │   ├── chat_cache.dart
│   │   │   ├── saved_search.dart
│   │   │   └── app_settings.dart
│   │   └── isar_service.dart       # init + migration
│   └── remote/                     # Firebase
│       ├── firestore_service.dart
│       └── storage_service.dart
│
├── providers/                      # cross-cutting providers
│   └── isar_provider.dart          # @riverpod Isar isar()
│
├── repositories/
│   ├── search_repository.dart      # abstract + SearchFilters freezed model
│   ├── firestore_search_repository.dart
│   ├── typesense_search_repository.dart  # Phase 4 stub
│   ├── auth_repository.dart        # abstract
│   ├── auth_repository_impl.dart
│   ├── profile_repository.dart     # abstract
│   ├── profile_repository_impl.dart
│   ├── chat_repository.dart        # abstract
│   └── request_repository.dart     # abstract
│
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── screens/
│   │       └── verify_account_screen.dart
│   │
│   ├── profile/
│   │   ├── providers/
│   │   │   ├── profile_provider.dart
│   │   │   ├── privacy_provider.dart
│   │   │   ├── consent_log_provider.dart
│   │   │   └── location_service.dart  # GPS permission + geolocator
│   │   └── screens/
│   │       ├── profile_screen.dart     # main profile tab
│   │       ├── profile_editor_screen.dart
│   │       ├── privacy_editor_screen.dart
│   │       └── consent_log_screen.dart
│   │
│   ├── discovery/
│   │   ├── providers/
│   │   │   ├── search_provider.dart
│   │   │   └── filters_provider.dart
│   │   └── screens/
│   │       ├── discovery_screen.dart
│   │       ├── search_filters_screen.dart
│   │       └── public_profile_view_screen.dart
│   │
│   ├── chat/
│   │   ├── providers/
│   │   │   └── chat_provider.dart
│   │   └── screens/
│   │       ├── chat_list_screen.dart
│   │       └── chat_screen.dart
│   │
│   ├── requests/
│   │   ├── providers/
│   │   │   └── requests_provider.dart
│   │   └── screens/
│   │       ├── requests_dashboard_screen.dart
│   │       └── send_request_screen.dart
│   │
│   ├── video/                      # Φάση 4
│   │   └── screens/
│   │       └── video_call_screen.dart
│   │
│   └── settings/
│       ├── providers/
│       │   ├── settings_provider.dart
│       │   └── delete_account_provider.dart  # DeleteAccountNotifier
│       └── screens/
│           ├── settings_screen.dart
│           └── delete_account_screen.dart
│
└── shared/
    ├── widgets/
    │   ├── app_state_widget.dart   # ErrorView / LoadingView / EmptyView
    │   ├── profile_card.dart
    │   ├── online_indicator.dart
    │   ├── consent_badge.dart
    │   ├── form_section.dart       # FormSection card
    │   ├── form_toggle.dart        # FormToggle SwitchListTile
    │   ├── chip_selector.dart      # ChipSelector ChoiceChip group
    │   ├── gradient_header.dart    # GradientHeader με icon/title/subtitle/child
    │   └── save_button.dart        # SaveButton με loading state
    ├── utils/
    │   └── consent_action_config.dart  # centralized action→icon/color/label
    └── models/
        └── public_profile.dart     # read-only Firestore model (freezed)
```

---

## 16. Packages

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x

  # Local Database
  isar: ^3.x
  isar_flutter_libs: ^3.x
  path_provider: ^2.x

  # Firebase
  firebase_core: ^2.x
  firebase_auth: ^4.x
  cloud_firestore: ^4.x
  firebase_storage: ^11.x
  firebase_messaging: ^14.x
  cloud_functions: ^4.x

  # Geo
  geolocator: ^10.x
  geoflutterfire_plus: ^0.x

  # Navigation
  go_router: ^13.x

  # Encryption
  encrypt: ^5.x
  flutter_secure_storage: ^9.x
  local_auth: ^2.x           # biometric

  # i18n
  flutter_localizations:
    sdk: flutter
  intl: ^0.18.x

  # Images
  cached_network_image: ^3.x
  image_picker: ^1.x
  image_cropper: ^5.x

  # UI
  flutter_svg: ^2.x

  # Utilities
  freezed_annotation: ^2.x
  json_annotation: ^4.x
  uuid: ^4.x
  connectivity_plus: ^5.x

dev_dependencies:
  build_runner: ^2.x
  isar_generator: ^3.x
  riverpod_generator: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  flutter_lints: ^3.x
```

---

## 17. Roadmap Φάσεων

### Φάση 1 — Core & Privacy (~2 μήνες)
**Στόχος:** Λειτουργικός σκελετός με πλήρη privacy control

- [ ] Firebase init + Anonymous Auth
- [ ] Isar init με schema versioning (schemaVersion: 1)
- [ ] UserProfile CRUD (local)
- [ ] PrivacySettings editor — ανά πεδίο toggle
- [ ] ConsentLog implementation
- [ ] Publish / Unpublish toggle → Firestore
- [ ] GPS permission flow + GeoHash conversion
- [ ] i18n setup (Ελληνικά + Αγγλικά)
- [ ] Dark/Light theme από system
- [ ] Delete account (local + cloud)
- [ ] Feature flags infrastructure
- [ ] Security Rules v1

---

### Φάση 2 — Discovery (~2 μήνες)
**Στόχος:** Αναζήτηση και εύρεση χρηστών

- [x] Firestore search με geoflutterfire_plus
- [x] SearchFilters UI (ηλικία, περιοχή, interests, lookingFor)
- [x] Results dashboard (cards)
- [x] PublicProfile view screen
- [x] Saved searches
- [ ] ~~View history (ποιον είδε ο χρήστης)~~ — **deferred** (χαμηλή προτεραιότητα)
- [x] Block user (local + Firestore)
- [ ] Report user → Cloud Function
- [ ] Auto-ban Cloud Function

---

### Φάση 3 — Communication (~2 μήνες)
**Στόχος:** Πλήρης επικοινωνία μεταξύ χρηστών

- [ ] Email/Phone verification (Anonymous → Verified upgrade)
- [ ] Request system (chat / video / email request)
- [ ] Requests dashboard (open requests)
- [ ] E2E encrypted chat
- [ ] FCM push notifications
- [ ] Online presence indicator
- [ ] Read receipts
- [ ] Message expiry (opt-in)
- [ ] Email trigger via Cloud Functions
- [ ] Rate limiting Cloud Function

---

### Φάση 4+ — Advanced (ongoing)
**Στόχος:** Επεκτάσεις και premium features

- [ ] Typesense migration (swap Repository)
- [ ] Video calls (Agora RTC)
- [ ] AI matching score
- [ ] Groups / events
- [ ] Verified badge
- [ ] Premium tier
- [ ] Remote feature flags (Firebase Remote Config)
- [ ] Admin panel
- [ ] Analytics dashboard
- [ ] Web version

---

## 18. Κόστος Εκτίμηση

### Firebase (Free Spark → Blaze pay-as-you-go)

| Χρήστες | Firestore reads | Storage | FCM | Εκτίμηση |
|---|---|---|---|---|
| 0–1k | Free tier (50k reads/day) | Free (1GB) | Free | **€0/μήνα** |
| 1k–10k | ~€5–20 | ~€1–5 | Free | **€10–30/μήνα** |
| 10k–100k | ~€50–200 | ~€10–50 | Free | **€60–250/μήνα** |
| 100k+ | ~€500+ | ~€100+ | ~€100+ | **€700+/μήνα** |

### Typesense (Hetzner VPS, από Φάση 2)

| Plan | Specs | Κόστος |
|---|---|---|
| CX11 (starter) | 2vCPU, 4GB RAM | **€3.8/μήνα** |
| CX21 (growth) | 4vCPU, 8GB RAM | **€7.6/μήνα** |
| CX31 (scale) | 8vCPU, 16GB RAM | **€15/μήνα** |

### Agora (Video, Φάση 4)

- Free: 10,000 λεπτά/μήνα
- Μετά: ~€0.0015/λεπτό/χρήστη
- 1k active video users × 30 λεπτά/μήνα = €45/μήνα

### Σύνολο εκτίμηση ανά στάδιο

| Στάδιο | Users | Μηνιαίο κόστος |
|---|---|---|
| Launch | 0–1k | **€0 – €5** |
| Growth | 1k–10k | **€15–50** |
| Scale | 10k–100k | **€70–300** |
| Mature | 100k+ | **€800–1.500** |

---

## 19. GDPR & Consent

### Απαιτήσεις

Η εφαρμογή ακολουθεί τον GDPR (EU 2016/679) και τον Ελληνικό Ν. 4624/2019.

### Υλοποίηση

1. **Ρητή συγκατάθεση** για κάθε είδος δεδομένου (GPS, photos, public profile)
2. **ConsentLog** — τοπικό ιστορικό κάθε ενέργειας
3. **Δικαίωμα πρόσβασης** — ο χρήστης βλέπει ακριβώς τι είναι στο cloud (Privacy Editor)
4. **Δικαίωμα διαγραφής** — "Delete Account" διαγράφει όλα cloud δεδομένα μέσω Cloud Function
5. **Δικαίωμα φορητότητας** — Export λειτουργία (Φάση 4+)
6. **Data minimization** — ανεβαίνει μόνο ό,τι ο χρήστης επιλέξει ρητά
7. **GeoHash** αντί raw coordinates — privacy by design

### Delete Account Flow

> **Σημείωση υλοποίησης:** Στη Φάση 1, η διαγραφή γίνεται **client-side** (`auth_repository_impl.dart`): διαγράφει Firestore (public + status) + καθαρίζει Isar + διαγράφει Firebase Auth user. Το Cloud Function θα υλοποιηθεί στη **Φάση 3**, όταν θα υπάρχουν storage, requests και chat features που χρειάζονται server-side cleanup.

```dart
// Cloud Function (Φάση 3): deleteUserData(uid)
// 1. Delete users/{uid}/public
// 2. Delete users/{uid}/status
// 3. Delete Storage avatars/{uid}/ + photos/{uid}/
// 4. Mark all active requests as 'user_deleted'
// 5. Anonymize chat messages (replace content with '[deleted]')
// 6. Firebase Auth: deleteUser(uid)
// 7. Return success

// On device (μετά το Cloud Function success):
// 1. Isar.writeTxn(() => isar.clear())
// 2. flutter_secure_storage.deleteAll()
// 3. GoRouter.go('/goodbye')
```

---

## 20. Μελλοντικές Επεκτάσεις

Ο αρχιτεκτονικός σχεδιασμός προβλέπει τις παρακάτω επεκτάσεις χωρίς ανάγκη refactor:

| Feature | Προϋποθέσεις | Εκτίμηση προσπάθειας |
|---|---|---|
| Typesense search | Repository Pattern ήδη υλοποιημένο | 1 εβδομάδα |
| Video calls | FeatureFlag.videoCallEnabled | 2–3 εβδομάδες |
| AI matching | Search repo + scoring field στο Firestore | 3–4 εβδομάδες |
| Groups / Events | Νέο Firestore collection, νέο feature module | 4–6 εβδομάδες |
| Verified badge | Cloud Function ID check + badge field | 1–2 εβδομάδες |
| Premium tier | in_app_purchase + RevenueCat + FeatureFlags | 2–3 εβδομάδες |
| Web version | Flutter Web + Firebase same backend | 4–8 εβδομάδες |
| Admin panel | Firebase Admin SDK + separate Flutter app | 3–4 εβδομάδες |
| Remote feature flags | Firebase Remote Config (drop-in) | 3–5 ημέρες |
| Export data (GDPR) | Cloud Function + zip + download link | 1 εβδομάδα |
| Push-to-talk | Agora (ίδιο με video) | 1–2 εβδομάδες |
| Multi-language (additional) | .arb αρχεία μόνο | 2–3 ημέρες/γλώσσα |

---

## Σημειώσεις Υλοποίησης

### Isar Migration Pattern

```dart
// Πάντα στο isar_service.dart:
final isar = await Isar.open(
  [
    UserProfileSchema,
    PrivacySettingsSchema,
    ConsentLogSchema,
    ChatCacheSchema,
    SavedSearchSchema,
    AppSettingsSchema,
  ],
  directory: dir.path,
  name: 'nearme_db',
  inspector: kDebugMode,
);
// Σε κάθε schema αλλαγή → νέο schemaVersion + migration
```

### Riverpod Provider Patterns

```dart
// Profile — με Isar stream για real-time UI update
@riverpod
Stream<UserProfile?> userProfile(UserProfileRef ref) {
  final isar = ref.watch(isarProvider);
  return isar.userProfiles.watchObject(0);
}

// Publish/unpublish — μέσω repository από το provider
// Η λογική βρίσκεται στο ProfileRepositoryImpl, όχι σε ξεχωριστό notifier
@riverpod
ProfileRepository profileRepository(ProfileRepositoryRef ref) {
  return ProfileRepositoryImpl(
    isar: ref.watch(isarProvider),
    firestore: FirebaseFirestore.instance,
  );
}

@riverpod
Future<UserProfile?> currentProfile(CurrentProfileRef ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile();
}
```

### GoRouter Structure

```dart
// StatefulShellRoute.indexedStack — state preservation σε bottom tabs
// Adaptive shell (NavigationRail / NavigationBar) στο MainShell
// Leaf routes: siblings του StatefulShellRoute για full-screen εμπειρία

final router = GoRouter(
  redirect: (context, state) { /* firebaseReady guard + auth redirect */ },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, __, navigationShell) => MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const DiscoveryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ],
    ),
    // Push routes (slide-up transition)
    GoRoute(path: '/chat/:chatId', pageBuilder: (_, __) => _slideUp(const ChatScreen())),
    GoRoute(path: '/user/:uid', pageBuilder: (_, __) => _slideUp(const PublicProfileViewScreen())),
    // Modal routes (slide-from-bottom)
    GoRoute(path: '/profile/edit', pageBuilder: (_, __) => _modal(const ProfileEditorScreen())),
  ],
);
```

---

*Τελευταία ενημέρωση: Μάιος 2026 (v1.1)*  
*Επόμενο βήμα: Υλοποίηση Φάσης 1 — Isar schemas + Firebase init*

### Ιστορικό Αλλαγών

| Έκδοση | Ημερομηνία | Αλλαγή |
|--------|------------|--------|
| 1.0 | Μάιος 2026 | Αρχικός σχεδιασμός |
| 1.1 | Μάιος 2026 | Προσθήκη ανάλυσης Firestore compound query περιορισμού + client-side filtering στρατηγική στο Section 9 |
| 1.2 | Μάιος 2026 | Προσθήκη `/reports/{reportId}` schema με status/processedAt, `/banned/{uid}` schema, Cloud Function `onReportCreated` (Layer 5), report reasons UI (L10n) |
