import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { sendWithRetry } from './fcm-utils';
import { runSafeSearch, runSafeSearchGcs } from './moderation';

admin.initializeApp();

const db = admin.firestore();

const REPORT_LIMIT = 10;
const BAN_THRESHOLD = 5;
const SEARCH_RATE_LIMIT = 30;
const SEARCH_RATE_WINDOW_MS = 5 * 60 * 1000; // 5 λεπτά
const REGION = 'europe-west1'; // κοντά στο Firestore eur3 — δείχνει το migration

interface TokenEntry {
  uid: string;
  token: string;
  ref: admin.firestore.DocumentReference;
}

async function fetchTokensForUids(
  uids: string[],
): Promise<{ allTokens: string[]; tokenRefMap: Map<string, TokenEntry[]> }> {
  const allTokens: string[] = [];
  const tokenRefMap = new Map<string, TokenEntry[]>();

  const results = await Promise.allSettled(
    uids.map(async (uid) => {
      const snap = await db.collection(`users/${uid}/fcm_tokens`).get();
      return snap.docs.map((doc) => {
        const entry: TokenEntry = {
          uid,
          token: doc.data().token as string,
          ref: doc.ref,
        };
        return entry;
      });
    }),
  );

  for (const result of results) {
    if (result.status === 'fulfilled') {
      for (const entry of result.value) {
        const existing = tokenRefMap.get(entry.token);
        if (existing) {
          existing.push(entry);
        } else {
          tokenRefMap.set(entry.token, [entry]);
          allTokens.push(entry.token);
        }
      }
    }
  }

  return { allTokens, tokenRefMap };
}

function cleanupInvalidTokens(
  responses: admin.messaging.SendResponse[],
  tokens: string[],
  tokenRefMap: Map<string, TokenEntry[]>,
  firestore: admin.firestore.Firestore,
): void {
  const refsToDelete = new Set<admin.firestore.DocumentReference>();
  responses.forEach((resp, idx) => {
    if (
      !resp.success &&
      (resp.error?.code === 'messaging/invalid-registration-token' ||
        resp.error?.code === 'messaging/registration-token-not-registered')
    ) {
      const entries = tokenRefMap.get(tokens[idx]);
      if (entries) {
        entries.forEach((e) => refsToDelete.add(e.ref));
      }
    }
  });

  if (refsToDelete.size > 0) {
    const batch = firestore.batch();
    refsToDelete.forEach((ref) => batch.delete(ref));
    batch.commit().catch((e) =>
      functions.logger.warn('cleanupInvalidTokens batch commit failed', e),
    );
  }
}

export const sendChatNotification = functions.region(REGION).firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { chatId } = context.params;

    if (!message.senderId || message.senderId === 'system') {
      return null;
    }

    const chatSnap = await db.doc(`chats/${chatId}`).get();
    if (!chatSnap.exists) return null;

    const chatData = chatSnap.data()!;
    const participants = chatData.participants as string[];
    const isGroupChat = chatData.isGroupChat === true;
    const groupName = chatData.groupName as string | undefined;

    const senderSnap = await db.doc(`users/${message.senderId}/public/profile`).get();
    const senderName =
      senderSnap.data()?.nickname ??
      senderSnap.data()?.displayName ??
      'Someone';

    if (isGroupChat) {
      // ── Group chat: send to all participants except sender ──
      const recipientUids = participants.filter((uid: string) => uid !== message.senderId);
      if (recipientUids.length === 0) return null;

      const { allTokens, tokenRefMap } = await fetchTokensForUids(recipientUids);
      if (allTokens.length === 0) return null;

      const lang = (await db.doc(`users/${message.senderId}/public/profile`).get()).data()?.lang ?? 'en';
      const strings = getNotificationStrings(lang);

      functions.logger.info(
        `Group chat ${chatId}: sender=${message.senderId}, ${recipientUids.length} recipients, ${allTokens.length} tokens`,
      );

      const systemBody = message.type === 'system' ? (message.content as string) : null;
      const payload: admin.messaging.MulticastMessage = {
        tokens: allTokens,
        notification: {
          title: groupName ?? senderName,
          body: systemBody ?? (groupName ? senderName : strings.new_group_message),
        },
        data: {
          chatId,
          type: 'chat_message',
          isGroupChat: 'true',
          groupName: groupName ?? '',
        },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      };

      try {
        const response = await sendWithRetry(payload);
        if (response.failureCount > 0) {
          cleanupInvalidTokens(response.responses, allTokens, tokenRefMap, db);
        }
        functions.logger.info(
          `Group chat ${chatId}: ${response.successCount} sent, ${response.failureCount} failed`,
        );
      } catch (error) {
        functions.logger.error(`sendChatNotification (group) failed for ${chatId}`, error);
      }
    } else {
      // ── 1-to-1 chat (existing logic) ──
      const recipientUid = participants.find((uid: string) => uid !== message.senderId);
      if (!recipientUid) return null;

      const blockSnap = await db
        .doc(`users/${recipientUid}/blocked/${message.senderId}`)
        .get();
      if (blockSnap.exists) return null;

      const langSnap = await db.doc(`users/${recipientUid}/public/profile`).get();
      const lang = langSnap.data()?.lang ?? 'en';
      const strings = getNotificationStrings(lang);

      const tokensSnap = await db.collection(`users/${recipientUid}/fcm_tokens`).get();
      const tokens: string[] = [];
      const tokenRefMap = new Map<string, TokenEntry[]>();
      tokensSnap.forEach((doc) => {
        const token = doc.data().token as string;
        tokens.push(token);
        tokenRefMap.set(token, [{ uid: recipientUid, token, ref: doc.ref }]);
      });

      if (tokens.length === 0) return null;

      functions.logger.info(
        `Chat ${chatId}: sender=${message.senderId}, lang=${lang}, body=${strings.new_chat_message}`,
      );

      const systemBody = message.type === 'system' ? (message.content as string) : null;
      const payload: admin.messaging.MulticastMessage = {
        tokens,
        notification: { title: senderName, body: systemBody ?? strings.new_chat_message },
        data: { chatId, type: 'chat_message' },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      };

      try {
        const response = await sendWithRetry(payload);
        if (response.failureCount > 0) {
          cleanupInvalidTokens(response.responses, tokens, tokenRefMap, db);
        }
        functions.logger.info(
          `Chat ${chatId}: ${response.successCount} sent, ${response.failureCount} failed`,
        );
      } catch (error) {
        functions.logger.error(`sendChatNotification failed for ${chatId} after 3 attempts`, error);
      }
    }

    return null;
  });

