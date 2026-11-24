import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../repositories/case_repository.dart';
import '../repositories/referral_repository.dart';
import '../reports/report_builders.dart';
import '../reports/report_models.dart';
import '../services/auth_service.dart';
import '../utils/shared_stream.dart';
import '../widgets/admin_forms.dart' show formatDate;
import '../widgets/case_referrals_section.dart' show askText;
import '../widgets/dashboard_card.dart';
import '../widgets/load_more.dart';
import '../widgets/page_header.dart';
import '../widgets/section_error.dart';
import '../widgets/status_badge.dart';
import 'casos_screen.dart' show friendlyError;
import 'gerar_relatorio_screen.dart';

/// Encaminhamentos da Saúde: Direção da UBS (todos da unidade, P1-16) ou
/// psicólogo (atribuídos a ele, P1-06).
class EncaminhamentosScreen extends StatefulWidget {
  const EncaminhamentosScreen({
    required this.user,
    this.repository,
    this.caseRepository,
    super.key,
  });

  final AppUser user;
  final ReferralRepository? repository;
  final CaseRepository? caseRepository;

  @override
  State<EncaminhamentosScreen> createState() => _EncaminhamentosScreenState();
}

class _EncaminhamentosScreenState extends State<EncaminhamentosScreen> {
  late final ReferralRepository _repository =
      widget.repository ?? FirebaseReferralRepository();
  late final CaseRepository _cases = widget.caseRepository ?? FirebaseCaseRepository();
  late Stream<List<Referral>> _stream;
  Map<String, String> _names = const {};
  // Cada nome é buscado uma única vez (evita leituras repetidas a cada build).
  final _requestedNames = <String>{};
  bool _onlyActive = true;

  bool get _isUbsDirector => widget.user.healthRole == HealthRole.ubsDirector;
  String? get _ubsId =>
      widget.user.institutionIds.isEmpty ? null : widget.user.institutionIds.first;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  int _limit = listPageSize;

  void _subscribe() {
    final ubsId = _ubsId;
    _stream = _isUbsDirector
        ? (ubsId == null
            ? Stream.value(const [])
            : _repository.watchUbsReferrals(ubsId, limit: _limit))
        : _repository.watchPsychologistReferrals(widget.user.uid, limit: _limit);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Encaminhamentos',
          subtitle: _isUbsDirector
              ? 'Recebidos pela unidade de saúde'
              : 'Atribuídos a você',
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar apenas encaminhamentos ativos'),
          value: _onlyActive,
          onChanged: (v) => setState(() => _onlyActive = v),
        ),
        StreamBuilder<List<Referral>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppCard(
                key: const Key('referrals-error'),
                child: Column(children: [
                  const Text('Não foi possível carregar os encaminhamentos.'),
                  TextButton(
                      onPressed: () => setState(_subscribe),
                      child: const Text('Tentar novamente')),
                ]),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snapshot.data!
                .where((r) => !_onlyActive || r.status.active)
                .toList();
            if (items.isEmpty) {
              return const AppCard(
                key: Key('referrals-empty'),
                child: Text('Nenhum encaminhamento no momento.',
                    textAlign: TextAlign.center),
              );
            }
            final missing = items
                .map((r) => r.originInstitutionId)
                .where((id) => !_names.containsKey(id))
                .where(_requestedNames.add)
                .toList();
            if (missing.isNotEmpty) {
              _repository.institutionNames(missing).then((names) {
                if (mounted) setState(() => _names = {..._names, ...names});
              });
            }
            return Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: ListTile(
                        key: Key('referral-tile-${item.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.studentName),
                        subtitle: Text([
                          _names[item.originInstitutionId] ?? 'Escola',
                          if (item.assignedPsychologistName != null)
                            'Responsável: ${item.assignedPsychologistName}',
                          'Atualizado em ${formatDate(item.updatedAt)}',
                        ].join('\n')),
                        trailing:
                            StatusBadge(label: item.status.label, tone: item.status.tone),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => EncaminhamentoDetalheScreen(
                            user: widget.user,
                            referralId: item.id,
                            repository: _repository,
                            caseRepository: _cases,
                          ),
                        )),
                      ),
                    ),
                  ),
                LoadMoreButton(
                  keyName: 'referrals-load-more',
                  shown: snapshot.data!.length,
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
}

