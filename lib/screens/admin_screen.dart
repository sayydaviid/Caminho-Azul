import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/custom_button.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String tab = 'instituicoes';
  String query = '';

  static const tabs = [
    ('instituicoes', 'Instituicoes', Icons.business_outlined),
    ('profissionais', 'Profissionais', Icons.person_add_alt_outlined),
    ('rede', 'Rede Local', Icons.location_on_outlined),
    ('usuarios', 'Usuarios', Icons.people_outline),
    ('parametros', 'Parametros', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
            title: 'Administracao',
            subtitle: 'Gestao da rede local Caminho Azul'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: CustomButton(
                    label: 'Exportar',
                    icon: Icons.download_outlined,
                    onPressed: () {})),
            const SizedBox(width: 8),
            Expanded(
                child: CustomButton(
                    label: 'Novo cadastro',
                    icon: Icons.add,
                    primary: true,
                    onPressed: () {})),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  avatar: Icon(item.$3, size: 17),
                  label: Text(item.$2),
                  selected: tab == item.$1,
                  onSelected: (_) => setState(() => tab = item.$1),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => query = value.toLowerCase()),
          decoration: const InputDecoration(
              hintText: 'Buscar...', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 16),
        _content(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _content() {
    return switch (tab) {
      'profissionais' => _Professionals(query: query),
      'rede' => _Network(query: query),
      'usuarios' => const _Users(),
      'parametros' => const _Parameters(),
      _ => _Institutions(query: query),
    };
  }
}

class _Institutions extends StatelessWidget {
  const _Institutions({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final items = MockData.institutions
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
          children: items.map((item) => _InstitutionTile(item: item)).toList()),
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({required this.item});

  final InstitutionRecord item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
          backgroundColor: Color(0xFFDBEAFE),
          child: Icon(Icons.business_outlined, color: AppColors.primary)),
      title:
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '${item.type} - ${item.owner}\n${item.address} - ${item.contact}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'remove', child: Text('Remover'))
        ],
      ),
    );
  }
}

class _Professionals extends StatelessWidget {
  const _Professionals({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final items = MockData.professionals
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    Text('${item.role} - ${item.area}\n${item.institution}'),
                isThreeLine: true,
                trailing: StatusBadge(label: item.profile),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Network extends StatelessWidget {
  const _Network({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final items = MockData.institutions
        .where((item) => item.active && item.name.toLowerCase().contains(query))
        .toList();
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.business_outlined, color: AppColors.primary),
                      Spacer(),
                      StatusBadge(label: 'Ativo', tone: 'success')
                    ]),
                    const SizedBox(height: 10),
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(item.type,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 12)),
                    const SizedBox(height: 5),
                    Text(item.address,
                        style: const TextStyle(color: AppColors.muted)),
                    Text(item.contact,
                        style: const TextStyle(color: AppColors.muted)),
                    Text('Resp: ${item.owner}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Users extends StatelessWidget {
  const _Users();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: MockData.adminUsers
            .map((user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined,
                      color: AppColors.primary),
                  title: Text(user.email),
                  subtitle: Text('Ultimo acesso: ${user.lastAccess}'),
                  trailing: StatusBadge(label: user.profile),
                ))
            .toList(),
      ),
    );
  }
}

class _Parameters extends StatelessWidget {
  const _Parameters();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: MockData.adminParameters
          .map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(group.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined, size: 19))
                    ]),
                    ...group.items.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.chevron_right, size: 18),
                        title: Text(item))),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