export const onReportCreated = functions.region(REGION).firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const report = snap.data() as ReportData;
    const { reporterUid, reportedUid, reason } = report;

    if (!reporterUid || !reportedUid) {
      functions.logger.error('Missing reporterUid or reportedUid in report', report);
      await snap.ref.update({ status: 'invalid' });
      return null;
    }

    if (reporterUid === reportedUid) {
      functions.logger.warn(`Self-report attempt by ${reporterUid}`);
      await snap.ref.update({ status: 'self_report' });
      return null;
    }

    const existingBan = await db.doc(`banned/${reportedUid}`).get();
    if (existingBan.exists) {
      functions.logger.warn(`User ${reportedUid} is already banned`);
      await snap.ref.update({ status: 'already_banned' });
      return null;
    }

    const oneHourAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000),
    );
    const recentReports = await db
      .collection('reports')
      .where('reporterUid', '==', reporterUid)
      .where('createdAt', '>=', oneHourAgo)
      .count()
      .get();

    const rateCount = recentReports.data().count;
    if (rateCount >= REPORT_LIMIT) {
      functions.logger.warn(
        `Rate limit exceeded for reporter ${reporterUid}: ${rateCount} reports in 1h`,
      );
      await snap.ref.update({ status: 'rate_limited' });
      return null;
    }

    const existingReports = await db
      .collection('reports')
      .where('reporterUid', '==', reporterUid)
      .where('reportedUid', '==', reportedUid)
      .get();

    if (!existingReports.empty) {
      functions.logger.warn(
        `Duplicate report from ${reporterUid} for ${reportedUid}`,
      );
      await snap.ref.update({ status: 'duplicate' });
      return null;
    }

    const totalReports = await db
      .collection('reports')
      .where('reportedUid', '==', reportedUid)
      .count()
      .get();

    const reportCount = totalReports.data().count;

    if (reportCount >= BAN_THRESHOLD) {
      await db.doc(`banned/${reportedUid}`).set({
        bannedAt: admin.firestore.FieldValue.serverTimestamp(),
        reason: `Auto-ban: ${reportCount} reports (last reason: ${reason || 'N/A'})`,
        reportsCount: reportCount,
        bannedBy: 'system',
      });

      try {
        await admin.auth().setCustomUserClaims(reportedUid, { banned: true });
        functions.logger.info(`Set custom claim banned=true for ${reportedUid}`);
      } catch (err) {
        functions.logger.warn(`Failed to set custom claim for ${reportedUid}`, err);
      }

      const publicRef = db.doc(`users/${reportedUid}/public/profile`);
      try {
        await publicRef.update({ isVisible: false });
        functions.logger.info(
          `Auto-unpublished user ${reportedUid} due to ban`,
        );
      } catch (err) {
        functions.logger.warn(
          `Could not unpublish ${reportedUid}: profile may not exist`,
          err,
        );
      }

      functions.logger.info(
        `AUTO-BAN: ${reportedUid} banned with ${reportCount} reports (last reason: ${reason || 'N/A'})`,
      );

      await snap.ref.update({
        status: 'banned',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await snap.ref.update({
        status: 'processed',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.info(
        `Report ${context.params.reportId}: reporter=${reporterUid}, target=${reportedUid}, total=${reportCount}/${BAN_THRESHOLD}`,
      );
    }

    return null;
  });

export const sendRequestNotification = functions.region(REGION).firestore
  .document('requests/{reqId}')
  .onCreate(async (snap, context) => {
    const req = snap.data();
    const { fromUid, toUid, type } = req;

    if (!fromUid || !toUid || !type) {
      functions.logger.error('Missing fromUid, toUid, or type in request', req);
      return null;
    }

    if (fromUid === toUid) {
      functions.logger.warn(`Self-request from ${fromUid}`);
      return null;
    }

    const blockSnap = await db
      .doc(`users/${toUid}/blocked/${fromUid}`)
      .get();
    if (blockSnap.exists) {
      functions.logger.info(`Request from blocked user ${fromUid} to ${toUid}`);
      return null;
    }

    const [senderSnap, langSnap] = await Promise.all([
      db.doc(`users/${fromUid}/public/profile`).get(),
      db.doc(`users/${toUid}/public/profile`).get(),
    ]);
    const senderName = senderSnap.data()?.nickname ?? 'Someone';
    const lang = langSnap.data()?.lang ?? 'en';
    const strings = getNotificationStrings(lang);

    let body: string;
    switch (type) {
      case 'chat':
        body = strings.request_chat;
        break;
      case 'video':
        body = strings.request_video;
        break;
      default:
        body = strings.request_default;
    }

    const tokensSnap = await db
      .collection(`users/${toUid}/fcm_tokens`)
      .get();
    const tokens: string[] = [];
    tokensSnap.forEach((doc) => tokens.push(doc.data().token));

    if (tokens.length === 0) return null;

    functions.logger.info(
      `Request ${context.params.reqId}: from=${fromUid}, to=${toUid}, lang=${lang}, body=${body}`,
    );

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: senderName,
        body,
      },
      data: {
        type: 'request',
        requestId: context.params.reqId,
        fromUid,
      },
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    try {
      const response = await sendWithRetry(payload);

      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (
            !resp.success &&
            (resp.error?.code === 'messaging/invalid-registration-token' ||
              resp.error?.code === 'messaging/registration-token-not-registered')
          ) {
            invalidTokens.push(tokens[idx]);
          }
        });

        if (invalidTokens.length > 0) {
          const batch = db.batch();
          tokensSnap.docs.forEach((doc) => {
            if (invalidTokens.includes(doc.data().token)) {
              batch.delete(doc.ref);
            }
          });
          await batch.commit();
          functions.logger.info(
            `Deleted ${invalidTokens.length} invalid tokens for ${toUid}`,
          );
        }
      }

      functions.logger.info(
        `Request ${context.params.reqId}: ${response.successCount} sent, ${response.failureCount} failed`,
      );
    } catch (error) {
      functions.logger.error(`sendRequestNotification failed for ${context.params.reqId} after 3 attempts`, error);
    }

    return null;
  });

