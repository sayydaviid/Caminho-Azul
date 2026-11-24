import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/case_models.dart';
import '../repositories/case_repository.dart';
import '../services/auth_service.dart';
import 'admin_forms.dart' show formatDate;
import 'dashboard_card.dart';

/// Observações (P1-03) e registros pedagógicos (P1-04) do caso. Conteúdo
/// interno à escola: as regras negam leitura a família, Saúde e admin.
class CaseSchoolContent extends StatefulWidget {
  const CaseSchoolContent({
    required this.user,
    required this.value,
    required this.repository,
    super.key,
  });

  final AppUser user;
  final StudentCase value;
  final CaseRepository repository;

  @override
  State<CaseSchoolContent> createState() => _CaseSchoolContentState();
}

class _CaseSchoolContentState extends State<CaseSchoolContent> {
  late final Stream<List<Observation>> _observations;
  late final Stream<List<PedagogicalRecord>> _records;
  List<Observation> _latestObservations = const [];

  bool get _canWrite =>
      widget.user.schoolRole == SchoolRole.teacher &&
      widget.value.teacherUids.contains(widget.user.uid) &&
      widget.value.acceptsSchoolContent;

  @override
  void initState() {
    super.initState();
    _observations = widget.repository.watchObservations(widget.value.id);
    _records = widget.repository.watchRecords(widget.value.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Observações pedagógicas',
          action: _canWrite
              ? TextButton.icon(
                  key: const Key('case-add-observation'),
                  onPressed: _addObservation,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova observação'),
                )
              : null,
        ),
        StreamBuilder<List<Observation>>(
          key: const Key('case-observations'),
          stream: _observations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Não foi possível carregar as observações.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            _latestObservations = snapshot.data!;
            if (_latestObservations.isEmpty) {
              return const Text('Nenhuma observação registrada.',
                  style: TextStyle(color: AppColors.muted));
            }
            return Column(
              children: [
                for (final item in _latestObservations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.context,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(item.description),
                          const SizedBox(height: 4),
                          Text(
                            '${item.authorName} • observado em ${formatDate(item.observedAt)}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _Header(
          title: 'Registros pedagógicos',
          action: _canWrite
              ? TextButton.icon(
                  key: const Key('case-add-record'),
                  onPressed: _addRecord,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo registro'),
                )
              : null,
        ),
        StreamBuilder<List<PedagogicalRecord>>(
          key: const Key('case-records'),
          stream: _records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Não foi possível carregar os registros.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final records = snapshot.data!;
            if (records.isEmpty) {
              return const Text('Nenhum registro pedagógico.',
                  style: TextStyle(color: AppColors.muted));
            }
            return Column(
              children: [
                for (final item in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.summary),
                          if (item.actions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            for (final action in item.actions) Text('• $action'),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${item.authorName} • ${formatDate(item.createdAt)} • '
                            '${item.observationIds.length} observação(ões) referenciada(s)',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _addObservation() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ObservationForm(
        onSubmit: (contextText, description, observedAt) async {
          await widget.repository.addObservation(
            widget.user,
            widget.value,
            context: contextText,
            description: description,
            observedAt: observedAt,
          );
          return 'Observação registrada.';
        },
      ),
    );
    _show(message);
  }

  Future<void> _addRecord() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecordForm(
        observations: _latestObservations,
        onSubmit: (summary, actions, ids) async {
          await widget.repository.addRecord(
            widget.user,
            widget.value,
            summary: summary,
            actions: actions,
            observationIds: ids,
          );
          return 'Registro pedagógico salvo.';
        },
      ),
    );
    _show(message);
  }

  void _show(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

/// Formulário base com envio único e mensagem de erro amigável.
class _SheetForm extends StatefulWidget {
  const _SheetForm({
    required this.title,
    required this.fields,
    required this.onSubmit,
  });

  final String title;
  final List<Widget> Function(bool saving) fields;
  final Future<String> Function() onSubmit;

  @override
  State<_SheetForm> createState() => _SheetFormState();
}

class _SheetFormState extends State<_SheetForm> {
  final _key = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving || !(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final message = await widget.onSubmit();
      if (mounted) Navigator.pop(context, message);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(text.contains('permission-denied')
              ? 'Você não tem permissão para esta operação.'
              : text.replaceFirst(RegExp(r'^\w*Exception:\s*'), '')),
        ));
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
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...widget.fields(_saving),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('case-form-submit'),
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
        ),
      );
}

String? _required(String? value, {int max = 5000}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Campo obrigatório.';
  if (text.length > max) return 'Use no máximo $max caracteres.';
  return null;
}

class _ObservationForm extends StatefulWidget {
  const _ObservationForm({required this.onSubmit});
  final Future<String> Function(String context, String description, DateTime at)
      onSubmit;

  @override
  State<_ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends State<_ObservationForm> {
  final _context = TextEditingController();
  final _description = TextEditingController();
  DateTime _observedAt = DateTime.now();

  @override
  void dispose() {
    _context.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
        title: 'Nova observação pedagógica',
        onSubmit: () =>
            widget.onSubmit(_context.text, _description.text, _observedAt),
        fields: (saving) => [
          TextFormField(
            key: const Key('observation-context'),
            controller: _context,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: 'Contexto *',
              hintText: 'Ex.: sala de aula, recreio, atividade em grupo',
            ),
            validator: (v) => _required(v, max: 200),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('observation-description'),
            controller: _description,
            enabled: !saving,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Descrição objetiva *',
              helperText:
                  'Registre fatos observáveis. Não inclua diagnóstico ou hipótese clínica.',
              helperMaxLines: 2,
            ),
            validator: _required,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _observedAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _observedAt = picked);
                  },
            icon: const Icon(Icons.event_outlined),
            label: Text('Observado em ${formatDate(_observedAt).split(' ').first}'),
          ),
        ],
      );
}

class _RecordForm extends StatefulWidget {
  const _RecordForm({required this.observations, required this.onSubmit});
  final List<Observation> observations;
  final Future<String> Function(
      String summary, List<String> actions, List<String> observationIds) onSubmit;

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _summary = TextEditingController();
  final _actions = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _summary.dispose();
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
        title: 'Novo registro pedagógico',
        onSubmit: () => widget.onSubmit(
          _summary.text,
          _actions.text.split('\n'),
          _selected.toList(),
        ),
        fields: (saving) => [
          TextFormField(
            key: const Key('record-summary'),
            controller: _summary,
            enabled: !saving,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Síntese pedagógica *',
              helperText: 'Sem diagnóstico: descreva percurso, necessidades e apoios.',
            ),
            validator: _required,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('record-actions'),
            controller: _actions,
            enabled: !saving,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Ações pedagógicas (uma por linha)',
            ),
          ),
          if (widget.observations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Observações referenciadas'),
            for (final item in widget.observations)
              CheckboxListTile(
                key: Key('record-observation-${item.id}'),
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(item.id),
                title: Text(item.context),
                subtitle: Text(item.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onChanged: saving
                    ? null
                    : (checked) => setState(() => checked == true
                        ? _selected.add(item.id)
                        : _selected.remove(item.id)),
              ),
          ],
        ],
      );
}
