const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();
const db = admin.firestore();

// Initialize Google Play Developer API
// You need to set up a service account and enable the Google Play Android Developer API
const auth = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});
const androidPublisher = google.androidpublisher({
  version: 'v3',
  auth: auth,
});

// ============ SUBMISSION FUNCTIONS ============

/**
 * Secure Confession Submission
 * Enforces cooldowns and profanity checks on the server side
 */
exports.submitConfession = functions.https.onCall(async (data, context) => {
  // 1. Auth Check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const { content, category, city, state, country, isPaid } = data;
  const userId = context.auth.uid;

  // 2. Validate Inputs
  if (!content || !category) {
    throw new functions.https.HttpsError('invalid-argument', 'Content and category are required.');
  }

  try {
    // 3. Rate Limiting & Daily Reset Check
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const now = new Date();

    let dailyPostCount = userData.dailyPostCount || 0;
    const lastPostTime = userData.lastPostTime ? userData.lastPostTime.toDate() : null;

    // Auto-Reset count if 12 hours have passed since last post
    if (lastPostTime) {
      const diffMs = now.getTime() - lastPostTime.getTime();
      if (diffMs > 12 * 60 * 60 * 1000) {
        dailyPostCount = 0;
      }
    }

    // 4. Validate Content Length (Server-Side)
    if (content.length > 500) {
      throw new functions.https.HttpsError('invalid-argument', 'Confession too long (max 500 chars).');
    }

    // Check if it's a paid post (isPaid is already extracted from data in line 30)
    if (isPaid === true) {
      if ((userData.paidConfessionCredits || 0) <= 0) {
        throw new functions.https.HttpsError('failed-precondition', 'No paid credits available.');
      }
    } else {
      // Check Daily Limit (5 posts)
      if (dailyPostCount >= 5) {
        throw new functions.https.HttpsError('resource-exhausted', 'Daily limit reached for today.');
      }

      // Check 10-minute cooldown
      if (lastPostTime) {
        const diffMs = now.getTime() - lastPostTime.getTime();
        const diffMin = diffMs / (1000 * 60);
        if (diffMin < 10) {
          throw new functions.https.HttpsError('resource-exhausted', `Cooldown active. Try again in ${Math.ceil(10 - diffMin)} minutes.`);
        }
      }
    }

    // 4. Hardened Profanity Check (Server-Side)
    const leetMap = {
      '4': 'a', '@': 'a', '3': 'e', '1': 'i', '!': 'i', '0': 'o', '5': 's', '$': 's', '7': 't', '8': 'b'
    };

    // Normalize content: leetspeak conversion + remove all symbols/numbers
    let superNormalized = content.toLowerCase();
    for (const [key, value] of Object.entries(leetMap)) {
      superNormalized = superNormalized.split(key).join(value);
    }
    superNormalized = superNormalized.replace(/[^a-z]/g, '');

    const bannedPatterns = [
      /ch[u]*t[i]*y[a]*/i, /bkch[o]*d/i, /mdrch[o]*d/i, /b[h]*nch[o]*d/i,
      /f[u]*ck/i, /sh[i]*t/i, /b[i]*tch/i, /wh[o]*re/i, /r[a]*pe/i, /sl[u]*t/i,
      /p[u]*ss[y]*/i, /d[i]*ck/i, /p[e]*n[i]*s/i, /v[a]*g[i]*n[a]/i
    ];

    for (const pattern of bannedPatterns) {
      if (pattern.test(superNormalized) || pattern.test(content) || pattern.test(content.toLowerCase())) {
        throw new functions.https.HttpsError('invalid-argument', 'Inappropriate language detected. Please be respectful.');
      }
    }

    // 5. Success -> Write to Firestore
    const batch = db.batch();

    const confessionRef = db.collection('confessions').doc();
    batch.set(confessionRef, {
      content: content,
      category: category,
      userId: userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reactionCounts: { '❤️': 0, '😢': 0, '😮': 0, '🔥': 0 },
      isTop: false,
      isHighlighted: false,
      highlightEndTime: null,
      city: city || null,
      state: state || null,
      country: country || null,
      reportCount: 0,
      isPaid: isPaid,
    });

    if (isPaid === true) {
      // Consume credit
      batch.update(db.collection('users').doc(userId), {
        paidConfessionCredits: admin.firestore.FieldValue.increment(-1),
      });
    } else {
      // Update cooldown for free post
      batch.set(db.collection('users').doc(userId), {
        lastPostTime: admin.firestore.FieldValue.serverTimestamp(),
        dailyPostCount: dailyPostCount + 1,
      }, { merge: true });
    }

    await batch.commit();

    return { success: true, confessionId: confessionRef.id };

  } catch (error) {
    console.error('Submission failed:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Submission failed: ' + error.message);
  }
});