export const sendRequestResponseNotification = functions.region(REGION).firestore
  .document('requests/{reqId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'pending') return null;

    const newStatus = after.status;
    if (newStatus !== 'accepted' && newStatus !== 'declined') return null;

    const { fromUid, toUid, type } = after;

    if (!fromUid || !toUid || !type) {
      functions.logger.error('Missing fromUid, toUid, or type in request response', after);
      return null;
    }

    if (fromUid === toUid) {
      functions.logger.warn(`Self-response from ${toUid}`);
      return null;
    }

    const blockSnap = await db.doc(`users/${fromUid}/blocked/${toUid}`).get();
    if (blockSnap.exists) {
      functions.logger.info(`Response blocked: ${toUid} blocked by ${fromUid}`);
      return null;
    }

    const [responderSnap, langSnap] = await Promise.all([
      db.doc(`users/${toUid}/public/profile`).get(),
      db.doc(`users/${fromUid}/public/profile`).get(),
    ]);
    const responderName = responderSnap.data()?.nickname ?? 'Someone';
    const lang = langSnap.data()?.lang ?? 'en';
    const strings = getNotificationStrings(lang);

    let body: string;
    if (newStatus === 'accepted') {
      switch (type) {
        case 'chat':
          body = strings.accept_chat;
          break;
        case 'video':
          body = strings.accept_video;
          break;
        default:
          body = strings.accept_default;
      }
    } else {
      body = strings.declined;
    }

    const tokensSnap = await db.collection(`users/${fromUid}/fcm_tokens`).get();
    const tokens: string[] = [];
    tokensSnap.forEach((doc) => tokens.push(doc.data().token));
    if (tokens.length === 0) return null;

    functions.logger.info(
      `Response notif ${context.params.reqId}: from=${fromUid}, responder=${toUid}, lang=${lang}, body=${body}`,
    );

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: responderName,
        body,
      },
      data: {
        type: 'request',
        requestId: context.params.reqId,
        fromUid,
        responderUid: toUid,
      },
      android: { priority: 'high' },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      const response = await sendWithRetry(payload);

      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (
            !resp.success &&
            (resp.error?.code === 'messaging/invalid-registration-token' ||
              resp.error?.code === 'messaging/registration-token-not-registered')
          ) {
            invalidTokens.push(tokens[idx]);
          }
        });
        if (invalidTokens.length > 0) {
          const batch = db.batch();
          tokensSnap.docs.forEach((doc) => {
            if (invalidTokens.includes(doc.data().token)) {
              batch.delete(doc.ref);
            }
          });
          await batch.commit();
          functions.logger.info(
            `Deleted ${invalidTokens.length} invalid tokens for ${fromUid}`,
          );
        }
      }

      functions.logger.info(
        `Request response ${context.params.reqId} (${newStatus}): ${response.successCount} sent, ${response.failureCount} failed`,
      );
    } catch (error) {
      functions.logger.error(
        `sendRequestResponseNotification failed for ${context.params.reqId} after 3 attempts`,
        error,
      );
    }

    return null;
  });

