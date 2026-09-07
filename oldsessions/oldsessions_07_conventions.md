## ΚΕΦΑΛΑΙΟ 7 — KEY CONVENTIONS
- File size ≤ 500 lines (exceptions: profile_repository_impl ~765, chat_repository_impl 1228 με εγκεκριμένα parts: delete/clear/message_actions/group_chat_mixin, main)
- `DebugConfig.log(flag, msg)` σε κάθε operational action (33 flags, 3 levels)
- `ErrorView`/`LoadingView`/`EmptyView` + `AppMessenger` — ποτέ raw ScaffoldMessenger
- Bilingual (el/en): `L10n.isGreek()` + `L10n.localizedMessage()`
- Repository pattern: abstract + impl, ποτέ raw Firestore στο UI
- Privacy-first: πλήρες profile στο Drift, minimal public snapshot στο Firestore
- GPS-first → session cache (5min) → last known → failure
- Network timeouts: auth 6s (`_withAuthTimeout`) · search CF 4s fail-open · zombie futures consumed με `unawaited(f.then<void>((_) {}, onError))` — ποτέ bare `.catchError` (runtime TypeError σε non-nullable T)
- Offline gate: fresh connectivity check ΠΡΙΝ από κάθε CF κλήση → offline = άμεσο error state, μηδενική κλήση/αναμονή
- Client CF κλήσεις: πάντα `FirebaseFunctions.instanceFor(region: 'europe-west1')`, ποτέ default instance
- Firebase project: **nearme-eu / eur3** (migration 22 Αυγ 2026 από nearme-gr/nam5 — παλιό alias `old-nam5`)

---

