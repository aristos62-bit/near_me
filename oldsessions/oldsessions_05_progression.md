## ΚΕΦΑΛΑΙΟ 5 — SESSION PROGRESSION (ΣΥΝΟΠΤΙΚΟ)

### Foundation (Sessions 1-68)
Project init, Blueprint, Isar→Drift migration, Firebase, Auth, Profile CRUD, GPS, Search prototype, Chat init, FCM, Online Presence. Riverpod 2→3, deriveKey fix, `notBanned()` rewrite. Server-side filters + cursor pagination + 300 cap.

### Communication & Profile (Sessions 69-100)
Comm settings cleanup, Chat rebuild loop fix, Auto-publish, Request validation (4-layer), Feature Flags (8), Biometric Lock, Typesense stub, GoRouter errorBuilder, PresenceService race fix, `showPhotos` privacy toggle, Schema v3→v6, Country field, Null-overwrite fix, Unit tests (30), Phone verification, SettingsScreen cascade fix, Unlink phone, `isOnline` preserve, Country filter + GPS-first + auto-publish + Nominatim + `isManualLocation`.

### Search Overhaul (Sessions 100-131)
`hasLocationFilter` flag, `WHERE country` server-side, parallel geo queries per cell, Haversine distance, cell BOUNDS fix, stale lat/lng refresh, distance display, Adaptive search precision, `getNeighbours` `*2` bug, default radius selector. Auth fixes: registration UX redirect, stale `emailVerified`, canUserCommunicate 5-layer guard.

### Sessions 132-150 (Polish & Bugfixes)
| Sess | Key Fix |
|:----:|---------|
| 132 | `userChanges()` αντί `authStateChanges()` για reload() emit |
| 133 | `_safePublicProfileFromJson()` null check για legacy docs |
| 134 | GoRouterState moved to `didChangeDependencies()` + raw AlertDialog→AppMessenger |
| 135-136 | FCM biometric lock bypass — `FcmService.isLocked` flag + pending nav guard |
| 137 | ProfileCards ~20× rebuilds — `ValueKey` + `select()` + SearchResultsGrid extraction |
| 138 | FCM retry — exponential backoff 1s→2s→4s, 3 retries |
| 139 | Unread tracking requests (readAt, blue dot, badge, FCM deep link `/requests/:id`) |
| 140 | RenderFlex overflow fixes (discovery + delete account: LayoutBuilder + SingleChildScrollView) |
| 141 | Image Cropper (1:1 avatar, free ratio photos) |
| 142 | Riverpod autoDispose race — try-catch γύρω από invalidate |
| 143 | L2 badge iOS + L4 locale `?? 'en'` + **P0 city-filter Firestore crash** |
| 144 | Saved search bool DB fix (3 columns, schema v7→v8) |
| 145-146 | Breakpoint spam fix (cache) + 16/16 files constraint-based responsive |
| 147 | `_saveSearch()` stale state + 147b: Duplicate Encrypt/Decrypt (3 fixes) |
| 148a | RenderFlex overflow (request_card_widgets: Row→Wrap) |
| 148β | Auto-scroll to last message on chat open |
| 149 | Auto-search after reset filters (preserve GPS) |
| 150 | Saved search apply async + city+radius→`_geoSearch` + GPS refresh |

### Sessions 151-170 (Critical Bugfixes + MultiChat)
| Sess | Key Fix |
|:----:|---------|
| 151 | **6× PERMISSION_DENIED after signOut** — isSigningOut flag + autoDispose + provider invalidation |
| 152 | **Biometric idle timer `inactive` + sign-out** — stop timer, reset `_isLocked` |
| 153 | **ChatCache duplicate bug** — remove `_saveChatCache` from createChat, `var rows`/`rows=[]` |
| 154 | P1.1/P2.1/P2.2 verification audit — all already fixed |
| 155 | **Online Status Flicker** — `streamOnline ?? profile.isOnline` null-coalescing |
| 156 | **Haversine Memoization** — `_distanceCache` → 96% reduction |
| 157 | **ConsentLog Pagination** — `LIMIT 50 OFFSET ?` + loadMore button |
| 158 | **MultiChat Phase 1-7** — Group chat foundation (22/31 steps) |
| 159 | **MultiChat Phase 9** — 3× P0 fixes (deleteKey isSelf, memberCount, block check groups) + deploy rules/indexes/functions |
| 160 | **CRITICAL** — `addParticipant` PERMISSION_DENIED (callable CF) + `markAsRead` PERMISSION_DENIED (rules CEL fix) + arrayUnion crash |
| 161 | UID→Nickname fixes + avatar εμφάνιση (4 screens) |
| 162 | Role-based visibility: Invites gate + isAdmin from groupPermissionsProvider |
| 163 | Bilingual system messages SPoT (`SystemMessageFormatter`) + 5 νέες actions + FCM group add |
| 164 | Split photo privacy: `showAvatar` + `showPhotos` ξεχωριστά (schema v11→v12) |
| 165 | **Delete chat 1-to-1 flow** (request + approve/reject) — ChatDeleteMixin |
| 166 | 9 delete chat fixes + maxParticipants display bug (2-tier) |
| 167 | chatsProvider dispose/recreate στο startup — `prev is AsyncData` guard |
| 168 | **Firestore Cost Phase B**: unreadCount map (zero count queries) + parallel reads + conditional verify |
| 169 | **P0 joinPublicGroup crash** (rules read/update fix + nickname refactor) + member status UI |
| 170 | **notBanned() σε 17 chat/request rules** + `isGroupMember` helper + memberCount fix |