export const deleteUserData = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  const { uid } = data;
  if (!uid || typeof uid !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'uid must be a string');
  }
  if (uid !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Can only delete own data');
  }

  const bucket = admin.storage().bucket();
  const errors: string[] = [];

  try {
    await bucket.deleteFiles({ prefix: `avatars/${uid}/` });
    functions.logger.info(`deleteUserData: deleted avatars for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete avatars for ${uid}`, e);
    errors.push('avatars');
  }

  try {
    await bucket.deleteFiles({ prefix: `photos/${uid}/` });
    functions.logger.info(`deleteUserData: deleted photos for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete photos for ${uid}`, e);
    errors.push('photos');
  }

  try {
    const sentQuery = db.collection('requests').where('fromUid', '==', uid);
    const receivedQuery = db.collection('requests').where('toUid', '==', uid);
    const [sentSnap, receivedSnap] = await Promise.all([sentQuery.get(), receivedQuery.get()]);
    const reqBatch = db.batch();
    sentSnap.docs.forEach((doc) => reqBatch.delete(doc.ref));
    receivedSnap.docs.forEach((doc) => reqBatch.delete(doc.ref));
    await reqBatch.commit();
    functions.logger.info(
      `deleteUserData: deleted ${sentSnap.size + receivedSnap.size} requests for ${uid}`,
    );
  } catch (e) {
    functions.logger.error(`deleteUserData: failed to delete requests for ${uid}`, e);
    errors.push('requests');
  }

  try {
    const chatsSnap = await db
      .collection('chats')
      .where('participants', 'array-contains', uid)
      .get();

    for (const chatDoc of chatsSnap.docs) {
      const participants: string[] = chatDoc.data().participants ?? [];
      const remaining = participants.filter((p) => p !== uid);

      if (remaining.length === 0) {
        const messagesSnap = await chatDoc.ref.collection('messages').get();
        const delBatch = db.batch();
        messagesSnap.docs.forEach((msgDoc) => delBatch.delete(msgDoc.ref));
        delBatch.delete(chatDoc.ref);
        await delBatch.commit();
        functions.logger.info(`deleteUserData: deleted orphaned chat ${chatDoc.id}`);
      } else {
        const msgSnap = await chatDoc.ref
          .collection('messages')
          .where('senderId', '==', uid)
          .get();
        if (msgSnap.size > 0) {
          const updBatch = db.batch();
          msgSnap.docs.forEach((msgDoc) =>
            updBatch.update(msgDoc.ref, {
              senderId: 'deleted_user',
              senderName: '[deleted]',
              content: '[deleted]',
            }),
          );
          updBatch.update(chatDoc.ref, { participants: remaining });
          await updBatch.commit();
          functions.logger.info(
            `deleteUserData: anonymized ${msgSnap.size} messages in chat ${chatDoc.id}`,
          );
        } else {
          await chatDoc.ref.update({ participants: remaining });
        }
      }
    }
    functions.logger.info(`deleteUserData: processed ${chatsSnap.size} chats for ${uid}`);
  } catch (e) {
    functions.logger.error(`deleteUserData: failed to process chats for ${uid}`, e);
    errors.push('chats');
  }

  try {
    await db.doc(`users/${uid}/public/profile`).delete();
    functions.logger.info(`deleteUserData: deleted public profile for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete public profile for ${uid}`, e);
    errors.push('profile');
  }

  try {
    await db.doc(`users/${uid}/status/status`).delete();
    functions.logger.info(`deleteUserData: deleted status for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete status for ${uid}`, e);
    errors.push('status');
  }

  // ── privacy/settings (orphan prevention) ──────────────────────
  try {
    await db.doc(`users/${uid}/privacy/settings`).delete();
    functions.logger.info(`deleteUserData: deleted privacy/settings for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete privacy/settings for ${uid}`, e);
    errors.push('privacy');
  }

  // ── blocked/ collection (orphan prevention) ───────────────────
  try {
    const blockedSnap = await db.collection(`users/${uid}/blocked`).get();
    if (blockedSnap.size > 0) {
      const blockedBatch = db.batch();
      blockedSnap.docs.forEach((doc) => blockedBatch.delete(doc.ref));
      await blockedBatch.commit();
      functions.logger.info(`deleteUserData: deleted ${blockedSnap.size} blocked docs for ${uid}`);
    }
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete blocked for ${uid}`, e);
    errors.push('blocked');
  }

  // ── rateLimits/search (orphan prevention) ─────────────────────
  try {
    await db.doc(`users/${uid}/rateLimits/search`).delete();
    functions.logger.info(`deleteUserData: deleted rateLimits/search for ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete rateLimits/search for ${uid}`, e);
    errors.push('rateLimits');
  }

  try {
    const tokensSnap = await db.collection(`users/${uid}/fcm_tokens`).get();
    if (tokensSnap.size > 0) {
      const tokenBatch = db.batch();
      tokensSnap.docs.forEach((doc) => tokenBatch.delete(doc.ref));
      await tokenBatch.commit();
      functions.logger.info(`deleteUserData: deleted ${tokensSnap.size} FCM tokens for ${uid}`);
    }
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete FCM tokens for ${uid}`, e);
    errors.push('fcm_tokens');
  }

  try {
    await db.doc(`users/${uid}`).delete();
    functions.logger.info(`deleteUserData: deleted user doc ${uid}`);
  } catch (e) {
    functions.logger.warn(`deleteUserData: failed to delete user doc for ${uid}`, e);
    errors.push('user_doc');
  }

  if (errors.length > 0) {
    functions.logger.warn(`deleteUserData: completed with errors for ${uid}: ${errors.join(', ')}`);
  } else {
    functions.logger.info(`deleteUserData: completed successfully for ${uid}`);
  }

  return { success: true, errors: errors.length > 0 ? errors : undefined };
  });

  // ─────────────────────────────────────────────────────────
  // computeGeoHash — server-side authoritative geoHash.
  // Πηγή αλήθειας: users/{uid}/privacy/settings.geoPrecision (SPoT).
  // Ο client στέλνει μόνο lat/lng· ποτέ το geoPrecision ή το geoHash.
  // ─────────────────────────────────────────────────────────

  const GEOHASH_BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  // Πιστό port του GeoHashUtils.encode (lib/core/utils/geohash_utils.dart).
  function encodeGeoHash(latitude: number, longitude: number, precision: number): string {
    precision = Math.max(1, Math.min(12, precision));
    let latMin = -90;
    let latMax = 90;
    let lonMin = -180;
    let lonMax = 180;
    let result = '';
    let hash = 0;
    let bits = 0;
    let isLon = true;

    while (result.length < precision) {
      if (isLon) {
        const mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          hash = (hash << 1) | 1;
          lonMin = mid;
        } else {
          hash = hash << 1;
          lonMax = mid;
        }
      } else {
        const mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          hash = (hash << 1) | 1;
          latMin = mid;
        } else {
          hash = hash << 1;
          latMax = mid;
        }
      }
      bits++;
      isLon = !isLon;
      if (bits === 5) {
        result += GEOHASH_BASE32[hash];
        hash = 0;
        bits = 0;
      }
    }
    return result;
  }

  // Πιστό port του GeoHashUtils.precisionFromSetting.
  function precisionFromSetting(geoPrecision: string): number {
    switch (geoPrecision) {
      case 'city':
        return 3;
      case 'neighborhood':
        return 5;
      case 'street':
        return 7;
      case 'hidden':
        return 0;
      default:
        return 5;
    }
  }

  export const computeGeoHash = functions.region(REGION).https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    const uid = context.auth.uid;
    const { latitude, longitude } = data;

    if (typeof latitude !== 'number' || typeof longitude !== 'number') {
      throw new functions.https.HttpsError('invalid-argument', 'latitude/longitude must be numbers');
    }
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw new functions.https.HttpsError('invalid-argument', 'latitude/longitude out of range');
    }

    try {
      const privacySnap = await db.doc(`users/${uid}/privacy/settings`).get();
      const geoPrecision =
        (privacySnap.exists && (privacySnap.data()?.geoPrecision as string)) || 'neighborhood';
      const precision = precisionFromSetting(geoPrecision);

      const publicRef = db.doc(`users/${uid}/public/profile`);
      const publicSnap = await publicRef.get();
      if (!publicSnap.exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Public profile must exist before computing geoHash',
        );
      }

      if (precision > 0) {
        const geoHash = encodeGeoHash(latitude, longitude, precision);
        await publicRef.set({ geoHash }, { merge: true });
        functions.logger.info(
          `computeGeoHash: uid=${uid} precision=${geoPrecision}(${precision}) → geoHash=${geoHash}`,
        );
        return { geoHash };
      } else {
        await publicRef.set({ geoHash: admin.firestore.FieldValue.delete() }, { merge: true });
        functions.logger.info(`computeGeoHash: uid=${uid} precision=hidden → geoHash removed`);
        return { geoHash: null };
      }
    } catch (e) {
      if (e instanceof functions.https.HttpsError) throw e;
      functions.logger.error(`computeGeoHash failed for uid=${uid}`, e);
      throw new functions.https.HttpsError('internal', 'Failed to compute geoHash');
    }
  });

