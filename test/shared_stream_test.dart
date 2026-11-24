import 'dart:async';

import 'package:caminho_azul/utils/shared_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D-A04: seções de listas preguiçosas voltam a escutar o mesmo stream.
void main() {
  test('aceita novo ouvinte e reenvia o último valor', () async {
    final source = StreamController<int>();
    final shared = SharedStream(source.stream);
    final first = <int>[];
    final sub = shared.stream.listen(first.add);
    source.add(1);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // Um stream de ouvinte único falharia aqui.
    final second = <int>[];
    shared.stream.listen(second.add);
    await Future<void>.delayed(Duration.zero);
    source.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(first, [1]);
    expect(second, [1, 2]);
    expect(source.hasListener, isTrue, reason: 'uma única assinatura da origem');
    await shared.dispose();
    expect(source.hasListener, isFalse);
  });

  test('reenvia o último erro a novos ouvintes', () async {
    final source = StreamController<int>();
    final shared = SharedStream(source.stream);
    shared.stream.listen((_) {}, onError: (_) {});
    source.addError(StateError('negado'));
    await Future<void>.delayed(Duration.zero);
    await expectLater(shared.stream.first, throwsStateError);
    await shared.dispose();
  });

  testWidgets('StreamBuilder recriado ao rolar a lista não quebra',
      (tester) async {
    final source = StreamController<String>();
    final shared = SharedStream(source.stream);
    addTearDown(shared.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            StreamBuilder<String>(
              stream: shared.stream,
              builder: (_, s) => Text(s.data ?? 'carregando',
                  key: const Key('section')),
            ),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 100, child: Text('item $i')),
          ],
        ),
      ),
    ));
    source.add('linha do tempo');
    await tester.pump();
    expect(find.text('linha do tempo'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('section')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('linha do tempo'), findsOneWidget);
  });
}
