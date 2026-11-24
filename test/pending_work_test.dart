import 'dart:async';

import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

// D-A03: o login precisa esperar a limpeza da saída anterior.
void main() {
  test('wait só termina depois do trabalho em andamento', () async {
    final barrier = PendingWork();
    final gate = Completer<void>();
    final events = <String>[];
    unawaited(barrier.run(() async {
      await gate.future;
      events.add('limpeza');
    }));
    expect(barrier.busy, isTrue);
    final waiting = barrier.wait().then((_) => events.add('login'));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    gate.complete();
    await waiting;
    expect(events, ['limpeza', 'login']);
    expect(barrier.busy, isFalse);
  });

  test('erro na limpeza não impede o login de prosseguir', () async {
    final barrier = PendingWork();
    final failing = barrier.run(() async => throw StateError('falhou'));
    await expectLater(failing, throwsStateError);
    await barrier.wait();
    expect(barrier.busy, isFalse);
  });

  test('sem trabalho pendente, wait retorna imediatamente', () async {
    await PendingWork().wait();
  });
}
