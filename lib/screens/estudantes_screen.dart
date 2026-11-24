import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/student_models.dart';
import '../repositories/student_repository.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/load_more.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

/// Cadastro de estudantes (P1-19, D-09). A Direção escolar cria e edita os
/// estudantes da sua escola; professores consultam para abrir casos.
class EstudantesScreen extends StatefulWidget {
  const EstudantesScreen({
    required this.user,
    this.repository,
    super.key,
  });

  final AppUser user;
  final StudentRepository? repository;

  @override
  State<EstudantesScreen> createState() => _EstudantesScreenState();
}

class _EstudantesScreenState extends State<EstudantesScreen> {
  late final StudentRepository _repository;
  StreamSubscription<List<Student>>? _subscription;
  Map<String, String> _schoolNames = const {};
  String? _schoolId;
  List<Student> _students = const [];
  bool _loading = true;
  int _limit = listPageSize;
  Object? _error;
  String _query = '';

  bool get _isDirector => widget.user.schoolRole == SchoolRole.director;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseStudentRepository();
    final ids = widget.user.institutionIds;
    _schoolId = ids.isEmpty ? null : ids.first;
    _listen();
    _repository.institutionNames(ids).then((names) {
      if (mounted) setState(() => _schoolNames = names);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    _subscription?.cancel();
    final schoolId = _schoolId;
    if (schoolId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _subscription = _repository.watchSchoolStudents(schoolId, limit: _limit).listen(
      (students) {
        if (!mounted) return;
        setState(() {
          _students = students;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error;
        });
      },
    );
  }

  List<Student> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students
        .where((s) =>
            s.name.toLowerCase().contains(query) ||
            (s.grade ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final schools = widget.user.institutionIds;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Estudantes',
          subtitle: _isDirector
              ? 'Cadastro dos estudantes da escola'
              : 'Estudantes da escola para abertura de casos',
          trailing: _isDirector && _schoolId != null
              ? FilledButton.icon(
                  key: const Key('students-new-button'),
                  onPressed: () => _openForm(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo estudante'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (schools.length > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final id in schools)
                ChoiceChip(
                  label: Text(_schoolNames[id] ?? id),
                  selected: id == _schoolId,
                  onSelected: (_) {
                    setState(() => _schoolId = id);
                    _listen();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ] else if (_schoolId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _schoolNames[_schoolId] ?? '',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        TextField(
          key: const Key('students-search'),
          decoration: const InputDecoration(
            labelText: 'Buscar por nome ou turma',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        _content(),
      ],
    );
  }

  Widget _content() {
    if (_schoolId == null) {
      return const _StateCard(
        key: Key('students-no-school'),
        icon: Icons.apartment_outlined,
        message: 'Sua conta não está vinculada a uma escola.',
      );
    }
    if (_loading) {
      return const Padding(
        key: Key('students-loading'),
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _StateCard(
        key: const Key('students-error'),
        icon: Icons.cloud_off_outlined,
        message: 'Não foi possível carregar os estudantes.',
        action: TextButton(onPressed: _listen, child: const Text('Tentar novamente')),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return _StateCard(
        key: const Key('students-empty'),
        icon: Icons.person_search_outlined,
        message: _students.isEmpty
            ? (_isDirector
                ? 'Nenhum estudante cadastrado. Use "Novo estudante".'
                : 'Nenhum estudante cadastrado pela Direção.')
            : 'Nenhum estudante encontrado para a busca.',
      );
    }
    return Column(
      children: [
        for (final student in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.person_outline, color: AppColors.primary),
                ),
                title: Text(student.name),
                subtitle: Text([
                  if (student.grade != null) student.grade!,
                  student.familyUid == null
                      ? 'Sem conta familiar'
                      : 'Conta familiar vinculada',
                ].join(' • ')),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    StatusBadge(
                      label: student.active ? 'Ativo' : 'Inativo',
                      tone: student.active ? 'success' : 'danger',
                    ),
                    if (_isDirector)
                      IconButton(
                        key: Key('students-edit-${student.id}'),
                        tooltip: 'Editar estudante',
                        onPressed: () => _openForm(student),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
              ),
            ),
          ),
        LoadMoreButton(
          keyName: 'students-load-more',
          shown: _students.length,
          limit: _limit,
          onPressed: () {
            _limit += listPageSize;
            _listen();
          },
        ),
      ],
    );
  }

  Future<void> _openForm(Student? student) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _StudentForm(
        student: student,
        onSubmit: (name, grade, active) async {
          if (student == null) {
            await _repository.createStudent(
              schoolInstitutionId: _schoolId!,
              name: name,
              grade: grade,
              actorUid: widget.user.uid,
            );
            return 'Estudante cadastrado com sucesso.';
          }
          await _repository.updateStudent(
            student,
            name: name,
            grade: grade,
            active: active,
            actorUid: widget.user.uid,
          );
          return 'Estudante atualizado com sucesso.';
        },
      ),
    );
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          children: [
            Icon(icon, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) action!,
          ],
        ),
      );
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.onSubmit, this.student});

  final Student? student;
  final Future<String> Function(String name, String? grade, bool active)
      onSubmit;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _grade;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.student?.name);
    _grade = TextEditingController(text: widget.student?.grade);
    _active = widget.student?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _grade.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final message =
          await widget.onSubmit(_name.text, _grade.text, _active);
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(text.contains('permission-denied')
              ? 'Você não tem permissão para esta operação.'
              : text),
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.student == null ? 'Novo estudante' : 'Editar estudante',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('student-form-name'),
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo *'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) return 'Informe o nome do estudante.';
                if (text.length > 120) return 'Use no máximo 120 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('student-form-grade'),
              controller: _grade,
              enabled: !_saving,
              decoration:
                  const InputDecoration(labelText: 'Ano ou turma (opcional)'),
              validator: (value) => (value?.trim().length ?? 0) > 60
                  ? 'Use no máximo 60 caracteres.'
                  : null,
            ),
            if (widget.student != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estudante ativo'),
                value: _active,
                onChanged:
                    _saving ? null : (value) => setState(() => _active = value),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('student-form-submit'),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
