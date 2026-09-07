## ΚΕΦΑΛΑΙΟ 1 — ΤΕΧΝΟΛΟΓΙΕΣ

| Layer | Επιλογή |
|---|---|
| State Management | Riverpod 3.x (Notifier, @riverpod) |
| Local DB | Drift 2.33 (SQLite, schema v12) |
| Navigation | GoRouter 17 (StatefulShellRoute) |
| Auth | Firebase (Anonymous → Email/Phone) |
| Cloud DB | Firestore (collectionGroup, 21 composite indexes) |
| Storage | Firebase Storage (avatars/photos 5MB, chat_media 50MB) |
| Functions | Firebase Functions (TypeScript, 1st Gen, 6 deployed) |
| Encryption | encrypt 5.0.3 (AES-256 GCM) + deriveKey (SHA-256) |
| Secure Storage | flutter_secure_storage (encryption keys) |
| Geo | geolocator + geoflutterfire_plus + geocoding |
| Search v1 | Firestore native (active) |
| Search v2 | Typesense self-hosted (stub, Phase 4) |
| Push | FCM (3 Cloud Functions + addGroupParticipant + leaveGroup + fcm-utils) |
| i18n | flutter_localizations + intl (el/en, L10n) |
| Biometric | local_auth 3.0 |
| Emoji | emoji_picker_flutter v4.4.0 |
| GIF | GIPHY API (dart:io HttpClient) |
| Images | image_picker + image_cropper + cached_network_image |