class EncaminhamentoDetalheScreen extends StatefulWidget {
  const EncaminhamentoDetalheScreen({
    required this.user,
    required this.referralId,
    required this.repository,
    required this.caseRepository,
    super.key,
  });

  final AppUser user;
  final String referralId;
  final ReferralRepository repository;
  final CaseRepository caseRepository;

  @override
  State<EncaminhamentoDetalheScreen> createState() =>
      _EncaminhamentoDetalheScreenState();
}

class _EncaminhamentoDetalheScreenState extends State<EncaminhamentoDetalheScreen> {
  late final Stream<Referral?> _referral =
      widget.repository.watchReferral(widget.referralId);
  late final Future<ReferralDetails?> _details =
      widget.repository.getDetails(widget.referralId);
  // D-A04: seções de lista preguiçosa voltam a escutar ao rolar.
  late final SharedStream<List<ReferralNote>> _notes = SharedStream(
      widget.repository.watchNotes(widget.referralId, _isUbsDirector ? 'ubs' : 'psychologist'));
  bool _busy = false;
  SharedStream<List<TimelineEvent>>? _timeline;
  SharedStream<List<HealthReturn>>? _returns;

  @override
  void dispose() {
    _notes.dispose();
    _timeline?.dispose();
    _returns?.dispose();
    super.dispose();
  }

