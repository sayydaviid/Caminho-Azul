import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../controllers/admin_controller.dart';
import '../models/admin_models.dart';
import '../repositories/admin_repository.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';
import '../widgets/admin_forms.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    required this.user,
    required this.authService,
    this.repository,
    this.userService,
    super.key,
  });

  final AppUser user;
  final AuthService authService;
  final AdminRepository? repository;
  final AdminUserService? userService;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _searchController = TextEditingController();
  late final AdminController _controller;
  Map<String, String> _institutionNames = const {};
  Map<String, String> _professionalNames = const {};

  @override
  void initState() {
    super.initState();
    _controller = AdminController(
      repository: widget.repository ?? FirebaseAdminRepository(),
      userService: widget.userService ?? FirebaseAdminUserService(),
      actorUid: widget.user.uid,
    )..addListener(_refresh);
    _refreshLookups();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshLookups() async {
    try {
      final institutions = await _controller.institutions();
      final professionals = await _controller.professionals();
      if (!mounted) return;
      setState(() {
        _institutionNames = {
          for (final item in institutions) item.id: item.name
        };
        _professionalNames = {
          for (final item in professionals) item.id: item.name
        };
      });
    } catch (_) {
      // A lista principal continua utilizável sem os rótulos relacionados.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('admin-screen'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const PageHeader(
          title: 'Administração',
          subtitle: 'Gestão da rede local Caminho Azul',
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('admin-export-button'),
              onPressed: _controller.loading ? null : _export,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Exportar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              key: const Key('admin-new-button'),
              onPressed: _openNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo cadastro'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _SectionPicker(
          selected: _controller.section,
          onSelected: (section) {
            _searchController.clear();
            _controller.selectSection(section);
            if (section == AdminSection.professionals ||
                section == AdminSection.users ||
                section == AdminSection.localNetwork) {
              _refreshLookups();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('admin-search-field'),
          controller: _searchController,
          onChanged: _controller.search,
          decoration: InputDecoration(
            hintText: _searchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildContent(),
        ),
      ],
    );
  }

  String get _searchHint => switch (_controller.section) {
        AdminSection.users => 'Buscar por nome ou e-mail...',
        AdminSection.professionals =>
          'Buscar por nome, especialidade ou registro...',
        _ => 'Buscar por nome...',
      };

  Widget _buildContent() {
    if (_controller.loading) {
      return const Padding(
        key: Key('admin-loading'),
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.error != null) {
      return AppCard(
        key: const Key('admin-error'),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
          const SizedBox(height: 8),
          const Text('Não foi possível carregar os cadastros.'),
          TextButton(
            onPressed: _controller.retry,
            child: const Text('Tentar novamente'),
          ),
        ]),
      );
    }
    final items = _controller.filteredItems;
    if (items.isEmpty) {
      return const AppCard(
        key: Key('admin-empty'),
        child: Column(children: [
          Icon(Icons.search_off_outlined, color: AppColors.muted),
          SizedBox(height: 8),
          Text('Nenhum resultado encontrado.'),
        ]),
      );
    }
    return Column(
      key: ValueKey(_controller.section),
      children: [
        for (final item in items) ...[
          _cardFor(item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _cardFor(Object item) => switch (item) {
        Institution value => _recordCard(
            icon: Icons.apartment_outlined,
            title: value.name,
            subtitle: [value.type, value.address.formatted, value.phone]
                .whereType<String>()
                .where((e) => e.isNotEmpty)
                .join('\n'),
            active: value.active,
            typeLabel: value.type,
            onEdit: () => _openInstitution(value),
          ),
        Professional value => _recordCard(
            icon: Icons.person_outline,
            title: value.name,
            subtitle: [
              value.registrationNumber,
              if (value.institutionIds.isNotEmpty)
                'Instituições: ${value.institutionIds.map((id) => _institutionNames[id] ?? id).join(', ')}',
            ].whereType<String>().where((e) => e.isNotEmpty).join('\n'),
            active: value.active,
            typeLabel: 'Profissional',
            onEdit: () => _openProfessional(value),
          ),
        LocalNetwork value => _recordCard(
            icon: Icons.location_on_outlined,
            title: value.name,
            subtitle: [
              value.description,
              if (value.institutionIds.isNotEmpty)
                'Instituições: ${value.institutionIds.map((id) => _institutionNames[id] ?? id).join(', ')}',
            ].whereType<String>().where((e) => e.isNotEmpty).join('\n'),
            active: value.active,
            typeLabel: 'Rede local',
            onEdit: () => _openLocalNetwork(value),
          ),
        AdminUser value => _recordCard(
            icon: Icons.manage_accounts_outlined,
            title: value.name.isEmpty ? value.email : value.name,
            subtitle: [
              value.email,
              if (value.professionalId != null)
                'Profissional: ${_professionalNames[value.professionalId] ?? value.professionalId}',
              'Último acesso: ${formatDate(value.lastAccessAt)}',
            ].join('\n'),
            active: value.active,
            typeLabel: value.accessLabel,
            onEdit: () => _openUser(value),
          ),
        AdminParameter value => _recordCard(
            icon: Icons.settings_outlined,
            title: value.title,
            subtitle: value.items.join(' • '),
            active: value.active,
            typeLabel: 'Parâmetro',
            onEdit: () => _openParameter(value),
          ),
        _ => const SizedBox.shrink(),
      };

  Widget _recordCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required String typeLabel,
    required VoidCallback onEdit,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _LeadingIcon(icon: icon),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              StatusBadge(label: typeLabel),
              StatusBadge(
                label: active ? 'Ativo' : 'Inativo',
                tone: active ? 'success' : 'danger',
              ),
            ]),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
        IconButton(
          key: Key('admin-edit-${title.toLowerCase().replaceAll(' ', '-')}'),
          tooltip: 'Editar',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 19),
        ),
      ]),
    );
  }

  Future<void> _openNew() => switch (_controller.section) {
        AdminSection.institutions => _openInstitution(null),
        AdminSection.professionals => _openProfessional(null),
        AdminSection.localNetwork => _openLocalNetwork(null),
        AdminSection.users => _openUser(null),
        AdminSection.parameters => _openParameter(null),
      };

  Future<void> _openUser(AdminUser? user) async {
    await _showLoadingForm(() async => UserForm(
          user: user,
          professionals: await _controller.professionals(),
          institutions: await _controller.institutions(),
          currentUid: widget.user.uid,
          onSubmit: (value) => _controller.saveUser(user, value),
          onDelete: user == null ? null : () => _controller.deleteUser(user),
        ));
  }

  Future<void> _openInstitution(Institution? value) => _showForm(
        InstitutionForm(
          institution: value,
          onSubmit: (item) async {
            await _controller.saveInstitution(item);
            await _refreshLookups();
            return value == null
                ? 'Instituição criada com sucesso.'
                : 'Instituição atualizada com sucesso.';
          },
        ),
      );

  Future<void> _openProfessional(Professional? value) async {
    await _showLoadingForm(() async {
      final institutions = await _controller.activeInstitutions();
      final users = await _controller.users();
      return ProfessionalForm(
        professional: value,
        institutions: institutions,
        users: users,
        onSubmit: (item) async {
          await _controller.saveProfessional(item);
          await _refreshLookups();
          return value == null
              ? 'Profissional criado com sucesso.'
              : 'Profissional atualizado com sucesso.';
        },
      );
    });
  }

  Future<void> _openLocalNetwork(LocalNetwork? value) async {
    await _showLoadingForm(() async => LocalNetworkForm(
          network: value,
          institutions: await _controller.activeInstitutions(),
          onSubmit: (item) async {
            await _controller.saveLocalNetwork(item);
            return value == null
                ? 'Registro da rede criado com sucesso.'
                : 'Registro da rede atualizado com sucesso.';
          },
        ));
  }

  Future<void> _openParameter(AdminParameter? value) => _showForm(
        ParameterForm(
          parameter: value,
          onSubmit: (item) async {
            await _controller.saveParameter(item);
            return value == null
                ? 'Parâmetro criado com sucesso.'
                : 'Parâmetro atualizado com sucesso.';
          },
        ),
      );

  Future<void> _showLoadingForm(Future<Widget> Function() load) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final form = await load();
      if (!mounted) return;
      Navigator.pop(context);
      await _showForm(form);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      showFormError(context, error);
    }
  }

  Future<void> _showForm(Widget form) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => form,
    );
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final rows = <List<String>>[
      ['Seção', 'Nome', 'Detalhe', 'Status'],
      for (final item in _controller.filteredItems) _exportRow(item),
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados copiados. Cole em sua planilha para exportar.'),
      ),
    );
  }

  List<String> _exportRow(Object item) => switch (item) {
        Institution v => [
            _controller.section.label,
            v.name,
            v.type,
            v.active ? 'Ativo' : 'Inativo'
          ],
        Professional v => [
            _controller.section.label,
            v.name,
            v.registrationNumber ?? '',
            v.active ? 'Ativo' : 'Inativo'
          ],
        LocalNetwork v => [
            _controller.section.label,
            v.name,
            v.description ?? '',
            v.active ? 'Ativo' : 'Inativo'
          ],
        AdminUser v => [
            _controller.section.label,
            v.name,
            '${v.email} / ${v.accessLabel}',
            v.active ? 'Ativo' : 'Inativo'
          ],
        AdminParameter v => [
            _controller.section.label,
            v.title,
            v.items.join('; '),
            v.active ? 'Ativo' : 'Inativo'
          ],
        _ => const ['', '', '', ''],
      };

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelected});
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AdminSection.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, index) {
            final section = AdminSection.values[index];
            final selectedNow = section == selected;
            return ChoiceChip(
              key: Key('admin-tab-${section.name}'),
              selected: selectedNow,
              showCheckmark: false,
              avatar: Icon(
                _iconFor(section),
                size: 15,
                color: selectedNow ? AppColors.foreground : AppColors.primary,
              ),
              label: Text(section.label),
              labelStyle: const TextStyle(fontSize: 12),
              side: const BorderSide(color: AppColors.border),
              selectedColor: const Color(0xFFE0E7FF),
              backgroundColor: Colors.white,
              onSelected: (_) => onSelected(section),
            );
          },
        ),
      );

  IconData _iconFor(AdminSection section) => switch (section) {
        AdminSection.institutions => Icons.apartment_outlined,
        AdminSection.professionals => Icons.group_outlined,
        AdminSection.localNetwork => Icons.location_on_outlined,
        AdminSection.users => Icons.manage_accounts_outlined,
        AdminSection.parameters => Icons.settings_outlined,
      };
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E7FF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      );
}
