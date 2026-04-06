const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineSecret } = require('firebase-functions/params');
const twilio = require('twilio');

admin.initializeApp();
setGlobalOptions({ region: 'us-central1' });

const db = admin.firestore();

const TWILIO_ACCOUNT_SID = defineSecret('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = defineSecret('TWILIO_AUTH_TOKEN');
const TWILIO_FROM_NUMBER = defineSecret('TWILIO_FROM_NUMBER');

const MAX_ATTEMPTS = 3;
const PROCESSING_LOCK_MINUTES = 2;

function normalizeSmsError(error) {
  const message = error instanceof Error ? error.message : 'Unknown SMS error';
  const code = error && typeof error.code !== 'undefined' ? String(error.code) : null;

  let category = 'unknown';
  let userMessage = 'SMS sending failed. Please retry later.';

  const lower = message.toLowerCase();
  if (lower.includes('trial accounts cannot send') || lower.includes('unverified')) {
    category = 'trial_unverified_number';
    userMessage = 'Twilio trial cannot send to unverified recipient numbers.';
  } else if (code === '21211' || lower.includes('invalid') && lower.includes('number')) {
    category = 'invalid_phone_number';
    userMessage = 'The recipient phone number is invalid.';
  } else if (code === '21606' || lower.includes('from') && lower.includes('not a valid')) {
    category = 'invalid_from_number';
    userMessage = 'Twilio from number is invalid for this account.';
  } else if (code === '20003' || lower.includes('authenticate')) {
    category = 'auth_error';
    userMessage = 'Twilio authentication failed. Check credentials.';
  }

  return {
    rawMessage: message,
    code,
    category,
    userMessage,
  };
}

function currentDayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function incrementMetric(metricKey) {
  const docRef = db.collection('sms_metrics').doc(currentDayKey());
  await docRef.set(
    {
      [metricKey]: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function addDeliveryEvent(messageId, type, payload = {}) {
  await db.collection('sms_delivery_events').add({
    messageId,
    type,
    payload,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function moveToDeadLetter(messageId, data) {
  await db.collection('sms_outbox_dead_letter').doc(messageId).set(
    {
      ...data,
      movedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function renderSmsBody(template, variables = {}) {
  if (template === 'arriving_soon') {
    return `Smart Monadi: Bus is approaching for ${variables.name ?? 'passenger'}. Pickup around ${variables.pickupTime ?? 'soon'}.`;
  }

  if (template === 'arrival_now') {
    return `Smart Monadi: Bus has arrived for ${variables.name ?? 'passenger'}. Please be ready now.`;
  }

  return `Smart Monadi update for ${variables.name ?? 'passenger'}.`;
}

function renderPushTitle(template) {
  if (template === 'arriving_soon') {
    return 'Smart Monadi: Bus approaching';
  }
  if (template === 'arrival_now') {
    return 'Smart Monadi: Bus arrived';
  }
  return 'Smart Monadi update';
}

async function sendPushToPassenger(payload) {
  const passengerId = (payload.passengerId || '').toString();
  if (!passengerId) {
    return;
  }

  const userDoc = await db.collection('users').doc(passengerId).get();
  if (!userDoc.exists) {
    return;
  }

  const data = userDoc.data() || {};
  const rawTokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
  const tokens = rawTokens
    .map((t) => (typeof t === 'string' ? t.trim() : ''))
    .filter((t) => t.length > 0);

  if (tokens.length === 0) {
    return;
  }

  const body = renderSmsBody(payload.template, payload.variables);
  const title = renderPushTitle(payload.template);

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      template: (payload.template || '').toString(),
      passengerId,
    },
  });

  const invalidTokens = [];
  response.responses.forEach((item, index) => {
    if (item.success) {
      return;
    }
    const code = item.error && item.error.code ? item.error.code : '';
    if (code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-argument') {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await db.collection('users').doc(passengerId).set(
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

async function sendSmsAndUpdate(messageId, payload, secrets) {
  const docRef = db.collection('sms_outbox').doc(messageId);
  const currentStatus = (payload.status || '').toString();
  const currentAttempts = Number(payload.attempts || 0);

  if (currentStatus === 'sent') {
    return;
  }

  if (currentAttempts >= MAX_ATTEMPTS) {
    await docRef.set(
      {
        status: 'failed_permanent',
        processingBy: admin.firestore.FieldValue.delete(),
        processingAt: admin.firestore.FieldValue.delete(),
        lockExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await moveToDeadLetter(messageId, {
      reason: 'max_attempts_reached_before_send',
      attempts: currentAttempts,
      toPhone: payload.toPhone,
      template: payload.template,
      variables: payload.variables || {},
      originalPayload: payload,
      errorCategory: payload.errorCategory || null,
      errorCode: payload.errorCode || null,
      errorUserMessage: payload.errorUserMessage || null,
      errorMessage: payload.errorMessage || null,
    });
    await addDeliveryEvent(messageId, 'failed_permanent', {
      reason: 'max_attempts_reached_before_send',
      attempts: currentAttempts,
    });
    await incrementMetric('failedPermanentCount');
    return;
  }

  const body = renderSmsBody(payload.template, payload.variables);
  const client = twilio(secrets.accountSid, secrets.authToken);

  try {
    const result = await client.messages.create({
      from: secrets.fromNumber,
      to: payload.toPhone,
      body,
    });

    await docRef.set(
      {
        status: 'sent',
        body,
        provider: 'twilio',
        providerMessageSid: result.sid,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        processingBy: admin.firestore.FieldValue.delete(),
        processingAt: admin.firestore.FieldValue.delete(),
        lockExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info('SMS sent', { messageId, sid: result.sid, to: payload.toPhone });
    await addDeliveryEvent(messageId, 'sent', {
      sid: result.sid,
      to: payload.toPhone,
      attempts: currentAttempts,
    });
    await sendPushToPassenger(payload);
    await incrementMetric('sentCount');
  } catch (error) {
    const normalized = normalizeSmsError(error);
    const attempts = currentAttempts + 1;
    const backoffMinutes = Math.min(15, attempts * 2);
    const nextRetryAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + backoffMinutes * 60 * 1000),
    );

    await docRef.set(
      {
        status: attempts >= MAX_ATTEMPTS ? 'failed_permanent' : 'failed',
        attempts,
        body,
        errorMessage: normalized.rawMessage,
        errorCode: normalized.code,
        errorCategory: normalized.category,
        errorUserMessage: normalized.userMessage,
        nextRetryAt,
        processingBy: admin.firestore.FieldValue.delete(),
        processingAt: admin.firestore.FieldValue.delete(),
        lockExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (attempts >= MAX_ATTEMPTS) {
      await moveToDeadLetter(messageId, {
        reason: 'max_attempts_reached_after_send_errors',
        attempts,
        toPhone: payload.toPhone,
        template: payload.template,
        variables: payload.variables || {},
        originalPayload: payload,
        errorMessage: normalized.rawMessage,
        errorCode: normalized.code,
        errorCategory: normalized.category,
        errorUserMessage: normalized.userMessage,
      });
      await addDeliveryEvent(messageId, 'failed_permanent', {
        attempts,
        errorMessage: normalized.rawMessage,
        errorCategory: normalized.category,
        errorUserMessage: normalized.userMessage,
      });
      await incrementMetric('failedPermanentCount');
    } else {
      await addDeliveryEvent(messageId, 'failed_retry_scheduled', {
        attempts,
        errorMessage: normalized.rawMessage,
        errorCategory: normalized.category,
        errorUserMessage: normalized.userMessage,
      });
      await incrementMetric('failedCount');
    }

    logger.error('SMS send failed', {
      messageId,
      attempts,
      to: payload.toPhone,
      error: normalized.rawMessage,
      errorCategory: normalized.category,
      errorCode: normalized.code,
    });
  }
}

async function tryClaimMessage(messageId, allowedStatuses, workerId) {
  const docRef = db.collection('sms_outbox').doc(messageId);
  const nowDate = new Date();
  const lockExpiryDate = new Date(
    nowDate.getTime() + PROCESSING_LOCK_MINUTES * 60 * 1000,
  );

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    if (!snap.exists) {
      return null;
    }

    const data = snap.data() || {};
    const status = (data.status || '').toString();
    const nextRetryAt = data.nextRetryAt;
    const lockExpiresAt = data.lockExpiresAt;

    if (!allowedStatuses.includes(status)) {
      return null;
    }

    if (nextRetryAt instanceof admin.firestore.Timestamp && nextRetryAt.toDate() > nowDate) {
      return null;
    }

    if (lockExpiresAt instanceof admin.firestore.Timestamp && lockExpiresAt.toDate() > nowDate) {
      return null;
    }

    tx.set(
      docRef,
      {
        status: 'processing',
        processingBy: workerId,
        processingAt: admin.firestore.FieldValue.serverTimestamp(),
        lockExpiresAt: admin.firestore.Timestamp.fromDate(lockExpiryDate),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { id: messageId, ...data };
  });
}

async function processOutboxByStatus(statuses, secrets) {
  const now = admin.firestore.Timestamp.now();
  const workerId = `worker-${Date.now()}`;
  const candidates = await db
    .collection('sms_outbox')
    .where('status', 'in', statuses)
    .where('nextRetryAt', '<=', now)
    .limit(20)
    .get();

  if (candidates.empty) {
    return 0;
  }

  let processed = 0;
  for (const doc of candidates.docs) {
    const claimed = await tryClaimMessage(doc.id, statuses, workerId);
    if (!claimed) {
      continue;
    }
    processed += 1;
    await sendSmsAndUpdate(doc.id, claimed, secrets);
  }

  return processed;
}

exports.onSmsOutboxCreated = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'UTC',
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER],
  },
  async () => {
    const secrets = {
      accountSid: TWILIO_ACCOUNT_SID.value(),
      authToken: TWILIO_AUTH_TOKEN.value(),
      fromNumber: TWILIO_FROM_NUMBER.value(),
    };

    const processed = await processOutboxByStatus(['pending'], secrets);
    logger.info('Pending outbox processing complete', { processed });
  },
);

exports.retryFailedSmsOutbox = onSchedule(
  {
    schedule: 'every 2 minutes',
    timeZone: 'UTC',
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER],
  },
  async () => {
    const secrets = {
      accountSid: TWILIO_ACCOUNT_SID.value(),
      authToken: TWILIO_AUTH_TOKEN.value(),
      fromNumber: TWILIO_FROM_NUMBER.value(),
    };

    const processed = await processOutboxByStatus(['failed'], secrets);
    if (processed === 0) {
      logger.info('No sms_outbox retries pending');
      return;
    }

    logger.info('Failed outbox retry complete', { processed });
  },
);
