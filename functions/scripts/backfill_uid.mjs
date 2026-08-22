#!/usr/bin/env node
/**
 * backfill_uid.mjs — one-time migration
 * Προσθέτει το πεδίο `uid` σε παλιά docs `users/{uid}/public/profile` που το λείπουν.
 * Διορθώνει ΟΛΕΣ τις εγκαταστάσεις (παλιές + νέες), γιατί το πρόβλημα ήταν στο data,
 * όχι στον client: τα παλιά docs γράφτηκαν πριν το publish() γράφει uid.
 *
 * Χρήση (τρέχει από τον φάκελο functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account-key.json" node scripts/backfill_uid.mjs
 *   GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account-key.json" node scripts/backfill_uid.mjs --commit
 *
 * Χωρίς --commit → DRY-RUN: μόνο σκανάρει και τυπώνει, ΔΕΝ γράφει τίποτα.
 * Service account key: Firebase Console → Project settings → Service accounts →
 * Generate new private key (project nearme-gr).
 */

import admin from 'firebase-admin';

admin.initializeApp({ credential: admin.credential.applicationDefault() });

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

const COMMIT = process.argv.includes('--commit');
const BATCH_LIMIT = 450;

// Παίρνει το uid από το path `users/{uid}/public/profile` (return null αν δεν ταιριάζει).
function uidFromPath(ref) {
  const parts = ref.path.split('/');
  if (
    parts.length === 4 &&
    parts[0] === 'users' &&
    parts[2] === 'public' &&
    parts[3] === 'profile'
  ) {
    return parts[1];
  }
  return null;
}

async function main() {
  console.log(`[backfill_uid] mode=${COMMIT ? 'COMMIT' : 'DRY-RUN'}`);

  // Το collection λέγεται 'public' (το doc μέσα λέγεται 'profile'):
  // users/{uid}/public/profile → collectionGroup('public') τα βρίσκει όλα.
  const snapshot = await db.collectionGroup('public').get();
  console.log(`[backfill_uid] σύνολο docs 'public' που βρέθηκαν: ${snapshot.size}`);

  let scanned = 0;
  const toFix = [];

  for (const doc of snapshot.docs) {
    const uid = uidFromPath(doc.ref);
    if (!uid) continue; // ασφάλεια: μόνο users/{uid}/public/profile
    scanned++;
    const data = doc.data();
    if (typeof data.uid === 'string' && data.uid.length > 0) continue; // ήδη OK
    toFix.push({ ref: doc.ref, uid });
    console.log(`  MISSING uid → ${doc.ref.path} (user=${uid})`);
  }

  console.log(
    `[backfill_uid] candidates: ${scanned} σε users/*/public/profile, missing uid: ${toFix.length}`,
  );

  if (!COMMIT) {
    console.log('[backfill_uid] DRY-RUN — δεν έγραψε τίποτα. Πρόσθεσε --commit για εκτέλεση.');
    return;
  }
  if (toFix.length === 0) {
    console.log('[backfill_uid] Τίποτα να διορθωθεί.');
    return;
  }

  let updated = 0;
  for (let i = 0; i < toFix.length; i += BATCH_LIMIT) {
    const chunk = toFix.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const { ref, uid } of chunk) {
      batch.update(ref, { uid });
    }
    await batch.commit();
    updated += chunk.length;
    console.log(`[backfill_uid] committed ${updated}/${toFix.length}...`);
  }

  console.log(`[backfill_uid] DONE — ενημερώθηκαν ${updated} docs.`);
}

main().catch((e) => {
  console.error('[backfill_uid] ERROR:', e);
  process.exit(1);
});