exports.verifyPurchase = functions.https.onCall(async (data, context) => {
  // 1. Auth Check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const { confessionId, productId, purchaseToken } = data;
  const userId = context.auth.uid;

  // 2. Validate Inputs (confessionId is optional for credit purchases)
  if (!productId || !purchaseToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
  }

  try {
    // 3. REPLAY PROTECTION: Check if token was used
    const tokenRef = db.collection('used_tokens').doc(purchaseToken);
    const tokenSnap = await tokenRef.get();
    if (tokenSnap.exists) {
      throw new functions.https.HttpsError('already-exists', 'This purchase has already been claimed.');
    }

    // 4. Verify with Google Play (PRODUCTION READY)
    // Replace with your real package name from Google Play Console
    const packageName = 'com.confess.app.confess_app';

    try {
      const purchase = await androidPublisher.purchases.products.get({
        packageName: packageName,
        productId: productId,
        token: purchaseToken,
      });

      // purchaseState: 0 (Purchased), 1 (Canceled), 2 (Pending)
      if (purchase.data.purchaseState !== 0) {
        throw new functions.https.HttpsError('permission-denied', 'Invalid or canceled purchase.');
      }
    } catch (apiError) {
      console.error('Google Play API Error:', apiError);
      // NOTE: In production, you MUST ensure your Service Account has access.
      // If the API call fails, we reject the claim for safety.
      throw new functions.https.HttpsError('internal', 'Could not verify with Google Play API.');
    }

    // 4. Handle based on Product Type
    if (productId.startsWith('highlight_')) {
      if (!confessionId) throw new functions.https.HttpsError('invalid-argument', 'Confession ID required for highlights.');

      let durationHours = productId.includes('48h') ? 48 : 24;
      const endTime = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + durationHours * 60 * 60 * 1000)
      );

      await db.collection('confessions').doc(confessionId).update({
        isHighlighted: true,
        highlightEndTime: endTime,
        isTop: true,
        highlightedBy: userId,
      });
      console.log(`Highlighted confession ${confessionId} for user ${userId}`);

    } else if (productId === 'paid_confession_10') {
      // Credit Purchase (e.g., 10 credits or similar)
      // Note: adjust the increment based on your actual product definition
      await db.collection('users').doc(userId).update({
        paidConfessionCredits: admin.firestore.FieldValue.increment(1),
      });
      console.log(`Added credit to user ${userId}`);

    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid product ID.');
    }

    // 5. Mark token as used securely
    await tokenRef.set({
      userId,
      productId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };

  } catch (error) {
    console.error('Purchase verification failed:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Verification failed: ' + error.message);
  }
});

// ============ NOTIFICATION FUNCTIONS ============

/**
 * Helper: Check if user can receive a notification today (max 1/day)
 */
async function canSendNotification(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return true;

  const data = userDoc.data();
  const settings = data.notificationSettings || {};

  // Check if notifications are enabled
  if (settings.enabled === false) return false;

  const lastNotifTime = data.lastNotificationTime;
  if (!lastNotifTime) return true;

  // Check if last notification was today
  const now = new Date();
  const lastNotif = lastNotifTime.toDate();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const lastNotifDate = new Date(
    lastNotif.getFullYear(),
    lastNotif.getMonth(),
    lastNotif.getDate()
  );

  // If last notification was on a different day, allow
  return lastNotifDate < today;
}

