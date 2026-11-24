import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Ativado somente com `--dart-define=USE_FIREBASE_EMULATORS=true`.
const bool useFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS');

/// Projeto usado pelo Emulator Suite e pelos seeds sintéticos. O prefixo
/// `demo-` impede que o modo emulador alcance o projeto remoto.
const String emulatorProjectId = 'demo-caminhoazul';

const String _emulatorHostOverride =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Host dos emuladores: valor do `--dart-define`, `localhost` na Web ou
/// `10.0.2.2` (máquina hospedeira vista pelo Android Emulator).
String get firebaseEmulatorHost {
  if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
  return kIsWeb ? 'localhost' : '10.0.2.2';
}

/// Chave fictícia usada no modo emulador (os emuladores aceitam qualquer
/// valor). Se alguma requisição escapar para os servidores reais, ela não
/// identifica o projeto `caminhoazul` e é recusada.
const String emulatorApiKey = 'demo-api-key-somente-emulador';

/// Idioma dos e-mails enviados pelo Firebase Authentication.
const String firebaseAuthLanguageCode = 'pt-BR';

/// Mantém a configuração de produção intacta fora do modo emulador.
FirebaseOptions firebaseOptionsFor(
  FirebaseOptions base, {
  required bool useEmulators,
}) {
  return useEmulators
      ? base.copyWith(projectId: emulatorProjectId, apiKey: emulatorApiKey)
      : base;
}

/// Configura uma instância do Auth (principal ou secundária).
///
/// Na Web a sessão fica só em memória: o app sempre começa no login e, se o
/// navegador guardasse a sessão, o `firebase_auth_web` a restauraria dentro do
/// `Firebase.initializeApp` — antes do `useAuthEmulator` — e passaria a falar
/// com os servidores reais, ignorando o erro `auth/emulator-config-failed`.
Future<void> configureFirebaseAuth(FirebaseAuth auth) async {
  // E-mails de ativação e de redefinição de senha em português: o projeto
  // remoto tem o idioma padrão `en`, e o Auth usa este código quando o envia.
  await auth.setLanguageCode(firebaseAuthLanguageCode);
  if (useFirebaseEmulators) {
    await auth.useAuthEmulator(firebaseEmulatorHost, 9099);
  }
  if (kIsWeb) {
    await auth.setPersistence(Persistence.NONE);
  }
}
