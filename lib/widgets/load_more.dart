import 'package:flutter/material.dart';

/// Tamanho de página das listas (P2-12): as consultas usam `limit` e a tela
/// carrega mais sob demanda, em vez de trazer a coleção inteira.
const listPageSize = 30;

/// "Carregar mais", exibido quando a página atual veio cheia.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    required this.shown,
    required this.limit,
    required this.onPressed,
    this.keyName = 'load-more',
    super.key,
  });

  final int shown;
  final int limit;
  final VoidCallback onPressed;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    if (shown < limit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: OutlinedButton.icon(
          key: Key(keyName),
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more),
          label: const Text('Carregar mais'),
        ),
      ),
    );
  }
}
