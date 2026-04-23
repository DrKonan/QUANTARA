import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXkzPpGXj6oyb1A2ELH9Gx0UeGJW9FzOY',
    appId: '1:828179538034:android:9b2bf8045a8e90bf6562eb',
    messagingSenderId: '828179538034',
    projectId: 'quantara-app-45ced',
    storageBucket: 'quantara-app-45ced.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMOsnavq8tOhTPKxMHsKZdd5M47QxUTM8',
    appId: '1:828179538034:ios:a8c25343ccc6e1ce6562eb',
    messagingSenderId: '828179538034',
    projectId: 'quantara-app-45ced',
    storageBucket: 'quantara-app-45ced.firebasestorage.app',
    iosBundleId: 'app.nakora.nakora',
  );
}