### Sessions 171-183 (Group Chat Polish + Media Input)
| Sess | Key Fix |
|:----:|---------|
| 171 | **leaveGroup callable CF** (Admin SDK bypass for self-removal) + GoError navigation race fix |
| 172 | GroupInfo Add Member search bug — stale participantRoles keys (priority fix) |
| 173 | Blocked user add bilingual error + existing members UI (disabled Chip) + auto-localize AppMessenger |
| 174 | **Rebuild loop fix**: chatDocProvider cache + `DeepCollectionEquality` |
| 175 | Media Input Plan (`media_input.md`) + Phase 1 proposal |
| 176 | **Phase 1: Emoji Picker** — `ChatInputBar` extraction + `emoji_picker_flutter v4.4.0` |
| 177 | **Theme-aware EmojiPicker** — `EmojiPickerConfig` SPoT + responsive height |
| 178 | **ChatScreen rebuild storm** — participantUidsProvider cache + `select()` αντί direct watch |
| 179 | **EmojiPickerPanel extraction** — rebuild storm isolation (leaf widget) |
| 180 | **Instance cache** — StatefulWidget + SPoT restoration + decrypt log summary |
| 181 | **Phase 2: GIF Support** — GIPHY API (Tenor discontinued) + `GifPickerSheet` + `_GifBubble` |
| 182 | **Phase 3: Large Emoji-Only** — `EmojiOnlyBubble` (font size 64/48/36/28px) |
| 183 | **Profile Sync Across Chats** — nickname+avatar auto-sync σε όλα τα chat docs + avatar UI |

### Sessions 184-199 (Chat Features + Rebuild Cascade Elimination)
| Sess | Key Fix |
|:----:|---------|
| 184 | **Reaction System** — emoji reactions (Map<UID, emoji>), toggle, preset + custom |
| 185 | **Reply to Message** — long-press → reply banner → send (12 steps, 11 files) |
| 186 | Reply flag enable + dispose crash fix + ReplyPreview dark theme colors |
| 187 | **Viber-like Chat Redesign** — bubble tails (CustomPainter), date separators, message grouping |
| 188 | **Chat rebuild storm** — remove GoRouterState + ValueKey(msg['id']) + memoization |
| 189 | MainShell rebuild fix (StatefulWidget + cached isWide) + reply delete fix |
| 190 | **Phase 3: Image Messages** — gallery/camera, Storage upload, full-screen, storage cleanup |
| 191 | **Media "+" Popup** + multiline TextField (maxLines:5) |
| 192 | ChatMessagesList rebuild fix — `select()` return Map (deep comparison) |
| 193 | participantUidsProvider dispose/recreate cascade — remove autoDispose |
| 194 | ReadReceiptIndicator shared widget + emoji card removal + text alignment end |
| 195 | Log Analysis: `resizeToAvoidBottomInset: false` + 5 remaining issues found |
| 196 | **LayoutBuilder removal** — pre-computed `bubbleMaxWidth` (cascade eliminated) |
| 197 | **markAsRead cascade fix** — move to `initState` postFrameCallback + _MessageReadProps precompute |
| 198 | **Keyboard cascade eliminated** — `_SafeInputArea` leaf widget (26→0 rebuilds) |
| 199 | **pending=true suppression** — chatDocProvider double-emit fixed |
| 200 | **messagesStream equality caching** — `DeepCollectionEquality` σε decrypted messages list (chat_repository_impl.dart) |
| 200 | **_MessageBubbleSignature + _obtainBubble cache** — MessageBubble instances cached by signature (chat_messages_list.dart) |
| 201 | **EmojiOnlyBubble _buildCounts cleanup** — remove static debug map (memory leak, misleading cascade counters) |
| 201 | **markAsRead guard** — skip serverTimestamp write when unreadCount==0 via local Drift cache (prevents group chat cascade) |
| **206** | **Server-side authoritative geoHash** — computeGeoHash CF (πιστό GeoHashUtils port), Firestore SPoT geoPrecision, update rule blocks client geoHash write, auto-publish σε κάθε save, live distance από geoHash αντί searchState.distances, 5 files changed |
| **207** | **Mock-location detection** — `position.isMocked` check σε GPS + lastKnown, LocationFailure.mockLocationDetected, discovery_screen μήνυμα fake GPS, 2 files changed |
| **208** | **Client-side search rate limiting** — `_checkRateLimit()` στο SearchNotifier (search_provider.dart:118), fixed-window 30 queries/5min, CF `checkSearchRateLimit` με transaction, firestore.rules rateLimits write:false, fail-open σε network/CF failure |
| **209** | **deleteUserData orphaned subcollections fix** — +3 subcollection deletes (privacy/settings, blocked/, rateLimits/search) σε CF `deleteUserData` (index.ts) + client-side defense-in-depth (`auth_repository_impl.dart:76-89`) + UI list update (`delete_account_screen.dart:213-221`). backup: `backups/deleteUserData_fix_20260728_*` |
| **235** | **EU migration (eur3) ολοκλήρωση + δικτυακή διάγνωση IPv6 + αμυντικά fixes** — project nearme-gr→nearme-eu (nam5→eur3), `REGION=europe-west1` στις 12 CFs, `instanceFor` ×3 client calls · διάγνωση IPv6 blackhole router halohalo (fix στη πηγή, search TOTAL 7931→1149ms) · offline gate στην `_checkRateLimit` · auth timeouts 6s (`_withAuthTimeout`, 5 μέθοδοι) · SEARCH-PERF cleanup (−67 γρ.) · minInstances → Plan B deferred με triggers |

