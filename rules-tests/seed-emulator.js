// Spice #1: Emulator Explorer seed script.
// Seeds the LOCAL Auth + Firestore emulators with test users and messages.
// Run while `firebase emulators:start --only auth,firestore` is running:
//   node seed-emulator.js
// It refuses to run unless emulator hosts are set, so production is never touched.
import { initializeApp } from 'firebase/app';
import {
  getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signOut,
} from 'firebase/auth';
import {
  getFirestore, connectFirestoreEmulator, doc, setDoc, serverTimestamp,
} from 'firebase/firestore';

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-vault-board';
if (!PROJECT.startsWith('demo-')) {
  console.error('Refusing to seed: project id must start with "demo-" (emulator only).');
  process.exit(1);
}

const app = initializeApp({ projectId: PROJECT, apiKey: 'fake-emulator-key' });
const auth = getAuth(app);
const db = getFirestore(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
connectFirestoreEmulator(db, '127.0.0.1', 8080);

const people = [
  { email: 'ada@test.dev', first: 'Ada', last: 'Lovelace', role: 'student' },
  { email: 'grace@test.dev', first: 'Grace', last: 'Hopper', role: 'instructor' },
];

for (const p of people) {
  const { user } = await createUserWithEmailAndPassword(auth, p.email, 'password123');
  await setDoc(doc(db, 'users', user.uid), {
    uid: user.uid, firstName: p.first, lastName: p.last,
    role: p.role, registrationDateTime: serverTimestamp(),
  });
  for (let i = 1; i <= 3; i++) {
    await setDoc(doc(db, 'messages', `${p.first.toLowerCase()}-seed-${i}`), {
      text: `Seed message ${i} from ${p.first}`,
      authorUid: user.uid,
      authorName: `${p.first} ${p.last}`,
      createdAt: serverTimestamp(),
      editedAt: null,
    });
  }
  console.log(`Seeded ${p.email} (uid ${user.uid}) with 3 messages`);
  await signOut(auth);
}
console.log('Done. Open http://localhost:4000 to view the Emulator UI.');
process.exit(0);