// ─────────────────────────────────────────────────────────
// checkSearchRateLimit — fixed-window rate limit πάνω σε geo-search.
// Πηγή αλήθειας: users/{uid}/rateLimits/search (server-only, transaction).
// Καλείται ΠΡΙΝ από κάθε νέο search()/searchNearby() στο client — όχι
// στο loadMore() (απλή σελιδοποίηση, όχι νέο lat/lng probing).
// ─────────────────────────────────────────────────────────

export const checkSearchRateLimit = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  const uid = context.auth.uid;
  const ref = db.doc(`users/${uid}/rateLimits/search`);

  try {
    const allowed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const now = Date.now();
      const existing = snap.exists ? snap.data() : null;
      const windowStart = existing?.windowStart as number | undefined;
      const withinWindow =
        windowStart != null && now - windowStart < SEARCH_RATE_WINDOW_MS;
      const count = withinWindow ? ((existing?.count as number) ?? 0) : 0;

      if (withinWindow && count >= SEARCH_RATE_LIMIT) {
        return false;
      }

      tx.set(ref, {
        windowStart: withinWindow ? windowStart : now,
        count: count + 1,
      });
      return true;
    });

    functions.logger.info(`checkSearchRateLimit: uid=${uid} allowed=${allowed}`);
    if (!allowed) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'search_rate_limited',
      );
    }
    return { allowed: true };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    functions.logger.error(`checkSearchRateLimit failed for uid=${uid}`, e);
    // Fail-open: αν δεν μπορούμε να προσδιορίσουμε το limit, δεν μπλοκάρουμε.
    throw new functions.https.HttpsError('internal', 'Failed to check rate limit');
  }
});

  export const addGroupParticipant = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { chatId, newUid } = data;
  const callerUid = context.auth.uid;

  if (!chatId || typeof chatId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'chatId must be a string');
  }
  if (!newUid || typeof newUid !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'newUid must be a string');
  }

  const chatRef = db.doc(`chats/${chatId}`);

  try {
    const cache = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(chatRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'Chat not found');
      }

      const chatData = snap.data()!;
      const participants: string[] = chatData.participants ?? [];
      const maxP = chatData.maxParticipants ?? 10;

      if (!participants.includes(callerUid)) {
        throw new functions.https.HttpsError('permission-denied', 'Not a participant');
      }
      if (participants.includes(newUid)) {
        throw new functions.https.HttpsError('already-exists', 'Already in group');
      }
      if (participants.length >= maxP) {
        throw new functions.https.HttpsError('resource-exhausted', 'Group is full');
      }

      for (const pUid of participants) {
        const blockedSnap = await transaction.get(
          db.doc(`users/${pUid}/blocked/${newUid}`),
        );
        if (blockedSnap.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Blocked by a participant',
          );
        }
      }

      const newProfileSnap = await transaction.get(
        db.doc(`users/${newUid}/public/profile`),
      );
      const newNickname = (newProfileSnap.data()?.nickname as string) ?? newUid;
      const newAvatarUrl = newProfileSnap.data()?.avatarUrl as string | undefined;

      transaction.update(chatRef, {
        participants: admin.firestore.FieldValue.arrayUnion(newUid),
        [`participantNicknames.${newUid}`]: newNickname,
        ...(newAvatarUrl ? { [`participantAvatarUrls.${newUid}`]: newAvatarUrl } : {}),
        [`participantRoles.${newUid}`]: 'member',
        [`participantJoinedAt.${newUid}`]: admin.firestore.FieldValue.serverTimestamp(),
        [`participantInvitedBy.${newUid}`]: callerUid,
        [`participantIsActive.${newUid}`]: true,
      });

      return { newNickname, groupName: chatData.groupName };
    });

    functions.logger.info(
      `addGroupParticipant: ${newUid} added to ${chatId} by ${callerUid}`,
    );

    // ── FCM: notify the new participant ──
    const callerSnap = await db.doc(`users/${callerUid}/public/profile`).get();
    const callerName = callerSnap.data()?.nickname ?? 'Someone';

    const newUserLangSnap = await db.doc(`users/${newUid}/public/profile`).get();
    const lang = newUserLangSnap.data()?.lang ?? 'en';
    const isGreek = lang === 'el';

    const title = cache.groupName ?? (isGreek ? 'Ομάδα' : 'Group');
    const body = isGreek
      ? `Ο/Η ${callerName} σε προσκάλεσε στην ομάδα`
      : `${callerName} added you to the group`;

    const { allTokens, tokenRefMap } = await fetchTokensForUids([newUid]);

    if (allTokens.length > 0) {
      const payload: admin.messaging.MulticastMessage = {
        tokens: allTokens,
        notification: { title, body },
        data: {
          chatId,
          type: 'group_invite',
          addedBy: callerUid,
        },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      };

      try {
        const response = await sendWithRetry(payload);
        if (response.failureCount > 0) {
          cleanupInvalidTokens(response.responses, allTokens, tokenRefMap, db);
        }
        functions.logger.info(
          `addGroupParticipant FCM: ${response.successCount} sent, ${response.failureCount} failed to ${newUid}`,
        );
      } catch (error) {
        functions.logger.error(`addGroupParticipant FCM failed for ${newUid}`, error);
      }
    }

    return { success: true, chatId, newNickname: cache.newNickname };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
    functions.logger.error(`addGroupParticipant: unexpected error for ${chatId}`, e);
    throw new functions.https.HttpsError('internal', 'Internal error');
  }
});

