import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = FirebaseOptions(
    apiKey: 'chave-sintetica',
    appId: '1:000:android:000',
    messagingSenderId: '000',
    projectId: 'caminhoazul',
  );

  test('modo emulador usa o projeto demo-caminhoazul', () {
    final options = firebaseOptionsFor(base, useEmulators: true);
    expect(options.projectId, emulatorProjectId);
    expect(options.projectId, startsWith('demo-'));
    expect(options.appId, base.appId);
  });

  test('modo emulador não leva a chave de API real', () {
    final options = firebaseOptionsFor(base, useEmulators: true);
    expect(options.apiKey, emulatorApiKey);
    expect(options.apiKey, isNot(base.apiKey));
    final real = firebaseOptionsFor(
      DefaultFirebaseOptions.web,
      useEmulators: true,
    );
    expect(real.apiKey, isNot(DefaultFirebaseOptions.web.apiKey));
  });

  test('fora do modo emulador a configuração de produção não muda', () {
    expect(firebaseOptionsFor(base, useEmulators: false), same(base));
  });

  test('configuração gerada pelo FlutterFire continua apontando para produção',
      () {
    expect(DefaultFirebaseOptions.android.projectId, 'caminhoazul');
    expect(DefaultFirebaseOptions.web.projectId, 'caminhoazul');
  });

  test('e-mails do Authentication saem em português do Brasil', () {
    expect(firebaseAuthLanguageCode, 'pt-BR');
  });

  test('testes não ativam emuladores por padrão', () {
    expect(useFirebaseEmulators, isFalse);
    expect(firebaseEmulatorHost, '10.0.2.2');
  });
}
