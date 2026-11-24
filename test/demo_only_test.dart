import 'package:caminho_azul/widgets/demo_only.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fora do modo demonstração os dados fictícios não aparecem',
      (tester) async {
    expect(demoMode, isFalse);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DemoOnly(title: 'Linha do tempo', child: Text('Lucas Oliveira')),
      ),
    ));
    expect(find.text('Lucas Oliveira'), findsNothing);
    expect(find.byKey(const Key('demo-only-placeholder')), findsOneWidget);
    expect(find.text('Linha do tempo'), findsOneWidget);
  });

  testWidgets('no modo demonstração o protótipo é exibido', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DemoOnly(
          title: 'Linha do tempo',
          enabled: true,
          child: Text('Lucas Oliveira'),
        ),
      ),
    ));
    expect(find.text('Lucas Oliveira'), findsOneWidget);
  });
}
