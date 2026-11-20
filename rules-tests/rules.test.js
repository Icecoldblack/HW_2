// Spice #2: Rules Unit Tester.
// Automated security-rules tests against the Firestore emulator.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection,
  serverTimestamp, setLogLevel,
} from 'firebase/firestore';

setLogLevel('error');

let env;
const ADA = 'ada-uid';
const GRACE = 'grace-uid';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vault-board',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  // Seed one message owned by Ada (rules bypassed for seeding only).
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'messages/ada-msg'), {
      text: 'Hello from Ada',
      authorUid: ADA,
      authorName: 'Ada Lovelace',
      createdAt: new Date(),
      editedAt: null,
    });
    await setDoc(doc(ctx.firestore(), 'users/' + ADA), {
      uid: ADA, firstName: 'Ada', lastName: 'Lovelace',
      role: 'student', registrationDateTime: new Date(),
    });
  });
});

const newMessage = (uid, text = 'hi') => ({
  text, authorUid: uid, authorName: 'Tester',
  createdAt: serverTimestamp(), editedAt: null,
});

// ---- The four required cases ----

test('1. signed-out read of messages is DENIED', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(db, 'messages')));
  await assertFails(getDoc(doc(db, 'messages/ada-msg')));
});

test('2. cross-uid update and delete are DENIED', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  await assertFails(updateDoc(doc(db, 'messages/ada-msg'), {
    text: 'hijacked', editedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(db, 'messages/ada-msg')));
});

test('3. create with forged authorUid is DENIED', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  await assertFails(setDoc(doc(db, 'messages/forged'), newMessage(ADA)));
});

test('4. correct author full CRUD is ALLOWED', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  const ref = doc(db, 'messages/grace-msg');
  await assertSucceeds(setDoc(ref, newMessage(GRACE, 'Grace was here')));
  await assertSucceeds(getDocs(collection(db, 'messages')));
  await assertSucceeds(updateDoc(ref, { text: 'edited', editedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(ref));
});

// ---- Extra hardening cases ----

test('5. author cannot rewrite authorUid or createdAt on update', async () => {
  const db = env.authenticatedContext(ADA).firestore();
  await assertFails(updateDoc(doc(db, 'messages/ada-msg'), { authorUid: GRACE }));
  await assertFails(updateDoc(doc(db, 'messages/ada-msg'), { createdAt: new Date(0) }));
});

test('6. client clock createdAt is DENIED (server timestamp required)', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  await assertFails(setDoc(doc(db, 'messages/clock'), {
    ...newMessage(GRACE), createdAt: new Date(),
  }));
});

test('7. empty and oversized text are DENIED', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  await assertFails(setDoc(doc(db, 'messages/e'), newMessage(GRACE, '')));
  await assertFails(setDoc(doc(db, 'messages/b'), newMessage(GRACE, 'x'.repeat(501))));
});

test('8. users/{uid}: owner creates own record with 5 fields; others denied', async () => {
  const grace = env.authenticatedContext(GRACE).firestore();
  const record = {
    uid: GRACE, firstName: 'Grace', lastName: 'Hopper',
    role: 'student', registrationDateTime: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(grace, 'users/' + GRACE), record));
  await assertFails(getDoc(doc(grace, 'users/' + ADA)));         // not mine
  await assertFails(setDoc(doc(grace, 'users/' + ADA), record)); // not mine
  await assertFails(updateDoc(doc(grace, 'users/' + GRACE), { role: 'instructor' })); // immutable
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/' + GRACE)));
});

test('9. users/{uid}: missing field or extra field is DENIED', async () => {
  const db = env.authenticatedContext(GRACE).firestore();
  await assertFails(setDoc(doc(db, 'users/' + GRACE), {
    uid: GRACE, firstName: 'Grace', role: 'student',
    registrationDateTime: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(db, 'users/' + GRACE), {
    uid: GRACE, firstName: 'Grace', lastName: 'Hopper', role: 'student',
    registrationDateTime: serverTimestamp(), isAdmin: true,
  }));
});
