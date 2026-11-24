// P2-08 — símbolo da marca (Acolhida) desenhado no app, sem pacote de SVG.
import 'package:caminho_azul/app/theme.dart';
import 'package:caminho_azul/screens/login_screen.dart';
import 'package:caminho_azul/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show FakeAuthService;

void main() {
  testWidgets('símbolo é decorativo por padrão e anunciado com rótulo', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [
        BrandMark(key: Key('decorativo')),
        BrandMark.white(semanticLabel: 'Caminho Azul'),
      ]),
    ));
    expect(tester.getSize(find.byKey(const Key('decorativo'))), const Size.square(48));
    expect(find.bySemanticsLabel('Caminho Azul'), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<BrandMarkPainter>()
        .first;
    expect(painter.tileColor, AppColors.primary);
    expect(painter.dotColor, AppColors.sidebar);
    handle.dispose();
  });

  testWidgets('login mostra o símbolo da marca, sem o ícone antigo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(authService: FakeAuthService()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-mark')), findsOneWidget);
    expect(find.byIcon(Icons.extension_outlined), findsNothing);
  });

  test('SVG do PDF usa as cores da marca e a mesma geometria', () {
    final svg = brandMarkSvg();
    expect(svg, contains('viewBox="24 24 208 208"'));
    expect(svg, contains('#2563EB'));
    expect(svg, contains('<circle cx="128" cy="128" r="27" fill="#1E3A5F"/>'));
  });
}