/**
 * Helper: Record that a notification was sent
 */
async function recordNotification(userId) {
  await db.collection('users').doc(userId).set({
    lastNotificationTime: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Helper: Send FCM notification
 */
async function sendNotification(userId, title, body, data) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return;

  const fcmToken = userDoc.data().fcmToken;
  if (!fcmToken) return;

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data || {},
    token: fcmToken,
  };

  try {
    await admin.messaging().send(message);
    console.log(`Notification sent to user ${userId}`);
  } catch (error) {
    console.error(`Failed to send notification to ${userId}:`, error);
  }
}

/**
 * Trigger: New Confession Posted
 * Sends a generic notification to random users (not the author)
 */
exports.onNewConfession = functions.firestore
  .document('confessions/{confessionId}')
  .onCreate(async (snap, context) => {
    const confession = snap.data();
    const authorId = confession.userId;

    // Get all users with FCM tokens (excluding author)
    const usersSnapshot = await db.collection('users')
      .where('fcmToken', '!=', null)
      .limit(50) // Limit to avoid overwhelming
      .get();

    const eligibleUsers = [];
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      if (userId === authorId) continue; // Skip author

      const settings = userDoc.data().notificationSettings || {};
      if (settings.enabled === false || settings.newConfessionAlerts === false) {
        continue;
      }

      if (await canSendNotification(userId)) {
        eligibleUsers.push(userId);
      }
    }

    // Send to a random subset (e.g., 5 users) to avoid spam
    const selectedUsers = eligibleUsers
      .sort(() => 0.5 - Math.random())
      .slice(0, 5);

    for (const userId of selectedUsers) {
      await sendNotification(
        userId,
        'Someone just shared something important.',
        'Tap to see what\'s on their mind.',
        { type: 'new_confession' }
      );
      await recordNotification(userId);
    }
  });

/**
 * Trigger: Reaction Added
 * Notifies the confession author (generic message)
 */
exports.onReaction = functions.firestore
  .document('reactions/{reactionId}')
  .onCreate(async (snap, context) => {
    const reaction = snap.data();
    const confessionId = reaction.confessionId;
    const reactorId = reaction.userId;

    // Get confession to find author
    const confessionDoc = await db.collection('confessions').doc(confessionId).get();
    if (!confessionDoc.exists) return;

    const authorId = confessionDoc.data().userId;
    if (authorId === reactorId) return; // Don't notify self

    // Check user settings
    const authorDoc = await db.collection('users').doc(authorId).get();
    if (!authorDoc.exists) return;

    const settings = authorDoc.data().notificationSettings || {};
    if (settings.enabled === false || settings.reactionAlerts === false) {
      return;
    }

    // Check daily limit
    if (!(await canSendNotification(authorId))) {
      console.log(`Daily limit reached for user ${authorId}`);
      return;
    }

    // Send generic notification (no reaction type or confession content)
    await sendNotification(
      authorId,
      'Someone reacted to your confession.',
      'Your words resonated with someone.',
      { type: 'reaction', confessionId: confessionId }
    );
    await recordNotification(authorId);
  });

/**
 * Scheduled: Daily Reminder
 * Runs once per day at 8 PM (adjust timezone as needed)
 * Sends to users who haven't received a notification today
 */
exports.scheduledDailyReminder = functions.pubsub
  .schedule('0 20 * * *') // 8 PM daily (IST)
  .timeZone('Asia/Kolkata') // Set to Indian Standard Time
  .onRun(async (context) => {
    console.log('Running daily reminder...');

    // Get all users with FCM tokens
    const usersSnapshot = await db.collection('users')
      .where('fcmToken', '!=', null)
      .get();

    let sentCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const settings = userDoc.data().notificationSettings || {};

      // Check if daily reminders are enabled
      if (settings.enabled === false || settings.dailyReminders === false) {
        continue;
      }

      // Only send if user hasn't received a notification today
      if (await canSendNotification(userId)) {
        await sendNotification(
          userId,
          'Holding something inside?',
          'You\'re not alone. Share anonymously.',
          { type: 'daily_reminder' }
        );
        await recordNotification(userId);
        sentCount++;
      }
    }

    console.log(`Daily reminder sent to ${sentCount} users`);
    return null;
  });

