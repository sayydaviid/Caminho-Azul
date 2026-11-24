import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../repositories/case_repository.dart';
import '../reports/report_builders.dart';
import '../reports/report_export_log.dart';
import '../reports/report_models.dart';
import '../repositories/referral_repository.dart';
import '../repositories/student_repository.dart';
import '../services/auth_service.dart';
import '../utils/shared_stream.dart';
import '../widgets/admin_forms.dart' show formatDate;
import '../widgets/case_referrals_section.dart';
import '../widgets/case_school_content.dart';
import '../widgets/case_teachers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/status_badge.dart';
import 'casos_screen.dart' show friendlyError;
import 'gerar_relatorio_screen.dart';

/// Detalhe do caso (P1-01): metadados, ações permitidas ao perfil e linha do
/// tempo da escola. As permissões são garantidas pelas Security Rules; a tela
/// só exibe as ações que o perfil pode executar.
class CasoDetalheScreen extends StatefulWidget {
  const CasoDetalheScreen({
    required this.user,
    required this.caseId,
    required this.repository,
    this.referralRepository,
    this.studentRepository,
    this.reportExportLog,
    super.key,
  });

  final AppUser user;
  final String caseId;
  final CaseRepository repository;
  final ReferralRepository? referralRepository;
  final StudentRepository? studentRepository;
  final ReportExportLog? reportExportLog;

  @override
  State<CasoDetalheScreen> createState() => _CasoDetalheScreenState();
}

class _CasoDetalheScreenState extends State<CasoDetalheScreen> {
  late final Stream<StudentCase?> _case;
  // D-A04: a linha do tempo fica numa lista preguiçosa e é recriada ao rolar.
  late final SharedStream<List<TimelineEvent>> _timeline;
  bool _busy = false;
  late final ReferralRepository _referrals =
      widget.referralRepository ?? FirebaseReferralRepository();

  bool get _isTeacher => widget.user.schoolRole == SchoolRole.teacher;
  bool get _isDirector => widget.user.schoolRole == SchoolRole.director;

  @override
  void initState() {
    super.initState();
    _case = widget.repository.watchCase(widget.caseId);
    _timeline = SharedStream(widget.repository.watchSchoolTimeline(widget.caseId));
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _snack(success);
    } catch (error) {
      if (mounted) _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// R-02/R-03: professor vinculado gera o pedagógico; Direção, o escolar.
  void _openReport(StudentCase value) {
    final kind = _isDirector ? ReportKind.school : ReportKind.pedagogical;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GerarRelatorioScreen(
        user: widget.user,
        kind: kind,
        exportLog: widget.reportExportLog,
        loadSource: () => _isDirector
            ? loadSchoolSource(
                director: widget.user,
                value: value,
                cases: widget.repository,
                referrals: _referrals,
                students: widget.studentRepository)
            : loadPedagogicalSource(
                teacher: widget.user,
                value: value,
                cases: widget.repository,
                referrals: _referrals,
                students: widget.studentRepository),
      ),
    ));
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caso')),
      body: StreamBuilder<StudentCase?>(
        stream: _case,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              key: Key('case-detail-error'),
              child: Text('Não foi possível carregar o caso.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final value = snapshot.data;
          if (value == null) {
            return const Center(child: Text('Caso não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            value.studentName,
                            key: const Key('case-detail-student'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusBadge(
                          key: const Key('case-detail-status'),
                          label: value.status.label,
                          tone: value.status.tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Aberto em ${formatDate(value.createdAt)}',
                        style: const TextStyle(color: AppColors.muted)),
                    if (value.familyVisible)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'A família vinculada acompanha as movimentações administrativas.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    if (_isTeacher || _isDirector) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('case-generate-pdf'),
                          onPressed: () => _openReport(value),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(_isDirector
                              ? 'Gerar relatório escolar (PDF)'
                              : 'Gerar relatório pedagógico (PDF)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Estrutura estável: ações mudam sem recriar a linha do tempo.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _actions(value),
              ),
              if (_isDirector) ...[
                CaseDirectorActions(
                  key: const Key('case-director-actions'),
                  user: widget.user,
                  value: value,
                  repository: _referrals,
                  run: _run,
                ),
                const SizedBox(height: 12),
              ],
              if (widget.user.role == UserRole.school) ...[
                CaseTeachers(
                  key: const Key('case-teachers-section'),
                  user: widget.user,
                  value: value,
                  repository: widget.repository,
                  run: _run,
                ),
                const SizedBox(height: 12),
              ],
              if (_isTeacher && value.complementOpen)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'A UBS solicitou complementação (via Direção escolar): registre novas observações.',
                    key: Key('case-complement-open'),
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              if (widget.user.role == UserRole.school)
                CaseReferralsSection(
                  key: const Key('case-referrals'),
                  user: widget.user,
                  value: value,
                  repository: _referrals,
                  run: _run,
                ),
              if (widget.user.role == UserRole.school) ...[
                const SizedBox(height: 12),
                CaseSchoolContent(
                  key: const Key('case-school-content'),
                  user: widget.user,
                  value: value,
                  repository: widget.repository,
                ),
              ],
              const SizedBox(height: 12),
              Text('Linha do tempo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _TimelineList(key: const Key('case-timeline'), stream: _timeline.stream),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions(StudentCase value) {
    final actions = <Widget>[];
    if (_isTeacher &&
        (value.status == CaseStatus.draft ||
            value.status == CaseStatus.complementRequested)) {
      actions.add(FilledButton.icon(
        key: const Key('case-submit-button'),
        onPressed: _busy
            ? null
            : () => _run(
                  () => widget.repository.submitCase(widget.user, value),
                  'Caso enviado à Direção escolar.',
                ),
        icon: const Icon(Icons.send_outlined),
        label: Text(value.status == CaseStatus.draft
            ? 'Enviar à Direção escolar'
            : 'Enviar complementação'),
      ));
    }
    return actions;
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.stream, super.key});
  final Stream<List<TimelineEvent>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimelineEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Não foi possível carregar a linha do tempo.',
              key: Key('timeline-error'));
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return const Text('Nenhuma movimentação registrada.',
              key: Key('timeline-empty'));
        }
        return Column(
          children: [
            for (final event in events)
              ListTile(
                key: Key('timeline-${event.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  event.visibility == 'interno'
                      ? Icons.lock_outline
                      : Icons.timeline_outlined,
                  color: AppColors.primary,
                ),
                title: Text(event.label),
                subtitle: Text(
                    '${event.actorName} • ${formatDate(event.createdAt)}'),
              ),
          ],
        );
      },
    );
  }
}