  bool get _isUbsDirector => widget.user.healthRole == HealthRole.ubsDirector;

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _snack(success);
    } catch (error) {
      _snack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openReport(Referral referral) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GerarRelatorioScreen(
        user: widget.user,
        kind: _isUbsDirector ? ReportKind.ubs : ReportKind.health,
        loadSource: () => _isUbsDirector
            ? loadUbsSource(
                ubsDirector: widget.user, referral: referral, referrals: widget.repository)
            : loadHealthSource(
                psychologist: widget.user, referral: referral, referrals: widget.repository),
      ),
    ));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encaminhamento')),
      body: StreamBuilder<Referral?>(
        stream: _referral,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Você não tem mais acesso a este encaminhamento.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final referral = snapshot.data;
          if (referral == null) {
            return const Center(child: Text('Encaminhamento não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(referral.studentName,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      StatusBadge(
                        key: const Key('referral-status'),
                        label: referral.status.label,
                        tone: referral.status.tone,
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('Recebido em ${formatDate(referral.createdAt)}',
                        style: const TextStyle(color: AppColors.muted)),
                    if (referral.assignedPsychologistName != null)
                      Text('Responsável: ${referral.assignedPsychologistName}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<ReferralDetails?>(
                future: _details,
                builder: (context, snap) {
                  final details = snap.data;
                  if (details == null) return const SizedBox.shrink();
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Motivo', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(details.reason),
                        const SizedBox(height: 8),
                        const Text('Resumo mínimo enviado pela escola',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(details.summary),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...(_isUbsDirector
                      ? _ubsActions(referral)
                      : _psychologistActions(referral)),
                  // R-04/R-05: devolutiva do psicólogo; resumo administrativo da UBS.
                  OutlinedButton.icon(
                    key: const Key('referral-generate-pdf'),
                    onPressed: () => _openReport(referral),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(_isUbsDirector ? 'Resumo em PDF' : 'Devolutiva em PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<ReferralNote>>(
                stream: _notes.stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const SectionError('Não foi possível carregar as notas.');
                  }
                  final notes = snap.data ?? const [];
                  if (notes.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notas', style: Theme.of(context).textTheme.titleMedium),
                      for (final note in notes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(note.kindLabel),
                          subtitle: Text(
                              '${note.text}\n${note.authorName} • ${formatDate(note.createdAt)}'),
                        ),
                    ],
                  );
                },
              ),
              StreamBuilder<List<TimelineEvent>>(
                key: const Key('referral-timeline'),
                stream: (_timeline ??= SharedStream(widget.repository
                        .watchReferralTimeline(referral.caseId, referral.id)))
                    .stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const SectionError(
                        'Não foi possível carregar a linha do tempo.');
                  }
                  final events = snap.data ?? const [];
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Linha do tempo do encaminhamento',
                          style: Theme.of(context).textTheme.titleMedium),
                      for (final event in events)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(event.label),
                          subtitle: Text('${event.actorName} • ${formatDate(event.createdAt)}'),
                        ),
                    ],
                  );
                },
              ),
              if (!_isUbsDirector)
                StreamBuilder<List<HealthReturn>>(
                  stream: (_returns ??= SharedStream(
                          widget.repository.watchReturnsForReferral(referral.id)))
                      .stream,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const SectionError(
                          'Não foi possível carregar as devolutivas.');
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Devolutivas', style: Theme.of(context).textTheme.titleMedium),
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Para: ${item.audienceLabel}'),
                            subtitle: Text('${item.content}\n${formatDate(item.createdAt)}'),
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _ubsActions(Referral referral) {
    final r = widget.repository;
    final status = referral.status;
    return [
      if (status == ReferralStatus.sent)
        FilledButton(
          key: const Key('referral-receive'),
          onPressed: _busy
              ? null
              : () => _run(() => r.receive(widget.user, referral),
                  'Recebimento registrado.'),
          child: const Text('Registrar recebimento'),
        ),
      if (status == ReferralStatus.received ||
          status == ReferralStatus.assigned ||
          status == ReferralStatus.inAttendance)
        FilledButton(
          key: const Key('referral-assign'),
          onPressed: _busy ? null : () => _assign(referral),
          child: Text(status == ReferralStatus.received
              ? 'Atribuir psicólogo(a)'
              : 'Transferir responsável'),
        ),
      if (status == ReferralStatus.received ||
          status == ReferralStatus.assigned ||
          status == ReferralStatus.inAttendance)
        OutlinedButton(
          key: const Key('referral-request-complement'),
          onPressed: _busy
              ? null
              : () => _withText('Solicitar complementação à escola',
                  'O que a Direção escolar deve complementar?',
                  (t) => r.requestUbsComplement(widget.user, referral, t),
                  'Complementação solicitada à Direção escolar.'),
          child: const Text('Solicitar complementação'),
        ),
      if (const {
        ReferralStatus.sent,
        ReferralStatus.received,
        ReferralStatus.complementRequested,
        ReferralStatus.assigned,
      }.contains(status)) ...[
        OutlinedButton(
          key: const Key('referral-return'),
          onPressed: _busy
              ? null
              : () => _withText('Devolver encaminhamento', 'Justificativa da devolução',
                  (t) => r.returnReferral(widget.user, referral, t),
                  'Encaminhamento devolvido à escola.'),
          child: const Text('Devolver'),
        ),
        OutlinedButton(
          key: const Key('referral-refuse'),
          onPressed: _busy
              ? null
              : () => _withText('Recusar encaminhamento', 'Justificativa da recusa',
                  (t) => r.refuse(widget.user, referral, t),
                  'Encaminhamento recusado.'),
          child: const Text('Recusar'),
        ),
      ],
      if (status == ReferralStatus.inAttendance ||
          status == ReferralStatus.returnRegistered)
        FilledButton(
          key: const Key('referral-finalize'),
          onPressed: _busy
              ? null
              : () => _run(() => r.finalize(widget.user, referral),
                  'Encaminhamento finalizado.'),
          child: const Text('Finalizar encaminhamento'),
        ),
    ];
  }

  List<Widget> _psychologistActions(Referral referral) {
    final r = widget.repository;
    final status = referral.status;
    final canWork = const {
      ReferralStatus.assigned,
      ReferralStatus.inAttendance,
      ReferralStatus.returnRegistered,
    }.contains(status);
    return [
      if (status == ReferralStatus.assigned)
        FilledButton(
          key: const Key('referral-start'),
          onPressed: _busy
              ? null
              : () => _run(() => r.startAttendance(widget.user, referral),
                  'Atendimento iniciado.'),
          child: const Text('Iniciar atendimento'),
        ),
      if (canWork)
        OutlinedButton(
          key: const Key('referral-progress'),
          onPressed: _busy
              ? null
              : () => _withText('Atualização do acompanhamento',
                  'Registro restrito a você', (t) => r.addProgressNote(widget.user, referral, t),
                  'Atualização registrada.'),
          child: const Text('Registrar atualização'),
        ),
      if (canWork)
        FilledButton(
          key: const Key('referral-health-return'),
          onPressed: _busy ? null : () => _healthReturn(referral),
          child: const Text('Registrar devolutiva'),
        ),
    ];
  }

  Future<void> _withText(String title, String label,
      Future<void> Function(String text) action, String success) async {
    final text = await askText(context, title: title, label: label);
    if (text == null) return;
    await _run(() => action(text), success);
  }

  Future<void> _assign(Referral referral) async {
    final ubsId = referral.destinationInstitutionId;
    final options = (await widget.repository.psychologistsOf(ubsId))
        .where((p) => p.uid != referral.assignedPsychologistUid)
        .toList();
    if (!mounted) return;
    if (options.isEmpty) {
      _snack('Nenhum(a) psicólogo(a) ativo(a) disponível nesta UBS.');
      return;
    }
    final chosen = await showDialog<StaffOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecionar psicólogo(a)'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              key: Key('psychologist-${option.uid}'),
              onPressed: () => Navigator.pop(context, option),
              child: Text(option.name),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await _run(() async {
      final current = await widget.caseRepository.watchCase(referral.caseId).first;
      await widget.repository.assign(widget.user, referral, chosen,
          caseNeedsFollowUp: current?.status == CaseStatus.referred);
    }, 'Responsável definido: ${chosen.name}.');
  }

  Future<void> _healthReturn(Referral referral) async {
    final result = await showDialog<({String content, List<String> audience})>(
      context: context,
      builder: (_) => const _HealthReturnDialog(),
    );
    if (result == null) return;
    await _run(
      () => widget.repository.registerReturn(widget.user, referral,
          content: result.content, audience: result.audience),
      'Devolutiva registrada.',
    );
  }
}

