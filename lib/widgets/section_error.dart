import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Aviso de falha ao carregar uma seção (P1-11): evita que um erro de leitura
/// (rede ou permissão) pareça "nenhum registro".
class SectionError extends StatelessWidget {
  const SectionError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 16, color: AppColors.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
}
