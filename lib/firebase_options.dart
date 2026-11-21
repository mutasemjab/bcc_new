// Firebase configuration for project "bccnew-53344".
// Android values come from android/app/google-services.json.
// To add iOS later, run `flutterfire configure --project=bccnew-53344`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured yet. Run `flutterfire configure --project=bccnew-53344`.');
      default:
        throw UnsupportedError('BCC Chat targets Android and iOS.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC45c6i2GVMEpSRN85NeB44Ca5ylJdEwpg',
    appId: '1:165152817211:android:589021d216c32f2b1ddc1e',
    messagingSenderId: '165152817211',
    projectId: 'bccnew-53344',
    storageBucket: 'bccnew-53344.firebasestorage.app',
  );
}
