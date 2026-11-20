// Firebase options for project hw2-vault-board (Android).
// Equivalent to the output of `flutterfire configure --platforms=android`.
// Firebase client config is not a secret; access is controlled by
// firestore.rules. Re-run `flutterfire configure` to regenerate.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('This app is configured for Android only.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3FeWukncdJ2P87RZOwuV_r3CgpXYd1LQ',
    appId: '1:844087069309:android:fbcc507ce5ee7b162b7f14',
    messagingSenderId: '844087069309',
    projectId: 'hw2-vault-board',
    storageBucket: 'hw2-vault-board.firebasestorage.app',
  );
}