/**
 * Secure Reporting
 * Enforces limits and prevents duplicates on the server
 */
exports.submitReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const { confessionId, reason } = data;
  const userId = context.auth.uid;

  if (!confessionId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing fields.');
  }

  try {
    const reportId = `${confessionId}_${userId}`;
    const reportRef = db.collection('reports').doc(reportId);
    const reportSnap = await reportRef.get();

    if (reportSnap.exists) {
      throw new functions.https.HttpsError('already-exists', 'You have already reported this.');
    }

    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};
    const now = new Date();

    let dailyReportCount = userData.dailyReportCount || 0;
    const lastReportTime = userData.lastReportTime ? userData.lastReportTime.toDate() : null;

    // Reset daily report count if 12 hours passed
    if (lastReportTime) {
      const diffMs = now.getTime() - lastReportTime.getTime();
      if (diffMs > 12 * 60 * 60 * 1000) dailyReportCount = 0;
    }

    if (dailyReportCount >= 5) {
      throw new functions.https.HttpsError('resource-exhausted', 'Daily report limit reached.');
    }

    // Success -> Atomic update
    const batch = db.batch();

    batch.set(reportRef, {
      confessionId: confessionId,
      reporterId: userId,
      reason: reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    batch.update(db.collection('confessions').doc(confessionId), {
      reportCount: admin.firestore.FieldValue.increment(1),
    });

    batch.set(userRef, {
      lastReportTime: admin.firestore.FieldValue.serverTimestamp(),
      dailyReportCount: dailyReportCount + 1,
    }, { merge: true });

    await batch.commit();
    return { success: true };

  } catch (error) {
    console.error('Report failed:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Report failed.');
  }
});

/**
 * Secure Reaction Toggling
 * Prevents direct manipulation of like counts and spamming
 */
exports.toggleReaction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
  }

  const { confessionId, reactionType } = data;
  const userId = context.auth.uid;

  if (!confessionId || !reactionType) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing fields.');
  }

  const validEmojis = ['❤️', '😢', '😮', '🔥'];
  if (!validEmojis.includes(reactionType)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid reaction type.');
  }

  try {
    const reactionId = `${confessionId}_${userId}`;
    const reactionRef = db.collection('reactions').doc(reactionId);
    const confessionRef = db.collection('confessions').doc(confessionId);

    return await db.runTransaction(async (transaction) => {
      const reactionSnap = await transaction.get(reactionRef);
      const confessionSnap = await transaction.get(confessionRef);

      if (!confessionSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Confession not found.');
      }

      if (!reactionSnap.exists) {
        // 1. ADD NEW REACTION
        transaction.set(reactionRef, {
          confessionId,
          userId,
          reactionType,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(confessionRef, {
          [`reactionCounts.${reactionType}`]: admin.firestore.FieldValue.increment(1),
        });
        return { success: true, action: 'added' };
      } else {
        const oldType = reactionSnap.data().reactionType;

        if (oldType === reactionType) {
          // 2. REMOVE REACTION (Same type tapped again)
          transaction.delete(reactionRef);
          transaction.update(confessionRef, {
            [`reactionCounts.${reactionType}`]: admin.firestore.FieldValue.increment(-1),
          });
          return { success: true, action: 'removed' };
        } else {
          // 3. CHANGE REACTION (Different type tapped)
          transaction.update(reactionRef, { reactionType });
          transaction.update(confessionRef, {
            [`reactionCounts.${oldType}`]: admin.firestore.FieldValue.increment(-1),
            [`reactionCounts.${reactionType}`]: admin.firestore.FieldValue.increment(1),
          });
          return { success: true, action: 'changed' };
        }
      }
    });

  } catch (error) {
    console.error('Reaction failed:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', 'Reaction system error.');
  }
});

