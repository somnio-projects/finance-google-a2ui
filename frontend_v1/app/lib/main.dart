import 'package:finance_app/a2ui/finance_catalog.dart';
import 'package:finance_app/app/app_config.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Initialises Firebase when the build carries its public config, then hands
/// the initialised SDK to the composition root. A build without the config —
/// the local stack — runs with no identity provider (spec frontend/0008).
///
/// The A2UI v1.0 catalog is read from the bundle first: the renderer
/// enforces it and advertises its id on every request (ADR-M D-4, D-8).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalogJson = await rootBundle.loadString(financeCatalogAsset);
  final config = AppConfig.fromEnvironment();
  final firebase = config.firebase;
  FirebaseAuth? auth;
  if (firebase != null) {
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
  runApp(
    bootstrap(config: config, firebaseAuth: auth, catalogJson: catalogJson),
  );
}
