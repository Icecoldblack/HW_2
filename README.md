# HW_2: The Message Board Vault Hunt

**Uyiosa Nehikhuere** · CSC 4360 Mobile App Development · Homework 02 · Georgia State University

A Flutter message board backed by Firebase. A styled splash screen shows while Firebase initializes. Firebase Authentication handles registration and sign in, every registration writes a private Cloud Firestore user record, and signed in users create, read (live), update, and delete messages on a public board. Firestore security rules enforce ownership as their own layer.

## Features

| Area | What it does | Where |
|---|---|---|
| Splash | Gradient splash while `Firebase.initializeApp` runs; retry screen on failure | `lib/main.dart`, `lib/screens/splash_screen.dart` |
| AuthService | register, signIn, signOut, currentUser, `authStateChanges()` stream, friendly error translation | `lib/services/auth_service.dart` |
| Auth screens | Validated login and registration forms, duplicate submit guard, inline error banners | `lib/screens/login_screen.dart`, `register_screen.dart` |
| Routing | `AuthGate` routes purely from `authStateChanges()` | `lib/screens/auth_gate.dart` |
| User record | `users/{uid}` with uid, firstName, lastName, role, registrationDateTime (server timestamp) | `AuthService.saveUserRecord` |
| BoardService | Every Firestore call for messages behind typed methods | `lib/services/board_service.dart` |
| Live board | `snapshots()` stream ordered by server `createdAt`; loading, empty, and error states | `lib/screens/board_screen.dart` |
| Update/Delete | Own messages only (UI hides buttons; rules enforce) | `BoardScreen._edit/_delete` |
| Rules Lab | In app screen that fires cross user update/delete and forged author creates so the denial visibly comes from Firestore | `lib/screens/rules_lab_screen.dart` |
| Signed out drill | Login screen button that reads the board while signed out (expected: permission denied) | `LoginScreen._signedOutRead` |

## Auth flow

```
App launch → SplashScreen (Firebase.initializeApp, min 1.5s)
          → AuthGate listens to authStateChanges()
              ├─ user == null → LoginScreen ⇄ RegisterScreen
              └─ user != null → BoardScreen (live stream)
Register: createUserWithEmailAndPassword → write users/{uid} → updateDisplayName
          (if the Firestore write fails, the new Auth account is deleted so no user exists without a record)
Sign out: AuthService.signOut → stream emits null → LoginScreen
```

The Auth session is persisted by the SDK, so hot restart and full relaunch both return straight to the board.

## Firestore data model (storage design)

| Document | Fields | Writer | Read by | Purpose |
|---|---|---|---|---|
| `users/{uid}` | `uid`, `firstName`, `lastName`, `role`, `registrationDateTime` | Client, once, at registration (uid keyed) | Owner only | Private user record required by the spec |
| `messages/{msgId}` | `text`, `authorUid`, `authorName`, `createdAt` (server), `editedAt` (server or null) | Signed in author (create, update own, delete own) | Any signed in user | Public board, streamed live |
| `users/{uid}/prefs/{doc}` | reserved | Owner | Owner | Private per user settings (not used yet) |

**Decisions**
* Public board content and private user data live in separate collections so a single rule (`allow read: if signedIn()`) can open the board without exposing user records.
* `authorUid` is written at create time and rules require it to equal `request.auth.uid`. Updates may only touch `text` and `editedAt`, so ownership can never be reassigned.
* `createdAt` and `editedAt` must equal `request.time`, which forces `FieldValue.serverTimestamp()` and gives every device one trusted clock for ordering.
* `role` is descriptive only. It is never used to grant access because the client writes it.
* The user record is immutable from the client (`allow update, delete: if false`).

## CRUD operations

| Operation | BoardService method | Firestore call |
|---|---|---|
| Create | `createMessage(draftId, text)` | `runTransaction` → `tx.get` then `tx.set(messages/{draftId})` only if absent |
| Read (live) | `streamMessages()` | `collection('messages').orderBy('createdAt').snapshots()` |
| Update | `updateMessage(id, text)` | `doc(id).update({text, editedAt: serverTimestamp()})` |
| Delete | `deleteMessage(id)` | `doc(id).delete()` |

## Security rules

