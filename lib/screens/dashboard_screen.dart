import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/custom_button.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const statIcons = [
    Icons.people_outline,
    Icons.person_search_outlined,
    Icons.schedule_outlined,
    Icons.error_outline,
    Icons.calendar_month_outlined,
    Icons.refresh_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(title: 'Dashboard', subtitle: 'Visao geral dos casos e proximos passos'),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MockData.stats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, index) {
            final stat = MockData.stats[index];
            return DashboardCard(
              label: stat.label,
              value: stat.value,
              icon: statIcons[index],
              color: _tone(stat.tone),
            );
          },
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Casos recentes',
          trailing: TextButton(onPressed: () {}, child: const Text('Ver todos')),
          child: Column(children: MockData.cases.map((item) => _CaseTile(item: item)).toList()),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Notificacoes',
          child: Column(
            children: MockData.dashboardNotices
                .map(
                  (notice) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 5, backgroundColor: _tone(notice.tone)),
                    title: Text(notice.text, style: const TextStyle(fontSize: 14)),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        const _Distribution(),
        const SizedBox(height: 16),
        _Section(
          title: 'Acoes rapidas',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CustomButton(label: 'Novo caso', icon: Icons.add, onPressed: () {}),
              CustomButton(label: 'Preencher ficha', icon: Icons.assignment_outlined, onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.observation)),
              CustomButton(label: 'Gerar relatorio', icon: Icons.description_outlined, onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.reports)),
              CustomButton(label: 'Registrar encaminhamento', icon: Icons.send_outlined, onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.referrals)),
              CustomButton(label: 'Anexar documento', icon: Icons.attach_file, onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.documents)),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static Color _tone(String tone) {
    return switch (tone) {
      'success' => AppColors.success,
      'warning' => AppColors.warning,
      'danger' => AppColors.danger,
      'purple' => AppColors.purple,
      _ => AppColors.primary,
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.item});

  final CaseRecord item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('${item.school}\n${item.stage} - ${item.updatedAt}'),
      ),
      trailing: StatusBadge(label: item.status, tone: item.status),
      isThreeLine: true,
      onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.timeline),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Em acompanhamento', 87, AppColors.success),
      ('Aguardando', 23, AppColors.warning),
      ('Pendente', 12, AppColors.danger),
      ('Ativos', 20, AppColors.primary),
    ];
    return _Section(
      title: 'Distribuicao por status',
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.$1, style: const TextStyle(color: AppColors.muted))),
                    Text('${item.$2}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
