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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDlkph8EsXU54accpN3hDG2mNoFCWFWilE',
    appId: '1:405928119803:web:3b89ad05a91dd768e60f5e',
    messagingSenderId: '405928119803',
    projectId: 'studyswap-e65a6',
    authDomain: 'studyswap-e65a6.firebaseapp.com',
    storageBucket: 'studyswap-e65a6.firebasestorage.app',
    measurementId: 'G-WVQ13Z2C7Q',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRXkwLSx9th8GVFez5S4qFNGvV93-FtUE',
    appId: '1:405928119803:android:b26a289eedf302e2e60f5e',
    messagingSenderId: '405928119803',
    projectId: 'studyswap-e65a6',
    storageBucket: 'studyswap-e65a6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAywksBqbxbx8RzxxjVNM66GwF7eWEsIpA',
    appId: '1:405928119803:ios:6ac5d313ebf70508e60f5e',
    messagingSenderId: '405928119803',
    projectId: 'studyswap-e65a6',
    storageBucket: 'studyswap-e65a6.firebasestorage.app',
    androidClientId:
        '405928119803-o9atmkh87gnhievubla9rg5i38cm9tsi.apps.googleusercontent.com',
    iosClientId:
        '405928119803-82tstfrq9k34epvjrpaos2ir15js4feh.apps.googleusercontent.com',
    iosBundleId: 'com.example.studyswap',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAywksBqbxbx8RzxxjVNM66GwF7eWEsIpA',
    appId: '1:405928119803:ios:6ac5d313ebf70508e60f5e',
    messagingSenderId: '405928119803',
    projectId: 'studyswap-e65a6',
    storageBucket: 'studyswap-e65a6.firebasestorage.app',
    androidClientId:
        '405928119803-o9atmkh87gnhievubla9rg5i38cm9tsi.apps.googleusercontent.com',
    iosClientId:
        '405928119803-82tstfrq9k34epvjrpaos2ir15js4feh.apps.googleusercontent.com',
    iosBundleId: 'com.example.studyswap',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDlkph8EsXU54accpN3hDG2mNoFCWFWilE',
    appId: '1:405928119803:web:410d2ae72360936ce60f5e',
    messagingSenderId: '405928119803',
    projectId: 'studyswap-e65a6',
    authDomain: 'studyswap-e65a6.firebaseapp.com',
    storageBucket: 'studyswap-e65a6.firebasestorage.app',
    measurementId: 'G-629Q573FVJ',
  );
}