See [`firestore.rules`](firestore.rules). Summary:

* `users/{uid}`: read and create by the owner only; create must contain exactly the five fields with `uid == auth.uid` and a server timestamp; no updates or deletes.
* `messages/{msgId}`: read by any signed in user; create only with `authorUid == auth.uid`, valid text (1 to 500 chars), server `createdAt`, and only known keys; update and delete only by the author; update may change only `text` and `editedAt`.
* Everything else is denied.

Deploy with `firebase deploy --only firestore:rules`.

## Setup

Prerequisites: Flutter SDK, Android Studio or an Android emulator/device, Node.js, and a Firebase project with **Email/Password** sign in enabled and a **Cloud Firestore** database created.

```powershell
git clone https://github.com/Icecoldblack/HW_2.git
cd HW_2
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```

The script generates the Android folder (`flutter create .`), adds the `INTERNET` permission to the release manifest, sets `minSdk 23`, runs `flutter pub get`, logs into Firebase, runs `flutterfire configure` (choose your project, Android only), deploys the rules, and builds the release APK.

Manual equivalent:

```bash
flutter create . --project-name message_board --platforms android
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
firebase deploy --only firestore:rules
flutter run
```

`lib/firebase_options.dart` in the repo is a placeholder; `flutterfire configure` generates the real one. Firebase client config is not a secret, but no passwords, tokens, keystores or service account keys are committed.

## Run and test

```bash
flutter analyze
flutter test                      # validator unit tests
flutter run                       # debug on a device/emulator
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

**Five minute smoke test:** register → sign in → empty board → post → second device sees it live → edit → delete → Rules Lab denials → double tap Post leaves one document.

## Extra Spices completed

**Main Spice: Release Readiness Gate.** The release APK is installed and run through the full checklist; the record is in the evidence document.

**Spice #1: Emulator Explorer.**
```bash
firebase emulators:start --only auth,firestore --project demo-vault-board
cd rules-tests && npm install && node seed-emulator.js     # seeds 2 users + 6 messages
flutter run --dart-define=USE_EMULATOR=true                # Android emulator reaches host via 10.0.2.2
# physical device: add --dart-define=EMULATOR_HOST=<your PC LAN IP>
```
Emulator UI: http://localhost:4000. The seed script refuses to run unless the project id starts with `demo-`, and the app only connects to the emulator when `USE_EMULATOR=true`, so production data is never touched (compare the production Firestore console before and after).

**Spice #2: Rules Unit Tester.**
```bash
cd rules-tests
npm install
npm test        # starts the Firestore emulator, runs node --test rules.test.js, shuts down
```
Covers signed out read denied, cross uid update/delete denied, forged `authorUid` create denied, correct author CRUD allowed, plus five hardening cases (immutable owner fields, client clock rejected, text bounds, user record shape and privacy).

**Spice #4: Idempotent Alchemist.** Each compose action gets a random `draftId` that is kept until the post succeeds. `createMessage` runs a transaction that creates `messages/{draftId}` only if it does not exist, so a double tap, a retry after a timeout, or a second call with the same id produces exactly one document (the second call returns `false` and shows "duplicate ignored"). Trade off: Firestore transactions need a server round trip, so posting fails fast while offline instead of being queued; the user sees an error and can retry with the same id.

## Project structure

```
lib/
  main.dart                 Bootstrap + splash + emulator switch
  firebase_options.dart     generated by flutterfire configure
  models/message.dart
  services/auth_service.dart
  services/board_service.dart
  screens/ splash, auth_gate, login, register, board, rules_lab
firestore.rules  firebase.json  firestore.indexes.json
rules-tests/     rules.test.js, seed-emulator.js
scripts/setup.ps1
test/validators_test.dart
```

## References

* Firebase Flutter setup: https://firebase.google.com/docs/flutter/setup
* Firebase Auth for Flutter: https://firebase.google.com/docs/auth/flutter/start
* Firestore add/update/delete: https://firebase.google.com/docs/firestore/manage-data/add-data
* Realtime listeners: https://firebase.google.com/docs/firestore/query-data/listen
* Transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
* Security rules testing: https://firebase.google.com/docs/rules/unit-tests
* Emulator Suite: https://firebase.google.com/docs/emulator-suite
