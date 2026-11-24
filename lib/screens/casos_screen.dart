import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../models/student_models.dart';
import '../repositories/case_repository.dart';
import '../repositories/referral_repository.dart';
import '../repositories/student_repository.dart';
import '../services/auth_service.dart';
import '../widgets/admin_forms.dart' show formatDate;
import '../widgets/dashboard_card.dart';
import '../widgets/load_more.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import 'caso_detalhe_screen.dart';

/// Lista de casos da Escola (P1-01). Professor: casos aos quais está
/// vinculado. Direção: casos da instituição.
class CasosScreen extends StatefulWidget {
  const CasosScreen({
    required this.user,
    this.caseRepository,
    this.studentRepository,
    this.referralRepository,
    super.key,
  });

  final AppUser user;
  final CaseRepository? caseRepository;
  final StudentRepository? studentRepository;
  final ReferralRepository? referralRepository;

  @override
  State<CasosScreen> createState() => _CasosScreenState();
}

class _CasosScreenState extends State<CasosScreen> {
  late final CaseRepository _cases;
  late final StudentRepository _students;
  late Stream<List<StudentCase>> _stream;
  String? _schoolId;
  CaseStatus? _filter;
  bool _creating = false;
  int _limit = listPageSize;

  bool get _isTeacher => widget.user.schoolRole == SchoolRole.teacher;

  @override
  void initState() {
    super.initState();
    _cases = widget.caseRepository ?? FirebaseCaseRepository();
    _students = widget.studentRepository ?? FirebaseStudentRepository();
    final ids = widget.user.institutionIds;
    _schoolId = ids.isEmpty ? null : ids.first;
    _subscribe();
  }

  void _subscribe() {
    final schoolId = _schoolId;
    _stream = schoolId == null
        ? Stream.value(const [])
        : _isTeacher
            ? _cases.watchTeacherCases(widget.user, schoolId, limit: _limit)
            : _cases.watchSchoolCases(schoolId, limit: _limit);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Casos',
          subtitle: _isTeacher
              ? 'Casos aos quais você está vinculado'
              : 'Casos da escola para análise e acompanhamento',
          trailing: _isTeacher && _schoolId != null
              ? FilledButton.icon(
                  key: const Key('cases-new-button'),
                  onPressed: _creating ? null : _newCase,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo caso'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
              ),
              for (final status in CaseStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status.label),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<StudentCase>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (_schoolId == null) {
              return const _Message(
                key: Key('cases-no-school'),
                icon: Icons.apartment_outlined,
                text: 'Sua conta não está vinculada a uma escola.',
              );
            }
            if (snapshot.hasError) {
              return _Message(
                key: const Key('cases-error'),
                icon: Icons.cloud_off_outlined,
                text: 'Não foi possível carregar os casos.',
                action: TextButton(
                  onPressed: () => setState(_subscribe),
                  child: const Text('Tentar novamente'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                key: Key('cases-loading'),
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snapshot.data!;
            final items = _filter == null
                ? all
                : all.where((c) => c.status == _filter).toList();
            if (items.isEmpty) {
              return _Message(
                key: const Key('cases-empty'),
                icon: Icons.folder_open_outlined,
                text: all.isEmpty
                    ? (_isTeacher
                        ? 'Nenhum caso registrado. Use "Novo caso".'
                        : 'Nenhum caso registrado na escola.')
                    : 'Nenhum caso com este status.',
              );
            }
            return Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: ListTile(
                        key: Key('case-tile-${item.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.studentName),
                        subtitle: Text('Atualizado em ${formatDate(item.updatedAt)}'),
                        trailing: StatusBadge(
                            label: item.status.label, tone: item.status.tone),
                        onTap: () => _open(item.id),
                      ),
                    ),
                  ),
                LoadMoreButton(
                  keyName: 'cases-load-more',
                  shown: all.length,
                  limit: _limit,
                  onPressed: () => setState(() {
                    _limit += listPageSize;
                    _subscribe();
                  }),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _open(String caseId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CasoDetalheScreen(
        user: widget.user,
        caseId: caseId,
        repository: _cases,
        referralRepository: widget.referralRepository,
        studentRepository: _students,
      ),
    ));
  }

  Future<void> _newCase() async {
    final schoolId = _schoolId;
    if (schoolId == null || _creating) return;
    setState(() => _creating = true);
    try {
      // Seleção do estudante: lista ampla (a escola raramente passa disso).
      final students = (await _students.watchSchoolStudents(schoolId, limit: 500).first)
          .where((s) => s.active)
          .toList();
      if (!mounted) return;
      final student = await showDialog<Student>(
        context: context,
        builder: (_) => _StudentPicker(students: students),
      );
      if (student == null || !mounted) return;
      final caseId = await _cases.createCase(widget.user, student);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Caso registrado.')));
      _open(caseId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

/// Mensagem amigável para falhas de persistência/permissão.
String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Você não tem permissão para esta operação.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Não foi possível conectar. Verifique a internet e tente novamente.';
  }
  return text.replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.students});
  final List<Student> students;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.students
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Selecionar estudante'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              key: const Key('case-student-search'),
              decoration: const InputDecoration(
                hintText: 'Buscar estudante',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum estudante ativo. A Direção escolar cadastra os estudantes.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final student in items)
                          ListTile(
                            key: Key('case-student-${student.id}'),
                            title: Text(student.name),
                            subtitle: student.grade == null
                                ? null
                                : Text(student.grade!),
                            onTap: () => Navigator.pop(context, student),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    super.key,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          children: [
            Icon(icon, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            if (action != null) action!,
          ],
        ),
      );
}
