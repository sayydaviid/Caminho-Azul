import 'package:flutter/material.dart';

import '../app/theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = 'primary',
    this.icon,
    super.key,
  });

  final String label;
  final String tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = statusBadgeColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.$2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.$2,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}

/// Fundo e texto dos selos (P2-02): texto escurecido para contraste WCAG AA
/// (≥ 4,5:1 em texto de 12 px) sobre os fundos claros.
(Color, Color) statusBadgeColors(String value) {
  return switch (value) {
    'success' || 'Ativo' || 'Concluido' || 'Adequado' =>
      (const Color(0xFFD1FAE5), const Color(0xFF047857)),
    'warning' || 'Pendente' || 'Aguardando' || 'Media' || 'Requer atencao' =>
      (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    'danger' || 'Alta' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    'purple' || 'Novo' => (const Color(0xFFF3E8FF), AppColors.purple),
    _ => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
  };
}
