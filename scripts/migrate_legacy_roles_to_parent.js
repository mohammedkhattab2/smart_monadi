#!/usr/bin/env node

/*
  Migrates legacy user roles in Firestore from "passenger" or "user" to "parent".

  Usage examples:
    node scripts/migrate_legacy_roles_to_parent.js --dry-run
    node scripts/migrate_legacy_roles_to_parent.js

  Requirements:
    - Service account credentials via GOOGLE_APPLICATION_CREDENTIALS, or
    - Application Default Credentials available to firebase-admin.
*/

const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const dryRun = process.argv.includes('--dry-run');
const batchSizeArg = process.argv.find((arg) => arg.startsWith('--batch-size='));
const batchSize = batchSizeArg ? Number(batchSizeArg.split('=')[1]) : 400;

if (!Number.isInteger(batchSize) || batchSize <= 0 || batchSize > 500) {
  console.error('[ERR] Invalid --batch-size. Choose an integer between 1 and 500.');
  process.exit(1);
}

function resolveProjectId() {
  const fromEnv =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID;
  if (fromEnv && fromEnv.trim()) {
    return fromEnv.trim();
  }

  const firebaseRcPath = path.join(__dirname, '..', '.firebaserc');
  if (!fs.existsSync(firebaseRcPath)) {
    return null;
  }

  try {
    const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, 'utf8'));
    const projects = firebaseRc && firebaseRc.projects ? firebaseRc.projects : null;
    if (!projects || typeof projects !== 'object') {
      return null;
    }

    if (projects.default && String(projects.default).trim()) {
      return String(projects.default).trim();
    }

    const firstKey = Object.keys(projects)[0];
    if (!firstKey) {
      return null;
    }

    const firstProject = projects[firstKey];
    if (firstProject && String(firstProject).trim()) {
      return String(firstProject).trim();
    }
  } catch (error) {
    console.error('[WARN] Failed to parse .firebaserc:', error.message || error);
  }

  return null;
}

function nowTs() {
  return admin.firestore.FieldValue.serverTimestamp();
}

async function main() {
  const projectId = resolveProjectId();
  if (!projectId) {
    console.error('[ERR] Unable to resolve Firebase projectId from env or .firebaserc.');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });

  const db = admin.firestore();
  console.log(`[INFO] Using projectId: ${projectId}`);

  const targets = ['passenger', 'user'];
  let scanned = 0;
  let candidateCount = 0;
  let updatedCount = 0;

  for (const legacyRole of targets) {
    const snapshot = await db.collection('users').where('role', '==', legacyRole).get();
    scanned += snapshot.size;
    candidateCount += snapshot.size;

    if (snapshot.empty) {
      console.log(`[OK] No users found with legacy role: ${legacyRole}`);
      continue;
    }

    console.log(`[INFO] Found ${snapshot.size} users with role=${legacyRole}`);

    let batch = db.batch();
    let inBatch = 0;

    for (const doc of snapshot.docs) {
      const ref = doc.ref;
      const payload = {
        role: 'parent',
        updatedAt: nowTs(),
      };

      if (dryRun) {
        console.log(`[DRY-RUN] Would update users/${doc.id} role ${legacyRole} -> parent`);
        continue;
      }

      batch.set(ref, payload, { merge: true });
      inBatch += 1;
      updatedCount += 1;

      if (inBatch >= batchSize) {
        await batch.commit();
        console.log(`[OK] Committed batch of ${inBatch} updates`);
        batch = db.batch();
        inBatch = 0;
      }
    }

    if (!dryRun && inBatch > 0) {
      await batch.commit();
      console.log(`[OK] Committed final batch of ${inBatch} updates`);
    }
  }

  console.log('--- Migration Summary ---');
  console.log(`Scanned candidates: ${scanned}`);
  console.log(`Matched legacy users: ${candidateCount}`);
  console.log(`Mode: ${dryRun ? 'DRY-RUN' : 'APPLY'}`);
  console.log(`Updated users: ${dryRun ? 0 : updatedCount}`);
  console.log('[DONE] Legacy role migration finished.');
}

main().catch((error) => {
  console.error('[ERR] Migration failed.');
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