export const leaveGroup = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { chatId } = data;
  const uid = context.auth.uid;

  if (!chatId || typeof chatId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'chatId must be a string');
  }

  const chatRef = db.doc(`chats/${chatId}`);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(chatRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'Chat not found');
      }

      const chatData = snap.data()!;
      const participants: string[] = chatData.participants ?? [];

      if (!participants.includes(uid)) {
        throw new functions.https.HttpsError(
          'failed-precondition', 'Not a participant',
        );
      }

      const nicknames = chatData.participantNicknames ?? {};
      const actorNickname = nicknames[uid] ?? uid;
      const groupName = chatData.groupName as string | undefined;
      const now = admin.firestore.FieldValue.serverTimestamp();

      const msgRef = chatRef.collection('messages').doc();
      const auditRef = chatRef.collection('audit_log').doc();

      const elMsg = groupName
        ? `${groupName}: ${actorNickname} αποχώρησε`
        : `${actorNickname} αποχώρησε`;
      const enMsg = groupName
        ? `${groupName}: ${actorNickname} left`
        : `${actorNickname} left`;

      transaction.set(msgRef, {
        senderId: uid,
        content: elMsg,
        contentEn: enMsg,
        type: 'system',
        timestamp: now,
      });

      transaction.set(auditRef, {
        action: 'participant_left',
        actorUid: uid,
        actorName: actorNickname,
        timestamp: now,
      });

      transaction.update(chatRef, {
        participants: admin.firestore.FieldValue.arrayRemove(uid),
        [`participantIsActive.${uid}`]: false,
      });

      const roles: Record<string, string> = chatData.participantRoles ?? {};
      if (roles[uid] === 'creator') {
        const activeParticipants = participants.filter((p: string) => p !== uid);
        if (activeParticipants.length > 0) {
          let newCreator = activeParticipants[0];
          for (const p of activeParticipants) {
            if (roles[p] === 'admin') { newCreator = p; break; }
          }
          transaction.update(chatRef, {
            [`participantRoles.${newCreator}`]: 'creator',
            [`participantRoles.${uid}`]: admin.firestore.FieldValue.delete(),
          });
        }
      }

      if (chatData.isPublic === true) {
        const remainingCount = participants.length - 1;
        transaction.set(
          db.collection('groups').doc(chatId),
          { memberCount: remainingCount },
          { merge: true },
        );
      }

      return { groupName: groupName ?? '' };
    });

    functions.logger.info(`leaveGroup: ${uid} left ${chatId} (group=${result.groupName})`);
    return { success: true };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    functions.logger.error(`leaveGroup failed for ${chatId}/${uid}`, e);
    throw new functions.https.HttpsError('internal', 'Internal error');
  }
});

export const expireStaleRequests = functions.region(REGION).pubsub
  .schedule('0 2 * * *')
  .timeZone('Europe/Athens')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expired = await db
      .collection('requests')
      .where('status', '==', 'pending')
      .where('expiresAt', '<', now)
      .get();

    if (expired.size === 0) {
      functions.logger.info('expireStaleRequests: no stale requests found');
      return null;
    }

    const batch = db.batch();
    expired.docs.forEach((doc) => batch.update(doc.ref, { status: 'expired' }));
    await batch.commit();

    functions.logger.info(`expireStaleRequests: expired ${expired.size} stale requests`);
    return null;
  });

export const expireStaleMessages = functions.region(REGION).pubsub
  .schedule('*/5 * * * *')
  .timeZone('Europe/Athens')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expired = await db
      .collectionGroup('messages')
      .where('expiresAt', '<', now)
      .get();

    if (expired.size === 0) {
      functions.logger.info('expireStaleMessages: no stale messages found');
      return null;
    }

    const batch = db.batch();
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    functions.logger.info(`expireStaleMessages: deleted ${expired.size} stale messages`);
    return null;
  });

