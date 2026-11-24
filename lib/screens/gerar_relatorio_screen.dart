import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app/theme.dart';
import '../reports/report_builders.dart';
import '../reports/report_export_log.dart';
import '../reports/report_models.dart';
import '../reports/report_pdf.dart';
import '../reports/report_share.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/section_error.dart';

/// Geração de PDF (R-06): o usuário escolhe período e registros; a fonte já
/// foi carregada só com as consultas que as regras permitem a ele.
class GerarRelatorioScreen extends StatefulWidget {
  const GerarRelatorioScreen({
    required this.user,
    required this.kind,
    required this.loadSource,
    this.exportLog,
    this.output = const PlatformReportOutput(),
    this.fonts,
    super.key,
  });

  final AppUser user;
  final ReportKind kind;
  final Future<ReportSource> Function() loadSource;
  final ReportExportLog? exportLog;
  final ReportOutput output;

  /// Testes injetam as fontes; o app carrega dos assets.
  final Future<ReportFonts> Function()? fonts;

  @override
  State<GerarRelatorioScreen> createState() => _GerarRelatorioScreenState();
}

class _GerarRelatorioScreenState extends State<GerarRelatorioScreen> {
  late final Future<ReportSource> _source = widget.loadSource();
  late final ReportExportLog _log = widget.exportLog ?? FirebaseReportExportLog();
  final _selected = <String>{};
  ReportPeriod _period = const ReportPeriod();
  bool _generating = false;

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _period.from : _period.to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: start ? 'Início do período' : 'Fim do período',
    );
    if (picked == null) return;
    setState(() => _period = start
        ? ReportPeriod(from: picked, to: _period.to)
        : ReportPeriod(from: _period.from, to: picked));
  }

  int _includedCount(ReportSource source) => source.allItems
      .where((i) => _selected.contains(i.id) && _period.contains(i.date))
      .length;

  Future<void> _generate(ReportSource source) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final document = buildReportDocument(source, selected: _selected, period: _period);
      final fonts = await (widget.fonts ?? ReportFonts.load)();
      final bytes = await buildReportPdf(document, fonts: fonts);
      await _record(source, document, ReportExportAction.generated);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RelatorioPreviewScreen(
          document: document,
          bytes: bytes,
          output: widget.output,
          onAction: (action) => _record(source, document, action),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Não foi possível gerar o PDF.')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Registro de metadados; uma falha de registro não impede o uso do PDF.
  Future<void> _record(ReportSource source, ReportDocument document,
      ReportExportAction action) async {
    try {
      await _log.record(
        actor: widget.user,
        kind: source.kind,
        action: action,
        caseId: source.caseId,
        referralId: source.referralId,
        itemCount: document.entryCount,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.title)),
      body: FutureBuilder<ReportSource>(
        future: _source,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: SectionError(
                  'Não foi possível carregar os registros. Verifique se você ainda '
                  'tem acesso a este acompanhamento.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Carregando os registros autorizados…'),
              ]),
            );
          }
          final source = snapshot.data!;
          final count = _includedCount(source);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Escolha o período e os registros que farão parte do documento. '
                      'Somente informações que você já pode consultar aparecem aqui.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    _periodCard(),
                    for (final group in source.groups) _groupCard(group),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          count == 0
                              ? 'Nenhum registro selecionado'
                              : count == 1
                                  ? '1 registro selecionado'
                                  : '$count registros selecionados',
                          key: const Key('report-selected-count'),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('report-generate'),
                      onPressed: count == 0 || _generating ? null : () => _generate(source),
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Gerar PDF'),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _periodCard() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Período', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  key: const Key('report-period-from'),
                  onPressed: () => _pickDate(start: true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_period.from == null
                      ? 'Desde o início'
                      : 'De ${formatReportDate(_period.from)}'),
                ),
                OutlinedButton.icon(
                  key: const Key('report-period-to'),
                  onPressed: () => _pickDate(start: false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_period.to == null
                      ? 'Até hoje'
                      : 'Até ${formatReportDate(_period.to)}'),
                ),
                if (!_period.isOpen)
                  TextButton(
                    key: const Key('report-period-clear'),
                    onPressed: () => setState(() => _period = const ReportPeriod()),
                    child: const Text('Todo o período'),
                  ),
              ]),
            ],
          ),
        ),
      );

  Widget _groupCard(ReportCandidateGroup group) {
    final inPeriod = group.items.where((i) => _period.contains(i.date)).toList();
    final allSelected =
        inPeriod.isNotEmpty && inPeriod.every((i) => _selected.contains(i.id));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: Key('report-group-${group.key}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(group.heading,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              if (inPeriod.isNotEmpty)
                TextButton(
                  key: Key('report-toggle-${group.key}'),
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.removeAll(inPeriod.map((i) => i.id));
                    } else {
                      _selected.addAll(inPeriod.map((i) => i.id));
                    }
                  }),
                  child: Text(allSelected ? 'Limpar' : 'Selecionar todos'),
                ),
            ]),
            if (group.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Nenhum registro disponível.',
                    style: TextStyle(color: AppColors.muted)),
              ),
            for (final item in group.items)
              CheckboxListTile(
                key: Key('report-item-${item.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selected.contains(item.id) && _period.contains(item.date),
                onChanged: _period.contains(item.date)
                    ? (checked) => setState(() => checked == true
                        ? _selected.add(item.id)
                        : _selected.remove(item.id))
                    : null,
                title: Text(item.title),
                subtitle: Text(
                  [
                    if (!_period.contains(item.date)) 'Fora do período',
                    if (item.meta != null) item.meta!,
                    if (item.body != null) item.body!,
                  ].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pré-visualização e saídas do PDF (R-07, R-08).
class RelatorioPreviewScreen extends StatelessWidget {
  const RelatorioPreviewScreen({
    required this.document,
    required this.bytes,
    required this.output,
    required this.onAction,
    super.key,
  });

  final ReportDocument document;
  final Uint8List bytes;
  final ReportOutput output;
  final Future<void> Function(ReportExportAction action) onAction;

  void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _share(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar documento'),
        content: const Text(
          'Este PDF contém informações pessoais do estudante. Compartilhe apenas com '
          'quem participa do acompanhamento.\n\nO Caminho Azul não envia o arquivo: '
          'você escolhe o destino (por exemplo, o WhatsApp) no menu do aparelho ou do '
          'navegador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('report-share-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compartilhar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final opened = await output.share(bytes, document.fileName, document.title);
      if (!context.mounted) return;
      if (opened) {
        await onAction(ReportExportAction.shareSheetOpened);
        if (!context.mounted) return;
        _snack(context,
            'Menu de compartilhamento aberto. O envio é concluído no aplicativo escolhido.');
      } else {
        _snack(context, 'Compartilhamento não disponível neste navegador. Use "Baixar PDF".');
      }
    } catch (_) {
      if (context.mounted) _snack(context, 'Não foi possível abrir o compartilhamento.');
    }
  }

  Future<void> _print(BuildContext context) async {
    try {
      await output.printOrSave(bytes, document.fileName);
      await onAction(ReportExportAction.printOrSaveOpened);
    } catch (_) {
      if (context.mounted) _snack(context, 'Não foi possível abrir a impressão.');
    }
  }

  Future<void> _download(BuildContext context) async {
    try {
      await output.download(bytes, document.fileName);
      await onAction(ReportExportAction.downloaded);
      if (context.mounted) _snack(context, 'PDF disponível em ${document.fileName}.');
    } catch (error) {
      // Só o tipo/mensagem técnica do erro, nunca o conteúdo do documento.
      debugPrint('Falha ao baixar o PDF: $error');
      if (context.mounted) _snack(context, 'Não foi possível baixar o PDF.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = pdfPageCount(bytes);
    return Scaffold(
      appBar: AppBar(title: const Text('Pré-visualização')),
      body: output.isWeb
          // Web: sem rasterizar no app (evita carregar o pdf.js de CDN de
          // terceiros); a visualização usa o leitor de PDF do navegador.
          ? ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                key: const Key('report-preview-summary'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('$pages ${pages == 1 ? 'página' : 'páginas'} • '
                        '${document.entryCount} registros • ${document.fileName}'),
                    const SizedBox(height: 12),
                    for (final section in document.sections)
                      Text('• ${section.heading} (${section.entries.length})'),
                    const SizedBox(height: 12),
                    const Text(
                      'Use "Visualizar ou imprimir" para abrir o documento no leitor de PDF '
                      'do navegador.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ])
          : PdfPreview(
              key: const Key('report-preview'),
              build: (_) async => bytes,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: document.fileName,
              useActions: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (output.canShareFiles)
                FilledButton.icon(
                  key: const Key('report-share'),
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                ),
              OutlinedButton.icon(
                key: const Key('report-print'),
                onPressed: () => _print(context),
                icon: const Icon(Icons.print_outlined),
                label: Text(output.isWeb ? 'Visualizar ou imprimir' : 'Imprimir ou salvar'),
              ),
              if (output.isWeb)
                OutlinedButton.icon(
                  key: const Key('report-download'),
                  onPressed: () => _download(context),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar PDF'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
