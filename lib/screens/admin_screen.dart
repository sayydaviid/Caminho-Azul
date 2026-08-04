import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({
    required this.user,
    required this.authService,
    super.key,
  });

  final AppUser user;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final displayName = user.name ?? user.email;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Area administrativa',
          subtitle: 'Gestao segura do Caminho Azul',
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const StatusBadge(label: 'Administrador', tone: 'success'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gerenciamento de usuarios',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Espaco reservado para cadastro e manutencao dos perfis de Escola, Familia e Saude.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context) async {
    await authService.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }
}
