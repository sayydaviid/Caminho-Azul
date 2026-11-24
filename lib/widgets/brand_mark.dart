import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Símbolo "Acolhida" da marca Caminho Azul: três peças (escola, família e
/// saúde) em volta do ponto central (o estudante); o canto aberto é o caminho
/// adiante. Arte-mestre e guia de uso em `docs/identidade/`.
///
/// Geometria no quadro de 256 (caixa útil de 24 a 232): peças de 100 com
/// cantos de 20 e vão de 8, mordida circular de raio 54 e ponto de raio 27,
/// ambos centrados em (128, 128). Desenhado com [CustomPaint] para não exigir
/// pacote de SVG.
class BrandMark extends StatelessWidget {
  const BrandMark({
    this.size = 48,
    this.tileColor = AppColors.primary,
    this.dotColor = AppColors.sidebar,
    this.semanticLabel,
    super.key,
  });

  /// Versão em uma cor, branca, para fundos escuros ou azuis.
  const BrandMark.white({this.size = 48, this.semanticLabel, super.key})
      : tileColor = Colors.white,
        dotColor = Colors.white;

  final double size;
  final Color tileColor;
  final Color dotColor;

  /// Sem rótulo, o símbolo é decorativo (o nome ao lado já é lido).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: BrandMarkPainter(tileColor: tileColor, dotColor: dotColor),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: mark);
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.tileColor, required this.dotColor});

  final Color tileColor;
  final Color dotColor;

  static const _box = 208.0; // 232 - 24
  static const _origin = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas
      ..save()
      ..translate((size.width - _box * scale) / 2, (size.height - _box * scale) / 2)
      ..scale(scale)
      ..translate(-_origin, -_origin);
    RRect tile(double x, double y) => RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 100, 100), const Radius.circular(20));
    final tiles = Path()
      ..addRRect(tile(24, 24))
      ..addRRect(tile(24, 132))
      ..addRRect(tile(132, 132));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: const Offset(128, 128), radius: 54));
    canvas
      ..drawPath(Path.combine(PathOperation.difference, tiles, bite),
          Paint()..color = tileColor)
      ..drawCircle(const Offset(128, 128), 27, Paint()..color = dotColor)
      ..restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.tileColor != tileColor || oldDelegate.dotColor != dotColor;
}

/// Mesmo símbolo em SVG (cores em hexadecimal), para o PDF (`pw.SvgImage`).
String brandMarkSvg({String tiles = '#2563EB', String dot = '#1E3A5F'}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="24 24 208 208">'
    '<path fill="$tiles" d="M44 24H104A20 20 0 0 1 124 44V74.15A54 54 0 0 0 74.15 124'
    'H44A20 20 0 0 1 24 104V44A20 20 0 0 1 44 24Z'
    'M44 132H74.15A54 54 0 0 0 124 181.85V212A20 20 0 0 1 104 232H44'
    'A20 20 0 0 1 24 212V152A20 20 0 0 1 44 132Z'
    'M181.85 132H212A20 20 0 0 1 232 152V212A20 20 0 0 1 212 232H152'
    'A20 20 0 0 1 132 212V181.85A54 54 0 0 0 181.85 132Z"/>'
    '<circle cx="128" cy="128" r="27" fill="$dot"/></svg>';
