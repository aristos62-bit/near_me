import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

const REPORT_LIMIT = 10;
const BAN_THRESHOLD = 5;

export const sendChatNotification = functions.firestore
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
    const recipientUid = participants.find((uid: string) => uid !== message.senderId);
    if (!recipientUid) return null;

    const blockSnap = await db
      .doc(`users/${recipientUid}/blocked/${message.senderId}`)
      .get();
    if (blockSnap.exists) return null;

    const [senderSnap, langSnap] = await Promise.all([
      db.doc(`users/${message.senderId}/public/profile`).get(),
      db.doc(`users/${recipientUid}/public/profile`).get(),
    ]);
    const senderName =
      senderSnap.data()?.nickname ??
      senderSnap.data()?.displayName ??
      'Someone';
    const lang = langSnap.data()?.lang ?? 'el';
    const strings = getNotificationStrings(lang);

    const tokensSnap = await db
      .collection(`users/${recipientUid}/fcm_tokens`)
      .get();
    const tokens: string[] = [];
    tokensSnap.forEach((doc) => tokens.push(doc.data().token));

    if (tokens.length === 0) return null;

    functions.logger.info(
      `Chat ${chatId}: sender=${message.senderId}, lang=${lang}, body=${strings.new_chat_message}`,
    );

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: senderName,
        body: strings.new_chat_message,
      },
      data: {
        chatId,
        type: 'chat_message',
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
      const response = await admin.messaging().sendEachForMulticast(payload);

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
            `Deleted ${invalidTokens.length} invalid tokens for ${recipientUid}`,
          );
        }
      }

      functions.logger.info(
        `Chat ${chatId}: ${response.successCount} sent, ${response.failureCount} failed`,
      );
    } catch (error) {
      functions.logger.error(`sendNotification failed for ${chatId}`, error);
    }

    return null;
  });

export const onReportCreated = functions.firestore
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

export const sendRequestNotification = functions.firestore
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
    const lang = langSnap.data()?.lang ?? 'el';
    const strings = getNotificationStrings(lang);

    let body: string;
    switch (type) {
      case 'chat':
        body = strings.request_chat;
        break;
      case 'video':
        body = strings.request_video;
        break;
      case 'email':
        body = strings.request_email;
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
      const response = await admin.messaging().sendEachForMulticast(payload);

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
      functions.logger.error(`sendRequestNotification failed for ${context.params.reqId}`, error);
    }

    return null;
  });

export const sendRequestResponseNotification = functions.firestore
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
    const lang = langSnap.data()?.lang ?? 'el';
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
        case 'email':
          body = strings.accept_email;
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

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: responderName,
        body,
      },
      data: {
        type: 'request',
        requestId: context.params.reqId,
        fromUid: toUid,
      },
      android: { priority: 'high' },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(payload);

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
        `sendRequestResponseNotification failed for ${context.params.reqId}`,
        error,
      );
    }

    return null;
  });

export const deleteUserData = functions.https.onCall(async (data, context) => {
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
function getNotificationStrings(lang: string) {
  const isGreek = lang === 'el';
  return {
    new_chat_message: isGreek ? 'Νέο μήνυμα' : 'New message',
    request_chat: isGreek ? 'Νέο αίτημα για συνομιλία' : 'Chat request',
    request_video: isGreek ? 'Νέο αίτημα για βιντεοκλήση' : 'Video call request',
    request_email: isGreek ? 'Νέο αίτημα μέσω email' : 'Email request',
    request_default: isGreek ? 'Νέο αίτημα' : 'New request',
    accept_chat: isGreek ? 'Αποδοχή αιτήματος για συνομιλία' : 'Chat request accepted',
    accept_video: isGreek ? 'Αποδοχή αιτήματος για βιντεοκλήση' : 'Video call accepted',
    accept_email: isGreek ? 'Αποδοχή αιτήματος μέσω email' : 'Email request accepted',
    accept_default: isGreek ? 'Αποδοχή αιτήματος' : 'Request accepted',
    declined: isGreek ? 'Απόρριψη αιτήματος' : 'Request declined',
  };
}

interface ReportData {
  reporterUid: string;
  reportedUid: string;
  reason: string;
  details?: string;
  createdAt: admin.firestore.Timestamp;
}
