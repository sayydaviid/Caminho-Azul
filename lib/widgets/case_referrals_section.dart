import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../repositories/referral_repository.dart';
import '../services/auth_service.dart';
import 'admin_forms.dart' show formatDate;
import 'dashboard_card.dart';
import 'section_error.dart';
import 'status_badge.dart';

/// Ações da Direção escolar e encaminhamentos do caso (P1-05, D-20).
class CaseDirectorActions extends StatelessWidget {
  const CaseDirectorActions({
    required this.user,
    required this.value,
    required this.repository,
    required this.run,
    super.key,
  });

  final AppUser user;
  final StudentCase value;
  final ReferralRepository repository;
  final Future<void> Function(Future<void> Function() action, String success) run;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    switch (value.status) {
      case CaseStatus.awaitingReview:
        buttons.addAll([
          OutlinedButton.icon(
            key: const Key('case-request-complement'),
            onPressed: () async {
              if (!await _confirm(context, 'Solicitar complementação?',
                  'O caso volta ao professor para complementar os registros.')) {
                return;
              }
              await run(() => repository.requestSchoolComplement(user, value),
                  'Complementação solicitada ao professor.');
            },
            icon: const Icon(Icons.undo_outlined),
            label: const Text('Solicitar complementação'),
          ),
          FilledButton.icon(
            key: const Key('case-approve'),
            onPressed: () async {
              if (!await _confirm(context, 'Aprovar o caso?',
                  'A família vinculada ao estudante passará a acompanhar o histórico '
                      'administrativo do caso (sem observações internas).')) {
                return;
              }
              await run(() => repository.approve(user, value),
                  'Caso aprovado e disponibilizado à família.');
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Aprovar e disponibilizar à família'),
          ),
        ]);
      case CaseStatus.approved || CaseStatus.referred || CaseStatus.inFollowUp:
        buttons.addAll([
          FilledButton.icon(
            key: const Key('case-send-referral'),
            onPressed: () => _send(context),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Encaminhar à UBS'),
          ),
          OutlinedButton.icon(
            key: const Key('case-conclude'),
            onPressed: value.activeReferrals.isNotEmpty
                ? null
                : () async {
                    if (!await _confirm(context, 'Concluir o acompanhamento?',
                        'O caso será concluído e não poderá mais ser alterado.')) {
                      return;
                    }
                    await run(() => repository.conclude(user, value),
                        'Acompanhamento concluído.');
                  },
            icon: const Icon(Icons.task_alt_outlined),
            label: Text(value.activeReferrals.isEmpty
                ? 'Concluir acompanhamento'
                : 'Concluir (aguardando encaminhamentos ativos)'),
          ),
        ]);
      default:
        break;
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<void> _send(BuildContext context) async {
    final options = (await repository.activeUbs())
        .where((u) => !value.activeReferrals.containsValue(u.id))
        .toList();
    if (!context.mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não há UBS ativa disponível para novo encaminhamento.')));
      return;
    }
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReferralForm(
        options: options,
        onSubmit: (ubsId, reason, summary) async {
          await repository.send(user, value,
              ubsId: ubsId, reason: reason, summary: summary);
          return 'Encaminhamento enviado à UBS.';
        },
      ),
    );
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

/// Encaminhamentos do caso vistos pela escola.
class CaseReferralsSection extends StatefulWidget {
  const CaseReferralsSection({
    required this.user,
    required this.value,
    required this.repository,
    required this.run,
    super.key,
  });

  final AppUser user;
  final StudentCase value;
  final ReferralRepository repository;
  final Future<void> Function(Future<void> Function() action, String success) run;

  @override
  State<CaseReferralsSection> createState() => _CaseReferralsSectionState();
}

class _CaseReferralsSectionState extends State<CaseReferralsSection> {
  late final Stream<List<Referral>> _referrals;
  Map<String, String> _names = const {};
  // Cada nome é buscado uma única vez (evita leituras repetidas a cada build).
  final _requestedNames = <String>{};

  bool get _isDirector => widget.user.schoolRole == SchoolRole.director;

  @override
  void initState() {
    super.initState();
    _referrals = widget.repository.watchSchoolCaseReferrals(
        widget.value.id, widget.value.schoolInstitutionId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Referral>>(
      stream: _referrals,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Não foi possível carregar os encaminhamentos.');
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        final missing = items
            .map((r) => r.destinationInstitutionId)
            .where((id) => !_names.containsKey(id))
                .where(_requestedNames.add)
                .toList();
        if (missing.isNotEmpty) {
          widget.repository.institutionNames(missing).then((names) {
            if (mounted) setState(() => _names = {..._names, ...names});
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Encaminhamentos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final referral in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _names[referral.destinationInstitutionId] ??
                                  referral.destinationInstitutionId,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          StatusBadge(
                              label: referral.status.label, tone: referral.status.tone),
                        ],
                      ),
                      if (referral.assignedPsychologistName != null)
                        Text('Responsável: ${referral.assignedPsychologistName}',
                            style: const TextStyle(color: AppColors.muted)),
                      if (_isDirector) ...[
                        _Notes(repository: widget.repository, referral: referral),
                        if (referral.status == ReferralStatus.complementRequested)
                          _ComplementActions(
                            user: widget.user,
                            value: widget.value,
                            referral: referral,
                            repository: widget.repository,
                            run: widget.run,
                          ),
                      ],
                      _SchoolReturns(
                        repository: widget.repository,
                        referral: referral,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.repository, required this.referral});
  final ReferralRepository repository;
  final Referral referral;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ReferralNote>>(
        stream: repository.watchNotes(referral.id, 'school'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SectionError('Não foi possível carregar as notas.');
          }
          final notes = snapshot.data ?? const [];
          if (notes.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${note.kindLabel} (${note.authorName}, '
                      '${formatDate(note.createdAt)}): ${note.text}'),
                ),
            ],
          );
        },
      );
}

class _SchoolReturns extends StatelessWidget {
  const _SchoolReturns({
    required this.repository,
    required this.referral,
  });
  final ReferralRepository repository;
  final Referral referral;

  @override
  Widget build(BuildContext context) {
    // Devolutivas destinadas à escola: Direção e professor vinculado
    // (MATRIZ_PERMISSOES: [IE]/[VP] + audiência school).
    return StreamBuilder<List<HealthReturn>>(
      stream: repository.watchReturnsForReferral(referral.id,
          audience: 'school', caseId: referral.caseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionError('Não foi possível carregar as devolutivas.');
        }
        final items = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Devolutiva (${item.authorName}, ${formatDate(item.createdAt)}): ${item.content}',
                  key: Key('school-return-${item.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ComplementActions extends StatelessWidget {
  const _ComplementActions({
    required this.user,
    required this.value,
    required this.referral,
    required this.repository,
    required this.run,
  });
  final AppUser user;
  final StudentCase value;
  final Referral referral;
  final ReferralRepository repository;
  final Future<void> Function(Future<void> Function() action, String success) run;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!value.complementOpen)
              OutlinedButton(
                key: const Key('referral-forward-teacher'),
                onPressed: () => run(
                    () => repository.forwardComplementToTeacher(user, value),
                    'Pedido repassado ao professor.'),
                child: const Text('Repassar ao professor'),
              ),
            FilledButton(
              key: const Key('referral-answer-ubs'),
              onPressed: () async {
                final text = await askText(context,
                    title: 'Responder à UBS', label: 'Complementação enviada à UBS');
                if (text == null) return;
                await run(
                    () => repository.answerUbsComplement(user, value, referral, text),
                    'Complementação enviada à UBS.');
              },
              child: const Text('Responder à UBS'),
            ),
          ],
        ),
      );
}

Future<bool> _confirm(BuildContext context, String title, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    ) ??
    false;

/// Pede um texto obrigatório (justificativa, complementação, atualização).
Future<String?> askText(BuildContext context,
    {required String title, required String label}) {
  final controller = TextEditingController();
  final key = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: TextFormField(
          key: const Key('ask-text-field'),
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            final text = v?.trim() ?? '';
            if (text.isEmpty) return 'Campo obrigatório.';
            if (text.length > 5000) return 'Use no máximo 5000 caracteres.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          key: const Key('ask-text-submit'),
          onPressed: () {
            if (key.currentState?.validate() ?? false) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
}

class _ReferralForm extends StatefulWidget {
  const _ReferralForm({required this.options, required this.onSubmit});
  final List<InstitutionOption> options;
  final Future<String> Function(String ubsId, String reason, String summary) onSubmit;

  @override
  State<_ReferralForm> createState() => _ReferralFormState();
}

class _ReferralFormState extends State<_ReferralForm> {
  final _key = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _summary = TextEditingController();
  String? _ubsId;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final message = await widget.onSubmit(_ubsId!, _reason.text, _summary.text);
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(text.contains('permission-denied')
                ? 'Você não tem permissão para esta operação.'
                : text.replaceFirst(RegExp(r'^\w*Exception:\s*'), ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Encaminhar à UBS', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('referral-ubs'),
                  value: _ubsId,
                  decoration: const InputDecoration(labelText: 'UBS de destino *'),
                  items: [
                    for (final option in widget.options)
                      DropdownMenuItem(value: option.id, child: Text(option.name)),
                  ],
                  validator: (v) => v == null ? 'Selecione a UBS.' : null,
                  onChanged: _saving ? null : (v) => setState(() => _ubsId = v),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('referral-reason'),
                  controller: _reason,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Motivo do encaminhamento *'),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Campo obrigatório.'
                      : ((v!.trim().length > 1000) ? 'Use no máximo 1000 caracteres.' : null),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('referral-summary'),
                  controller: _summary,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Resumo mínimo para a UBS *',
                    helperText:
                        'Compartilhe só o necessário. Observações internas não são enviadas.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Campo obrigatório.'
                      : ((v!.trim().length > 5000) ? 'Use no máximo 5000 caracteres.' : null),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('referral-submit'),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar encaminhamento'),
                ),
              ],
            ),
          ),
        ),
      );
}