class _HealthReturnDialog extends StatefulWidget {
  const _HealthReturnDialog();

  @override
  State<_HealthReturnDialog> createState() => _HealthReturnDialogState();
}

class _HealthReturnDialogState extends State<_HealthReturnDialog> {
  final _key = GlobalKey<FormState>();
  final _content = TextEditingController();
  bool _school = true;
  bool _family = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Registrar devolutiva'),
        content: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('health-return-content'),
                  controller: _content,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Devolutiva *',
                    helperText:
                        'Orientações para o acompanhamento. Não é prontuário clínico.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Campo obrigatório.'
                      : ((v!.trim().length > 10000) ? 'Texto muito longo.' : null),
                ),
                CheckboxListTile(
                  key: const Key('health-return-school'),
                  contentPadding: EdgeInsets.zero,
                  value: _school,
                  title: const Text('Destinada à escola'),
                  onChanged: (v) => setState(() => _school = v ?? false),
                ),
                CheckboxListTile(
                  key: const Key('health-return-family'),
                  contentPadding: EdgeInsets.zero,
                  value: _family,
                  title: const Text('Destinada à família'),
                  onChanged: (v) => setState(() => _family = v ?? false),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            key: const Key('health-return-submit'),
            onPressed: () {
              if (!(_key.currentState?.validate() ?? false)) return;
              if (!_school && !_family) {
                setState(() => _error = 'Escolha ao menos um destinatário.');
                return;
              }
              Navigator.pop(context, (
                content: _content.text.trim(),
                audience: [if (_school) 'school', if (_family) 'family'],
              ));
            },
            child: const Text('Registrar'),
          ),
        ],
      );
}
