import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_30VUqC4aNYZONz-TuElEtqxgKSbOW_I',
    appId: '1:1026970483734:android:5807ac1247c05ef3af4937',
    messagingSenderId: '1026970483734',
    projectId: 'lanchesimples-d101b',
    storageBucket: 'lanchesimples-d101b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJS3C3uZh2MM-oMIrumTRgrq64QSx7wAM',
    appId: '1:1026970483734:ios:a6a2a65dd3bfac75af4937',
    messagingSenderId: '1026970483734',
    projectId: 'lanchesimples-d101b',
    storageBucket: 'lanchesimples-d101b.firebasestorage.app',
    iosBundleId: 'com.example.lanchesimples',
  );

  static bool get hasValidConfiguration {
    const values = <String>[
      android.apiKey,
      android.appId,
      android.messagingSenderId,
      android.projectId,
      android.storageBucket,
      ios.apiKey,
      ios.appId,
      ios.messagingSenderId,
      ios.projectId,
      ios.storageBucket,
      ios.iosBundleId!,
    ];

    return values.every(
      (value) => value.isNotEmpty && !value.startsWith('YOUR_'),
    );
  }
}
