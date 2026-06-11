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
    final colors = _colors(tone);
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

  (Color, Color) _colors(String value) {
    return switch (value) {
      'success' || 'Ativo' || 'Concluido' || 'Adequado' => (
          const Color(0xFFD1FAE5),
          AppColors.success,
        ),
      'warning' || 'Pendente' || 'Aguardando' || 'Media' || 'Requer atencao' => (
          const Color(0xFFFEF3C7),
          AppColors.warning,
        ),
      'danger' || 'Alta' => (const Color(0xFFFEE2E2), AppColors.danger),
      'purple' || 'Novo' => (const Color(0xFFF3E8FF), AppColors.purple),
      _ => (const Color(0xFFDBEAFE), AppColors.primary),
    };
  }
}
