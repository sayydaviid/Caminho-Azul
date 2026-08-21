import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/admin_models.dart';
import '../repositories/admin_repository.dart';
import '../services/auth_service.dart';

typedef UserSubmit = Future<String> Function(UserFormData value);
typedef UserDelete = Future<String> Function();
typedef InstitutionSubmit = Future<String> Function(Institution value);
typedef ProfessionalSubmit = Future<String> Function(Professional value);
typedef LocalNetworkSubmit = Future<String> Function(LocalNetwork value);
typedef ParameterSubmit = Future<String> Function(AdminParameter value);

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Preencha este campo.' : null;

String? optionalEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Digite um e-mail válido.';
}

class UserForm extends StatefulWidget {
  const UserForm({
    required this.professionals,
    required this.institutions,
    required this.currentUid,
    required this.onSubmit,
    this.user,
    this.onDelete,
    super.key,
  });

  final AdminUser? user;
  final List<Professional> professionals;
  final List<Institution> institutions;
  final String currentUid;
  final UserSubmit onSubmit;
  final UserDelete? onDelete;

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late UserRole _role;
  SchoolRole? _schoolRole;
  late bool _active;
  String? _professionalId;
  bool _saving = false;
  bool _deleting = false;

  bool get _isSelf => widget.user?.id == widget.currentUid;

