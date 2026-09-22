import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Initialises Firebase when the build carries its public config, then hands
/// the initialised SDK to the composition root. A build without the config —
/// the local stack — runs with no identity provider (spec frontend/0008).
Future<void> main() async {
  final config = AppConfig.fromEnvironment();
  final firebase = config.firebase;
  FirebaseAuth? auth;
  if (firebase != null) {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebase.apiKey,
        appId: firebase.appId,
        projectId: firebase.projectId,
        authDomain: firebase.authDomain,
        messagingSenderId: firebase.messagingSenderId,
      ),
    );
    auth = FirebaseAuth.instance;
  }
  runApp(bootstrap(config: config, firebaseAuth: auth));
}