export const sendReactionNotification = functions.region(REGION).firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { chatId } = context.params;

    const beforeReactions = before.reactions ?? {};
    const afterReactions = after.reactions ?? {};
    const reactorUid = Object.keys(afterReactions).find(
      (uid) => afterReactions[uid] !== beforeReactions[uid],
    );
    if (!reactorUid) return null;

    if (reactorUid === before.senderId) return null;
    if (reactorUid === 'deleted_user' || before.senderId === 'deleted_user') return null;
    if (before.senderId === 'system') return null;

    const blockSnap = await db
      .doc(`users/${before.senderId}/blocked/${reactorUid}`)
      .get();
    if (blockSnap.exists) return null;

    const reactorSnap = await db.doc(`users/${reactorUid}/public/profile`).get();
    const reactorName = reactorSnap.data()?.nickname ?? 'Someone';

    const targetLangSnap = await db.doc(`users/${before.senderId}/public/profile`).get();
    const lang = targetLangSnap.data()?.lang ?? 'en';
    const strings = getNotificationStrings(lang);
    const emoji = afterReactions[reactorUid];

    const { allTokens, tokenRefMap } = await fetchTokensForUids([before.senderId]);
    if (allTokens.length === 0) return null;

    const payload: admin.messaging.MulticastMessage = {
      tokens: allTokens,
      notification: {
        title: reactorName,
        body: `${strings.reaction} ${emoji}`,
      },
      data: {
        chatId,
        type: 'chat_message',
        action: 'reaction',
        reactionEmoji: emoji,
        reactorUid,
        reactionMessageId: context.params.messageId,
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    };

    try {
      const response = await sendWithRetry(payload);
      if (response.failureCount > 0) {
        cleanupInvalidTokens(response.responses, allTokens, tokenRefMap, db);
      }
      functions.logger.info(
        `sendReactionNotification: msg=${context.params.messageId} reactor=${reactorUid} → ${before.senderId} ${emoji}`,
      );
    } catch (error) {
      functions.logger.error('sendReactionNotification failed', error);
    }
    return null;
  });

export const sendBlockNotification = functions.region(REGION).firestore
  .document('users/{uid}/blocked/{blockedUid}')
  .onWrite(async (change, context) => {
    const { uid, blockedUid } = context.params;

    if (!uid || !blockedUid || uid === blockedUid) return null;

    const isBlock = change.after.exists; // create = block, delete = unblock

    // Διάβασε nickname του blocker και γλώσσα του blocked
    const [blockerSnap, langSnap] = await Promise.all([
      db.doc(`users/${uid}/public/profile`).get(),
      db.doc(`users/${blockedUid}/public/profile`).get().catch(() => null),
    ]);

    const blockerName = blockerSnap.data()?.nickname ?? 'Someone';
    const lang = langSnap?.data()?.lang ?? 'en';
    const strings = getNotificationStrings(lang);
    const body = isBlock ? `${blockerName} ${strings.blocked}` : `${blockerName} ${strings.unblocked}`;
    const title = blockerName;

    const { allTokens, tokenRefMap } = await fetchTokensForUids([blockedUid]);
    if (allTokens.length === 0) return null;

    const payload: admin.messaging.MulticastMessage = {
      tokens: allTokens,
      notification: { title, body },
      data: {
        type: 'block',
        action: isBlock ? 'blocked' : 'unblocked',
        blockerUid: uid,
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    };

    try {
      const response = await sendWithRetry(payload);
      if (response.failureCount > 0) {
        cleanupInvalidTokens(response.responses, allTokens, tokenRefMap, db);
      }
      functions.logger.info(
        `sendBlockNotification: ${isBlock ? 'block' : 'unblock'} ${uid} → ${blockedUid} (${response.successCount} sent, ${response.failureCount} failed)`,
      );
    } catch (error) {
      functions.logger.error(`sendBlockNotification failed for ${uid}→${blockedUid}`, error);
    }

    return null;
  });

function getNotificationStrings(lang: string) {
  const isGreek = lang === 'el';
  return {
    new_chat_message: isGreek ? 'Νέο μήνυμα' : 'New message',
    new_group_message: isGreek ? 'Νέο μήνυμα στην ομάδα' : 'New group message',
    request_chat: isGreek ? 'Νέο αίτημα για συνομιλία' : 'Chat request',
    request_video: isGreek ? 'Νέο αίτημα για βιντεοκλήση' : 'Video call request',
    request_default: isGreek ? 'Νέο αίτημα' : 'New request',
    accept_chat: isGreek ? 'Αποδοχή αιτήματος για συνομιλία' : 'Chat request accepted',
    accept_video: isGreek ? 'Αποδοχή αιτήματος για βιντεοκλήση' : 'Video call accepted',
    accept_default: isGreek ? 'Αποδοχή αιτήματος' : 'Request accepted',
    declined: isGreek ? 'Απόρριψη αιτήματος' : 'Request declined',
    reaction: isGreek ? 'Αντέδρασε' : 'Reacted',
    blocked: isGreek ? 'Σε μπλόκαρε' : 'Blocked you',
    unblocked: isGreek ? 'Σε ξεμπλόκαρε' : 'Unblocked you',
  };
}

interface ReportData {
  reporterUid: string;
  reportedUid: string;
  reason: string;
  details?: string;
  createdAt: admin.firestore.Timestamp;
}

// ─────────────────────────────────────────────────────────────
// checkImageModeration — callable, πραγματικό Vision SafeSearch.
// Καλείται ΠΡΙΝ το upload από τον client (VisionModerationService.isSafe).
// Client-side gate: FeatureFlags.contentModerationEnabled (Dart const) —
// όταν false, ο client δεν καλεί καν αυτό το function (0 κόστος).
// Fail-open στον client σε σφάλμα/timeout· εδώ πετάμε HttpsError.
// ─────────────────────────────────────────────────────────────

const MODERATION_MAX_BASE64_CHARS = 8 * 1024 * 1024; // ~6MB δυαδικά, ασφαλές όριο callable payload

export const checkImageModeration = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  const base64Image = data?.image as string | undefined;
  if (!base64Image || typeof base64Image !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing image data');
  }
  if (base64Image.length > MODERATION_MAX_BASE64_CHARS) {
    throw new functions.https.HttpsError('invalid-argument', 'Image too large for moderation');
  }
  try {
    const verdict = await runSafeSearch(base64Image);
    functions.logger.info(
      `checkImageModeration: uid=${context.auth.uid} approved=${verdict.approved}` +
      (verdict.reasons.length ? ` reasons=${verdict.reasons.join(',')}` : ''),
    );
    return verdict;
  } catch (e) {
    functions.logger.error(`checkImageModeration failed for uid=${context.auth.uid}`, e);
    throw new functions.https.HttpsError('internal', 'Moderation check failed');
  }
});

