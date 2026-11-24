import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../repositories/case_repository.dart';
import '../services/auth_service.dart';
import 'dashboard_card.dart';

/// P1-02 — professores vinculados ao caso. A Direção escolar vincula ou
/// desvincula professores da escola e define o responsável principal; cada
/// alteração gera o evento interno `case.teachersUpdated`.
class CaseTeachers extends StatefulWidget {
  const CaseTeachers({
    required this.user,
    required this.value,
    required this.repository,
    required this.run,
    super.key,
  });

  final AppUser user;
  final StudentCase value;
  final CaseRepository repository;
  final Future<void> Function(Future<void> Function() action, String success) run;

  @override
  State<CaseTeachers> createState() => _CaseTeachersState();
}

class _CaseTeachersState extends State<CaseTeachers> {
  late Future<List<StaffOption>> _teachers;

  bool get _isDirector => widget.user.schoolRole == SchoolRole.director;

  @override
  void initState() {
    super.initState();
    _teachers = widget.repository.teachersOf(widget.value.schoolInstitutionId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StaffOption>>(
      future: _teachers,
      builder: (context, snapshot) {
        final names = {
          for (final item in snapshot.data ?? const <StaffOption>[])
            item.uid: item.name,
        };
        final linked = widget.value.teacherUids
            .map((uid) => uid == widget.value.primaryTeacherUid
                ? '${names[uid] ?? 'Professor(a)'} (principal)'
                : names[uid] ?? 'Professor(a)')
            .join(', ');
        return AppCard(
          key: const Key('case-teachers'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Professores vinculados',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.hasError
                          ? 'Não foi possível carregar os professores.'
                          : snapshot.hasData
                              ? linked
                              : 'Carregando...',
                      key: const Key('case-teachers-names'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (_isDirector &&
                  widget.value.status != CaseStatus.concluded &&
                  snapshot.hasData)
                TextButton.icon(
                  key: const Key('case-teachers-edit'),
                  onPressed: () => _edit(snapshot.data!),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Alterar'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(List<StaffOption> options) async {
    final result = await showDialog<({List<String> uids, String primary})>(
      context: context,
      builder: (_) => _TeachersDialog(
        options: options,
        selected: widget.value.teacherUids,
        primary: widget.value.primaryTeacherUid,
      ),
    );
    if (result == null) return;
    await widget.run(
      () => widget.repository.updateTeachers(
        widget.user,
        widget.value,
        teacherUids: result.uids,
        primaryTeacherUid: result.primary,
      ),
      'Professores do caso atualizados.',
    );
  }
}

class _TeachersDialog extends StatefulWidget {
  const _TeachersDialog({
    required this.options,
    required this.selected,
    required this.primary,
  });

  final List<StaffOption> options;
  final List<String> selected;
  final String primary;

  @override
  State<_TeachersDialog> createState() => _TeachersDialogState();
}

class _TeachersDialogState extends State<_TeachersDialog> {
  late final Set<String> _selected = {...widget.selected};
  late String? _primary = widget.primary;

  @override
  Widget build(BuildContext context) {
    final chosen =
        widget.options.where((o) => _selected.contains(o.uid)).toList();
    if (!_selected.contains(_primary)) {
      _primary = chosen.firstOrNull?.uid;
    }
    return AlertDialog(
      title: const Text('Professores do caso'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.options.isEmpty)
                const Text('Nenhum professor ativo cadastrado nesta escola.'),
              for (final option in widget.options)
                CheckboxListTile(
                  key: Key('case-teacher-${option.uid}'),
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(option.uid),
                  title: Text(option.name),
                  onChanged: (checked) => setState(() => checked == true
                      ? _selected.add(option.uid)
                      : _selected.remove(option.uid)),
                ),
              if (chosen.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('case-teacher-primary'),
                  value: _primary,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Responsável principal'),
                  items: [
                    for (final option in chosen)
                      DropdownMenuItem(
                          value: option.uid, child: Text(option.name)),
                  ],
                  onChanged: (value) => setState(() => _primary = value),
                ),
              ],
              if (_selected.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Mantenha ao menos um professor vinculado.',
                      style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          key: const Key('case-teachers-save'),
          onPressed: _selected.isEmpty || _primary == null
              ? null
              : () => Navigator.pop(context, (
                    uids: [
                      for (final o in widget.options)
                        if (_selected.contains(o.uid)) o.uid
                    ],
                    primary: _primary!,
                  )),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
