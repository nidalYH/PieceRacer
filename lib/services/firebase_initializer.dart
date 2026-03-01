import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<FirebaseOptions> resolveFirebaseOptions() async {
  return DefaultFirebaseOptions.currentPlatform;
}

