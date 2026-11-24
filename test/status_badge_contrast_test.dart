import 'dart:math' as math;

import 'package:caminho_azul/widgets/status_badge.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-02: contraste WCAG AA dos selos de status (texto pequeno: >= 4,5:1).
void main() {
  test('todos os tons de selo atingem 4,5:1', () {
    for (final tone in ['success', 'warning', 'danger', 'purple', 'info', 'primary', 'Novo']) {
      final (background, text) = statusBadgeColors(tone);
      final a = background.computeLuminance();
      final b = text.computeLuminance();
      final ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$tone: ${ratio.toStringAsFixed(2)}');
    }
  });
}