  @override
  void initState() {
    super.initState();
    final value = widget.user;
    _fullName = TextEditingController(
      text: value == null
          ? null
          : value.name.trim().isNotEmpty
              ? value.name
              : '${value.firstName} ${value.lastName}'.trim(),
    );
    _email = TextEditingController(text: value?.email);
    _role = value?.role ?? UserRole.family;
    _schoolRole = value?.schoolRole;
    _active = value?.active ?? true;
    _professionalId = value?.professionalId;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfessional = widget.professionals
        .where((item) => item.id == _professionalId)
        .firstOrNull;
    final institutionNames = selectedProfessional?.institutionIds
            .map((id) =>
                widget.institutions.where((i) => i.id == id).firstOrNull?.name)
            .whereType<String>()
            .toList() ??
        const <String>[];
    return AdminFormScaffold(
      title: widget.user == null ? 'Novo usuário' : 'Editar usuário',
      saving: _saving || _deleting,
      onSave: _submit,
      secondaryAction: widget.user != null && !_isSelf
          ? SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                key: const Key('admin-form-delete-user'),
                onPressed: _saving || _deleting ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir usuário'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            )
          : null,
      child: Form(
        key: _key,
        child: Column(
          children: [
            TextFormField(
              key: const Key('admin-form-fullName'),
              controller: _fullName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo *'),
              validator: _validateFullName,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('admin-form-email'),
              controller: _email,
              enabled: widget.user == null && !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail *'),
              validator: (value) => requiredText(value) ?? optionalEmail(value),
            ),
            const SizedBox(height: 10),
            _RolePickerField(
              fieldKey: const Key('admin-form-role'),
              role: _role,
              schoolRole: _schoolRole,
              enabled: !_saving && !_isSelf,
              onChanged: (selection) => setState(() {
                _role = selection.role;
                _schoolRole = selection.schoolRole;
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              key: const Key('admin-form-professional'),
              value: _professionalId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Profissional vinculado'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Nenhum')),
                for (final item in widget.professionals)
                  if (item.active || item.id == widget.user?.professionalId)
                    DropdownMenuItem<String?>(
                      value: item.id,
                      enabled: item.active &&
                          (item.userId == null ||
                              item.userId == widget.user?.id),
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _professionalId = value),
            ),
            if (institutionNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Instituições: ${institutionNames.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usuário ativo'),
              subtitle: _isSelf
                  ? const Text('Você não pode desativar a própria conta.')
                  : null,
              value: _active,
              onChanged: _saving || _isSelf
                  ? null
                  : (value) => setState(() => _active = value),
            ),
            if (widget.user != null) ...[
              const Divider(),
              _InfoLine('Criado em', formatDate(widget.user!.createdAt)),
              _InfoLine('Último acesso', formatDate(widget.user!.lastAccessAt)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving || _deleting || !(_key.currentState?.validate() ?? false)) {
      return;
    }
    final old = widget.user;
    if (old != null &&
        (old.role != _role ||
            old.schoolRole != _schoolRole ||
            old.active != _active)) {
      final confirmed = await confirmImportantChange(context);
      if (!confirmed) return;
    }
    setState(() => _saving = true);
    try {
      final nameParts = _fullName.text
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      final message = await widget.onSubmit(UserFormData(
        firstName: nameParts.first,
        lastName: nameParts.skip(1).join(' '),
        email: _email.text,
        role: _role,
        schoolRole: _role == UserRole.school
            ? (_schoolRole ?? SchoolRole.teacher)
            : null,
        active: _active,
        professionalId: _professionalId,
      ));
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateFullName(String? value) {
    final parts = value
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        const <String>[];
    return parts.length >= 2 ? null : 'Informe o nome completo.';
  }

  Future<void> _confirmDelete() async {
    final user = widget.user;
    final onDelete = widget.onDelete;
    if (user == null || onDelete == null || _saving || _deleting) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir usuário?'),
            content: Text(
              'O acesso de ${user.name.isEmpty ? user.email : user.name} será removido imediatamente e o vínculo profissional será desfeito.\n\n'
              'O registro de autenticação continuará no Firebase, mas não conseguirá acessar o aplicativo. Esta ação não pode ser desfeita pelo painel.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('admin-confirm-delete-user'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      final message = await onDelete();
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _RolePickerField extends StatelessWidget {
  const _RolePickerField({
    required this.fieldKey,
    required this.role,
    required this.schoolRole,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final UserRole role;
  final SchoolRole? schoolRole;
  final bool enabled;
  final ValueChanged<({UserRole role, SchoolRole? schoolRole})> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => _selectRole(context) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Perfil de acesso *',
            enabled: enabled,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  role == UserRole.school
                      ? 'Escola • ${(schoolRole ?? SchoolRole.teacher).label}'
                      : role.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      );

  Future<void> _selectRole(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected =
        await showModalBottomSheet<({UserRole role, SchoolRole? schoolRole})>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text(
                  'Perfil de acesso',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Text(
                  'Escola',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final item in SchoolRole.values)
                ListTile(
                  key: Key('admin-school-role-option-${item.value}'),
                  title: Text(item.label),
                  selected: role == UserRole.school && schoolRole == item,
                  trailing: role == UserRole.school && schoolRole == item
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    (role: UserRole.school, schoolRole: item),
                  ),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Text(
                  'Outros perfis',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final item in UserRole.values)
                if (item != UserRole.school)
                  ListTile(
                    key: Key('admin-role-option-${item.value}'),
                    title: Text(item.label),
                    selected: item == role,
                    trailing: item == role
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      (role: item, schoolRole: null),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class InstitutionForm extends StatefulWidget {
  const InstitutionForm({required this.onSubmit, this.institution, super.key});
  final Institution? institution;
  final InstitutionSubmit onSubmit;
  @override
  State<InstitutionForm> createState() => _InstitutionFormState();
}

class _InstitutionFormState extends State<InstitutionForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.institution;
    _active = v?.active ?? true;
    _fields = {
      'name': TextEditingController(text: v?.name),
      'type': TextEditingController(text: v?.type),
      'cnpj': TextEditingController(text: v?.cnpj),
      'email': TextEditingController(text: v?.email),
      'phone': TextEditingController(text: v?.phone),
      'street': TextEditingController(text: v?.address.street),
      'number': TextEditingController(text: v?.address.number),
      'complement': TextEditingController(text: v?.address.complement),
      'district': TextEditingController(text: v?.address.district),
      'city': TextEditingController(text: v?.address.city),
      'state': TextEditingController(text: v?.address.state),
      'zipCode': TextEditingController(text: v?.address.zipCode),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminFormScaffold(
        title: widget.institution == null
            ? 'Nova instituição'
            : 'Editar instituição',
        saving: _saving,
        onSave: _submit,
        child: Form(
          key: _key,
          child: Column(
            children: [
              _field('name', 'Nome *',
                  key: const Key('admin-form-name'), required: true),
              _field('type', 'Tipo *', required: true),
              _field('cnpj', 'CNPJ'),
              _field('email', 'E-mail', email: true),
              _field('phone', 'Telefone'),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 8),
                  child: Text('Endereço',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              _field('street', 'Logradouro *', required: true),
              Row(children: [
                Expanded(child: _field('number', 'Número *', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field('complement', 'Complemento')),
              ]),
              _field('district', 'Bairro *', required: true),
              _field('city', 'Cidade *', required: true),
              Row(children: [
                Expanded(child: _field('state', 'UF *', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field('zipCode', 'CEP *', required: true)),
              ]),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Instituição ativa'),
                value: _active,
                onChanged:
                    _saving ? null : (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      );

  Widget _field(String name, String label,
      {bool required = false, bool email = false, Key? key}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: key ?? Key('admin-form-$name'),
        controller: _fields[name],
        enabled: !_saving,
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            (required ? requiredText(value) : null) ??
            (email ? optionalEmail(value) : null),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    if (widget.institution != null && widget.institution!.active != _active) {
      if (!await confirmImportantChange(context)) return;
    }
    setState(() => _saving = true);
    try {
      String value(String key) => _fields[key]!.text.trim();
      final previous = widget.institution;
      final message = await widget.onSubmit(Institution(
        id: previous?.id ?? '',
        name: value('name'),
        type: value('type'),
        cnpj: value('cnpj'),
        email: value('email'),
        phone: value('phone'),
        address: Address(
          street: value('street'),
          number: value('number'),
          complement: value('complement'),
          district: value('district'),
          city: value('city'),
          state: value('state'),
          zipCode: value('zipCode'),
        ),
        active: _active,
        createdAt: previous?.createdAt,
        updatedAt: previous?.updatedAt,
        createdBy: previous?.createdBy,
      ));
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ProfessionalForm extends StatefulWidget {
  const ProfessionalForm({
    required this.institutions,
    required this.users,
    required this.onSubmit,
    this.professional,
    super.key,
  });
  final Professional? professional;
  final List<Institution> institutions;
  final List<AdminUser> users;
  final ProfessionalSubmit onSubmit;
  @override
  State<ProfessionalForm> createState() => _ProfessionalFormState();
}

class _ProfessionalFormState extends State<ProfessionalForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late Set<String> _institutionIds;
  String? _userId;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.professional;
    _fields = {
      'phone': TextEditingController(text: v?.phone),
      'registrationNumber': TextEditingController(text: v?.registrationNumber),
    };
    _institutionIds = {...?v?.institutionIds};
    _userId =
        widget.users.any((user) => user.id == v?.userId) ? v?.userId : null;
    _active = v?.active ?? true;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminFormScaffold(
        title: widget.professional == null
            ? 'Novo profissional'
            : 'Editar profissional',
        saving: _saving,
        onSave: _submit,
        child: Form(
          key: _key,
          child: Column(children: [
            DropdownButtonFormField<String?>(
              key: const Key('admin-form-user'),
              value: _userId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Usuário vinculado *'),
              items: [
                for (final item in widget.users)
                  if (item.active || item.id == widget.professional?.userId)
                    DropdownMenuItem<String?>(
                      value: item.id,
                      enabled: item.active &&
                          (item.professionalId == null ||
                              item.professionalId == widget.professional?.id),
                      child: Text('${item.name} • ${item.email}',
                          overflow: TextOverflow.ellipsis),
                    ),
              ],
              validator: (value) =>
                  value == null ? 'Selecione um usuário.' : null,
              onChanged:
                  _saving ? null : (value) => setState(() => _userId = value),
            ),
            const SizedBox(height: 10),
            _field('phone', 'Telefone'),
            _field('registrationNumber', 'Registro profissional'),
            InstitutionPicker(
              institutions: widget.institutions,
              selectedIds: _institutionIds,
              onChanged: (ids) => setState(() => _institutionIds = ids),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profissional ativo'),
              value: _active,
              onChanged:
                  _saving ? null : (value) => setState(() => _active = value),
            ),
          ]),
        ),
      );

  Widget _field(String name, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: Key('admin-form-$name'),
          controller: _fields[name],
          enabled: !_saving,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    if (widget.professional != null && widget.professional!.active != _active) {
      if (!await confirmImportantChange(context)) return;
    }
    setState(() => _saving = true);
    try {
      String value(String key) => _fields[key]!.text.trim();
      final previous = widget.professional;
      final selectedUser =
          widget.users.where((user) => user.id == _userId).firstOrNull;
      if (selectedUser == null) {
        throw const AdminRepositoryException(
          'O usuário selecionado não está mais disponível.',
        );
      }
      final message = await widget.onSubmit(Professional(
        id: previous?.id ?? '',
        firstName: selectedUser.firstName,
        lastName: selectedUser.lastName,
        name: selectedUser.name,
        email: selectedUser.email,
        phone: value('phone'),
        specialty: previous?.specialty,
        registrationNumber: value('registrationNumber'),
        userId: selectedUser.id,
        institutionIds: _institutionIds.toList(growable: false),
        active: _active,
        createdAt: previous?.createdAt,
        updatedAt: previous?.updatedAt,
        createdBy: previous?.createdBy,
      ));
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class LocalNetworkForm extends StatefulWidget {
  const LocalNetworkForm(
      {required this.institutions,
      required this.onSubmit,
      this.network,
      super.key});
  final LocalNetwork? network;
  final List<Institution> institutions;
  final LocalNetworkSubmit onSubmit;
  @override
  State<LocalNetworkForm> createState() => _LocalNetworkFormState();
}

class _LocalNetworkFormState extends State<LocalNetworkForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late Set<String> _institutionIds;
  late bool _active;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.network?.name);
    _description = TextEditingController(text: widget.network?.description);
    _institutionIds = {...?widget.network?.institutionIds};
    _active = widget.network?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminFormScaffold(
        title: widget.network == null
            ? 'Novo registro da rede'
            : 'Editar registro da rede',
        saving: _saving,
        onSave: _submit,
        child: Form(
            key: _key,
            child: Column(children: [
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                  validator: requiredText),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  minLines: 2,
                  maxLines: 4),
              const SizedBox(height: 10),
              InstitutionPicker(
                  institutions: widget.institutions,
                  selectedIds: _institutionIds,
                  onChanged: (ids) => setState(() => _institutionIds = ids)),
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registro ativo'),
                  value: _active,
                  onChanged:
                      _saving ? null : (v) => setState(() => _active = v)),
            ])),
      );
  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final old = widget.network;
      final message = await widget.onSubmit(LocalNetwork(
        id: old?.id ?? '',
        name: _name.text.trim(),
        description: _description.text.trim(),
        institutionIds: _institutionIds.toList(growable: false),
        active: _active,
        createdAt: old?.createdAt,
        updatedAt: old?.updatedAt,
        createdBy: old?.createdBy,
      ));
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ParameterForm extends StatefulWidget {
  const ParameterForm({required this.onSubmit, this.parameter, super.key});
  final AdminParameter? parameter;
  final ParameterSubmit onSubmit;
  @override
  State<ParameterForm> createState() => _ParameterFormState();
}

class _ParameterFormState extends State<ParameterForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _items;
  late bool _active;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.parameter?.title);
    _items = TextEditingController(text: widget.parameter?.items.join('\n'));
    _active = widget.parameter?.active ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _items.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminFormScaffold(
        title: widget.parameter == null ? 'Novo parâmetro' : 'Editar parâmetro',
        saving: _saving,
        onSave: _submit,
        child: Form(
            key: _key,
            child: Column(children: [
              TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: requiredText),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _items,
                  decoration: const InputDecoration(
                      labelText: 'Opções (uma por linha) *'),
                  minLines: 4,
                  maxLines: 8,
                  validator: requiredText),
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Parâmetro ativo'),
                  value: _active,
                  onChanged:
                      _saving ? null : (v) => setState(() => _active = v)),
            ])),
      );
  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final message = await widget.onSubmit(AdminParameter(
        id: widget.parameter?.id ?? '',
        title: _title.text.trim(),
        items: _items.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        active: _active,
      ));
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (mounted) showFormError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class InstitutionPicker extends StatelessWidget {
  const InstitutionPicker(
      {required this.institutions,
      required this.selectedIds,
      required this.onChanged,
      super.key});
  final List<Institution> institutions;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final result = await showDialog<Set<String>>(
            context: context,
            builder: (_) => _InstitutionPickerDialog(
                institutions: institutions, initial: selectedIds),
          );
          if (result != null) onChanged(result);
        },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Instituições', suffixIcon: Icon(Icons.search)),
          child: Text(
            selectedIds.isEmpty
                ? 'Selecionar instituições ativas'
                : institutions
                    .where((e) => selectedIds.contains(e.id))
                    .map((e) => e.name)
                    .join(', '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

class _InstitutionPickerDialog extends StatefulWidget {
  const _InstitutionPickerDialog(
      {required this.institutions, required this.initial});
  final List<Institution> institutions;
  final Set<String> initial;
  @override
  State<_InstitutionPickerDialog> createState() =>
      _InstitutionPickerDialogState();
}

class _InstitutionPickerDialogState extends State<_InstitutionPickerDialog> {
  late Set<String> selected;
  String query = '';
  @override
  void initState() {
    super.initState();
    selected = {...widget.initial};
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.institutions
        .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Selecionar instituições'),
      content: SizedBox(
          width: 440,
          height: 420,
          child: Column(children: [
            TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Buscar por nome',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => query = v)),
            const SizedBox(height: 8),
            Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('Nenhuma instituição ativa encontrada.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return CheckboxListTile(
                            value: selected.contains(item.id),
                            title: Text(item.name),
                            subtitle: Text(item.type),
                            onChanged: (checked) => setState(() =>
                                checked == true
                                    ? selected.add(item.id)
                                    : selected.remove(item.id)),
                          );
                        },
                      )),
          ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Aplicar'))
      ],
    );
  }
}

class AdminFormScaffold extends StatelessWidget {
  const AdminFormScaffold(
      {required this.title,
      required this.child,
      required this.saving,
      required this.onSave,
      this.secondaryAction,
      super.key});
  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback onSave;
  final Widget? secondaryAction;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 18),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  child,
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('admin-form-submit'),
                        onPressed: saving ? null : onSave,
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Salvar cadastro'),
                      )),
                  if (secondaryAction != null) ...[
                    const SizedBox(height: 4),
                    secondaryAction!,
                  ],
                ]),
          ),
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value))
        ]),
      );
}

String formatDate(DateTime? value) {
  if (value == null) return 'Não informado';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}

Future<bool> confirmImportantChange(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar alteração'),
        content: const Text(
            'Esta alteração afeta permissões ou acesso. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    ) ??
    false;

void showFormError(BuildContext context, Object error) {
  final raw = error.toString();
  final message = raw.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
