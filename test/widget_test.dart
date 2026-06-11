import 'package:caminho_azul/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a tela de login', (tester) async {
    await tester.pumpWidget(const CaminhoAzulApp());

    expect(find.text('Caminho Azul'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
