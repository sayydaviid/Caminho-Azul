import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/firebase_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: firebaseOptionsFor(
      DefaultFirebaseOptions.currentPlatform,
      useEmulators: useFirebaseEmulators,
    ),
  );
  // Sem cache persistente de dados sensíveis (modo offline fora do escopo).
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);
  await configureFirebaseAuth(FirebaseAuth.instance);
  if (useFirebaseEmulators) {
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  }
  runApp(const CaminhoAzulApp());
}
