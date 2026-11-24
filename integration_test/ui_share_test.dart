// R-08 — compartilhamento do PDF pelo menu nativo do Android (AVD +
// emuladores, seed com a fase B). O teste abre o menu do sistema e o mantém
// aberto por alguns segundos para a verificação externa (adb uiautomator);
// o app não envia nada nem afirma a entrega.
//
//   flutter test integration_test/ui_share_test.dart -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:caminho_azul/app/app.dart';
import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:caminho_azul/screens/familia_acompanhamento_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/ui_driver.dart';

const _seedPassword =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('família gera o PDF e abre o menu nativo de compartilhamento',
      (tester) async {
    if (!useFirebaseEmulators) fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    await Firebase.initializeApp(
        options: firebaseOptionsFor(DefaultFirebaseOptions.currentPlatform, useEmulators: true));
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    await configureFirebaseAuth(FirebaseAuth.instance);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    await tester.pumpWidget(const CaminhoAzulApp());
    final ui = UiDriver(tester);

    await ui.login('familia', 'familia.demo@caminhoazul.test', _seedPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.tap(find.byKey(const Key('family-generate-pdf-seed-caso-demo-1')));
    await ui.tapKey('report-toggle-timeline');
    await ui.tapKey('report-toggle-returns');
    await ui.tapKey('report-generate');
    await ui.waitFor(find.byKey(const Key('report-preview')),
        timeout: const Duration(seconds: 40));
    await ui.tapKey('report-share');
    await ui.waitFor(find.textContaining('informações pessoais do estudante'));
    debugPrint('[ETAPA] confirmação exibida');
    // Não aguarda o retorno: o menu do sistema fica em primeiro plano.
    await tester.tap(find.byKey(const Key('report-share-confirm')));
    debugPrint('[ETAPA] menu nativo solicitado');
    await Future<void>.delayed(const Duration(seconds: 20));
  });
}
