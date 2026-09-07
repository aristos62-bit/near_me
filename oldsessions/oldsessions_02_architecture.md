## ΚΕΦΑΛΑΙΟ 2 — ΑΡΧΙΤΕΚΤΟΝΙΚΕΣ ΑΠΟΦΑΣΕΙΣ

### Auth — Anonymous + Lazy Upgrade
Χρήστης ξεκινά ανώνυμος → upgrade σε verified (email/phone) μόνο όταν θελήσει επικοινωνία. `canUserCommunicate` = `!user.isAnonymous && (user.emailVerified || hasPhone)`.

### Γεωγραφία — GPS με fallback manual
GPS → lat/lng στο Drift (ΠΟΤΕ raw στο Firestore). GeoHash μόνο στο Firestore με precision levels (default: neighborhood ~2.5km²). Fallback: text field για χειροκίνητη πόλη/χώρα.

### Search — Υβριδικό (Repository Pattern)
Firestore native (τώρα) → Typesense (Phase 4). Abstract SearchRepository — swap χωρίς UI changes. 4 query paths: GPS-only, City+radius, City-only, Country-only. Cursor pagination + 300 cap.

### Security Architecture (5-Layer)
1. **Device**: Drift + flutter_secure_storage + FLAG_SECURE + Biometric Lock + Auto-lock timer
2. **Auth**: Anonymous → Email/Phone verify, `userChanges()` (όχι `authStateChanges()`)
3. **Data Rules**: Firestore Security Rules (7 helpers, 21 composite indexes)
4. **Transport**: TLS 1.3 + AES-256 GCM E2E chat (deriveKey deterministic)
5. **Behaviour**: Rate limiting (10 reports/hr), auto-ban (5 reports), request expiry (48h), 6 Cloud Functions

### Data Flow
- **Local (Drift)**: UserProfile (23 fields), PrivacySettings (13 toggles), ConsentLog (paginated LIMIT 50), ChatCache, SavedSearch, AppSettings, BlockedUser
- **Firestore**: users/{uid}/public (snapshot), status (isOnline), blocked, fcm_tokens, chats/{chatId}/messages (AES-256), requests, reports, banned
- **Repository Pattern**: 7 abstract interfaces — ποτέ raw Firestore στο UI

