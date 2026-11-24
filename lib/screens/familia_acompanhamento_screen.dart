import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../models/student_models.dart';
import '../reports/report_builders.dart';
import '../reports/report_export_log.dart';
import '../reports/report_models.dart';
import '../repositories/family_repository.dart';
import '../services/auth_service.dart';
import '../utils/shared_stream.dart';
import '../widgets/admin_forms.dart' show formatDate;
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_error.dart';
import '../widgets/status_badge.dart';
import 'gerar_relatorio_screen.dart';

/// Acompanhamento familiar (P1-08): somente consulta (D-17). Após a aprovação
/// pela Direção escolar, a família vê o histórico administrativo completo
/// (D-16), os encaminhamentos e as devolutivas destinadas a ela.
class FamiliaAcompanhamentoScreen extends StatefulWidget {
  const FamiliaAcompanhamentoScreen({
    required this.user,
    this.repository,
    this.focusCaseId,
    this.reportExportLog,
    super.key,
  });

  final ReportExportLog? reportExportLog;

  final AppUser user;
  final FamilyRepository? repository;

  /// Acompanhamento aberto a partir de uma notificação (destacado na tela).
  final String? focusCaseId;

  @override
  State<FamiliaAcompanhamentoScreen> createState() =>
      _FamiliaAcompanhamentoScreenState();
}

class _FamiliaAcompanhamentoScreenState extends State<FamiliaAcompanhamentoScreen> {
  late final FamilyRepository _repository =
      widget.repository ?? FirebaseFamilyRepository();
  late final String? _studentId =
      widget.user.studentIds.isEmpty ? null : widget.user.studentIds.first;
  Student? _student;
  // D-A04: seções de uma lista preguiçosa voltam a escutar ao rolar.
  late final SharedStream<List<StudentCase>> _cases;
  late final SharedStream<List<Referral>> _referrals;
  late final SharedStream<List<HealthReturn>> _returns;
  final _timelines = <String, SharedStream<List<TimelineEvent>>>{};
  Map<String, String> _names = const {};
  // Cada nome é buscado uma única vez (evita leituras repetidas a cada build).
  final _requestedNames = <String>{};
  final _focusKey = GlobalKey();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final id = _studentId;
    _cases = SharedStream(
        id == null ? Stream.value(const []) : _repository.watchCases(id));
    _referrals = SharedStream(
        id == null ? Stream.value(const []) : _repository.watchReferrals(id));
    _returns = SharedStream(
        id == null ? Stream.value(const []) : _repository.watchReturns(id));
    if (id != null) {
      _repository.student(id).then((s) {
        if (mounted) setState(() => _student = s);
      });
    }
  }

  @override
  void dispose() {
    _cases.dispose();
    _referrals.dispose();
    _returns.dispose();
    for (final stream in _timelines.values) {
      stream.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Acompanhamento familiar',
          subtitle: _student == null
              ? 'Movimentações autorizadas do estudante vinculado'
              : _student!.label,
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<StudentCase>>(
          stream: _cases.stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AppCard(
                key: Key('family-error'),
                child: Text('Não foi possível carregar o acompanhamento.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cases = snapshot.data!;
            if (cases.isEmpty) {
              return const AppCard(
                key: Key('family-empty'),
                child: Text(
                  'Ainda não há acompanhamento disponível. Ele aparece aqui quando a '
                  'Direção escolar aprovar o caso.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!_focused && cases.any((c) => c.id == widget.focusCaseId)) {
              _focused = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final target = _focusKey.currentContext;
                if (target != null && target.mounted) {
                  Scrollable.ensureVisible(target,
                      duration: const Duration(milliseconds: 300));
                }
              });
            }
            return Column(
              children: [for (final item in cases) _caseCard(item)],
            );
          },
        ),
        const SizedBox(height: 12),
        _referralsCard(),
        const SizedBox(height: 12),
        _returnsCard(),
      ],
    );
  }

  Widget _caseCard(StudentCase value) => Padding(
        key: value.id == widget.focusCaseId ? _focusKey : null,
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          key: Key('family-case-${value.id}'),
          highlighted: value.id == widget.focusCaseId,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Situação atual',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                StatusBadge(
                  key: Key('family-case-status-${value.id}'),
                  label: value.status.label,
                  tone: value.status.tone,
                ),
              ]),
              Text('Aprovado em ${formatDate(value.approvedAt)}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              // R-05: relatório só com o conteúdo liberado à família.
              OutlinedButton.icon(
                key: Key('family-generate-pdf-${value.id}'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => GerarRelatorioScreen(
                    user: widget.user,
                    kind: ReportKind.family,
                    exportLog: widget.reportExportLog,
                    loadSource: () => loadFamilySource(
                        family: widget.user, value: value, repository: _repository),
                  ),
                )),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Gerar PDF'),
              ),
              const SizedBox(height: 8),
              const Text('Linha do tempo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              StreamBuilder<List<TimelineEvent>>(
                key: Key('family-timeline-${value.id}'),
                stream: _timelines
                    .putIfAbsent(value.id,
                        () => SharedStream(_repository.watchTimeline(value.id)))
                    .stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Não foi possível carregar a linha do tempo.');
                  }
                  final events = snapshot.data ?? const [];
                  return Column(
                    children: [
                      for (final event in events)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.circle, size: 10, color: AppColors.primary),
                          title: Text(event.label),
                          subtitle: Text('${event.actorName} • ${formatDate(event.createdAt)}'),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  Widget _referralsCard() => StreamBuilder<List<Referral>>(
        stream: _referrals.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SectionError(
                'Não foi possível carregar os encaminhamentos.');
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          final missing = items
              .map((r) => r.destinationInstitutionId)
              .where((id) => !_names.containsKey(id))
                .where(_requestedNames.add)
                .toList();
          if (missing.isNotEmpty) {
            _repository.institutionNames(missing).then((names) {
              if (mounted) setState(() => _names = {..._names, ...names});
            });
          }
          return AppCard(
            key: const Key('family-referrals'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Encaminhamentos', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_names[item.destinationInstitutionId] ?? 'UBS'),
                    subtitle: Text(item.assignedPsychologistName == null
                        ? 'Aguardando definição do profissional'
                        : 'Profissional responsável: ${item.assignedPsychologistName}'),
                    trailing: StatusBadge(label: item.status.label, tone: item.status.tone),
                  ),
              ],
            ),
          );
        },
      );

  Widget _returnsCard() => StreamBuilder<List<HealthReturn>>(
        stream: _returns.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SectionError(
                'Não foi possível carregar as devolutivas.');
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          return AppCard(
            key: const Key('family-returns'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Devolutivas para a família',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.content),
                    subtitle: Text('${item.authorName} • ${formatDate(item.createdAt)}'),
                  ),
              ],
            ),
          );
        },
      );
}
