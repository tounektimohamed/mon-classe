// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // REMPLACEZ CES VALEURS PAR LES VÔTRES
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyA3MCEzAmK163Kqj4b-v5nZQOndWQKedis",
    authDomain: "scoutetrampe.firebaseapp.com",
    projectId: "scoutetrampe",
    storageBucket: "scoutetrampe.firebasestorage.app",
    messagingSenderId: "120598335519",
    appId: "1:120598335519:web:9d433ea9f57d7202c2c52a",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'zoom-3c767',
    storageBucket: 'zoom-3c767.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'zoom-3c767',
    storageBucket: 'zoom-3c767.appspot.com',
    iosBundleId: 'com.example.monClasseManegment',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'zoom-3c767',
    storageBucket: 'zoom-3c767.appspot.com',
    iosBundleId: 'com.example.monClasseManegment',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'zoom-3c767',
    authDomain: 'zoom-3c767.firebaseapp.com',
    storageBucket: 'zoom-3c767.appspot.com',
  );
}