// ─────────────────────────────────────────────────────────────
// moderateImage — server-side backstop, ανεξάρτητο από τον client.
// Τρέχει σε ΚΑΘΕ upload σε avatars/photos/chat_media, ό,τι client version
// κι αν έχει ο χρήστης εγκατεστημένη — προστασία ακόμα κι αν παρακαμφθεί
// το VisionModerationService.isSafe (modified APK, κ.λπ.).
// Kill-switch ΔΙΚΟ ΤΟΥ, ξεχωριστό από το Dart FeatureFlags.contentModerationEnabled:
// Firestore doc config/moderation {enabled: true|false} — instant on/off,
// χωρίς rebuild/redeploy του app. Default: doc δεν υπάρχει → OFF (fail-open).
// Requires: npm i @google-cloud/vision (έγινε) + gcloud services enable
//           vision.googleapis.com + IAM roles/vision.user.
export const moderateImage = functions.region(REGION).storage.object().onFinalize(async (object) => {
  // Kill-switch: read Firestore config/moderation (fail-open if missing)
  try {
    const cfg = await db.doc('config/moderation').get();
    if (!cfg.exists || cfg.data()?.enabled !== true) {
      return null;
    }
  } catch (_) {
    return null; // fail-open
  }
  const path = object.name ?? '';
  if (!path.startsWith('avatars/') && !path.startsWith('photos/') && !path.startsWith('chat_media/') && !path.startsWith('group_avatars/')) {
    return null;
  }
  // Vision SafeSearch δουλεύει μόνο σε στατικές εικόνες — chat_media
  // περιέχει και audio/mp4, video/mp4 (τα video thumbnails είναι ξεχωριστό
  // image/jpeg αρχείο, αυτό ελέγχεται κανονικά).
  if (!object.contentType?.startsWith('image/')) {
    return null;
  }

  const bucket = admin.storage().bucket(object.bucket);
  const gcsUri = `gs://${object.bucket}/${path}`;

  let verdict;
  try {
    verdict = await runSafeSearchGcs(gcsUri);
  } catch (e) {
    functions.logger.error(`moderateImage: Vision call failed for ${path}`, e);
    return null; // fail-open — δεν μπλοκάρουμε λόγω σφάλματος του ίδιου του Vision
  }

  functions.logger.info(
    `moderateImage: checked ${path} approved=${verdict.approved}` +
    (verdict.reasons.length ? ` reasons=${verdict.reasons.join(',')}` : ''),
  );

  if (verdict.approved) {
    return null;
  }

  // ── Απόρριψη: διαγραφή αρχείου + ενέργεια ανά κατηγορία ──
  try {
    await bucket.file(path).delete();
  } catch (e) {
    functions.logger.error(`moderateImage: failed to delete ${path}`, e);
  }

  const segments = path.split('/');
  try {
    if (path.startsWith('avatars/') || path.startsWith('photos/')) {
      // segments[1] = uid και στα δύο patterns (avatars/{uid}/profile.jpg,
      // photos/{uid}/{index}.jpg). Κρύβουμε ολόκληρο το προφίλ από το
      // discovery μέχρι χειροκίνητο review — δεν επιχειρούμε surgical
      // αφαίρεση από το photoUrls[] array (δεν έχουμε αξιόπιστα το
      // download-token URL server-side).
      const uid = segments[1];
      if (uid) {
        await db.doc(`users/${uid}/public/profile`).set(
          { isVisible: false },
          { merge: true },
        );
      }
    } else if (path.startsWith('chat_media/')) {
      // chat_media/{chatId}/{msgId}.{ext} — ίδιο hard-delete pattern με το
      // user-initiated deleteMessage (chat_repository_message_actions.dart).
      const chatId = segments[1];
      const msgId = segments[2]?.split('.')[0];
      if (chatId && msgId) {
        await db.collection('chats').doc(chatId)
          .collection('messages').doc(msgId).delete();
      }
    } else if (path.startsWith('group_avatars/')) {
      // group_avatars/{chatId}/avatar.jpg — αντικατοπτρίζει το
      // removeGroupAvatar (group_chat_mixin.dart): σβήνουμε το groupAvatarUrl
      // ώστε το UI να μη δείχνει νεκρό URL μετά από moderation reject.
      const chatId = segments[1];
      if (chatId) {
        await db.collection('chats').doc(chatId)
          .update({
            groupAvatarUrl: admin.firestore.FieldValue.delete(),
            groupAvatarRacyLevel: admin.firestore.FieldValue.delete(),
          });
      }
    }
  } catch (e) {
    functions.logger.error(`moderateImage: cleanup action failed for ${path}`, e);
  }

  // Audit trail — χρήσιμο για support/appeals, ανεξάρτητο από την ενέργεια
  // πάνω παραπάνω (best-effort, δεν μπλοκάρει τίποτα αν αποτύχει).
  try {
    await db.collection('moderationLog').add({
      path,
      reasons: verdict.reasons,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    functions.logger.error(`moderateImage: audit log write failed for ${path}`, e);
  }

  return null;
});