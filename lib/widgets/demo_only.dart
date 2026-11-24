import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Telas de protótipo com dados fictícios (`MockData`) só aparecem com
/// `--dart-define=CAMINHO_AZUL_DEMO=true` (P0-05). Fora desse modo, mostram um
/// estado vazio honesto, sem apresentar dados fictícios como reais.
const bool demoMode = bool.fromEnvironment('CAMINHO_AZUL_DEMO');

class DemoOnly extends StatelessWidget {
  const DemoOnly({
    required this.title,
    required this.child,
    this.enabled = demoMode,
    super.key,
  });

  final String title;
  final Widget child;

  /// Permite testar os dois estados sem recompilar.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return Center(
      key: const Key('demo-only-placeholder'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Funcionalidade em implantação. Ainda não há dados disponíveis '
              'nesta área.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
