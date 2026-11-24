/// Relatórios em PDF (R-01..R-06). Modelo neutro do documento: os
/// construtores de cada tipo (report_builders.dart) só usam dados já
/// carregados por consultas autorizadas e os itens que o usuário selecionou.
enum ReportKind {
  /// Professor vinculado: observações e registros pedagógicos (R-02).
  pedagogical('pedagogical', 'Relatório pedagógico', 'relatorio-pedagogico'),

  /// Direção escolar: acompanhamento escolar do caso (R-03).
  school('school', 'Relatório de acompanhamento escolar',
      'relatorio-acompanhamento-escolar'),

  /// Psicólogo atribuído: devolutiva profissional (R-04).
  health('health', 'Devolutiva profissional', 'devolutiva-profissional'),

  /// Direção da UBS: resumo administrativo do encaminhamento (R-05).
  ubs('ubs', 'Resumo administrativo do encaminhamento',
      'resumo-encaminhamento'),

  /// Família: somente o conteúdo destinado a ela (R-05).
  family('family', 'Relatório de acompanhamento para a família',
      'relatorio-familia');

  const ReportKind(this.value, this.title, this.fileSlug);

  final String value;
  final String title;
  final String fileSlug;
}

/// Um par rótulo/valor do bloco de identificação.
class ReportField {
  const ReportField(this.label, this.value);
  final String label;
  final String value;
}

/// Um registro do corpo (observação, registro, evento, devolutiva...).
class ReportEntry {
  const ReportEntry({
    required this.title,
    this.meta,
    this.body,
    this.bullets = const [],
  });

  final String title;

  /// Linha secundária (autor, data, situação).
  final String? meta;
  final String? body;
  final List<String> bullets;
}

class ReportSection {
  const ReportSection({
    required this.heading,
    this.intro,
    this.entries = const [],
    this.emptyText = 'Nenhum registro selecionado para esta seção.',
  });

  final String heading;
  final String? intro;
  final List<ReportEntry> entries;
  final String emptyText;
}

/// Quem emite o documento (área de identificação do responsável).
class ReportResponsible {
  const ReportResponsible({
    required this.name,
    required this.roleLabel,
    this.institution,
  });

  final String name;
  final String roleLabel;
  final String? institution;
}

class ReportDocument {
  const ReportDocument({
    required this.kind,
    required this.identification,
    required this.sections,
    required this.responsible,
    required this.issuedAt,
    this.subtitle,
    this.periodLabel,
    this.notice,
  });

  final ReportKind kind;
  final String? subtitle;
  final List<ReportField> identification;
  final List<ReportSection> sections;
  final ReportResponsible responsible;
  final DateTime issuedAt;
  final String? periodLabel;

  /// Aviso de confidencialidade/escopo no fim do documento.
  final String? notice;

  String get title => kind.title;

  int get entryCount =>
      sections.fold(0, (total, section) => total + section.entries.length);

  /// Nome de arquivo padronizado, sem nome do estudante (não identificável).
  String get fileName {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = issuedAt;
    return 'caminho-azul-${kind.fileSlug}-${d.year}${two(d.month)}${two(d.day)}'
        '-${two(d.hour)}${two(d.minute)}.pdf';
  }
}

String formatReportDate(DateTime? value, {bool withTime = false}) {
  if (value == null) return 'Não informado';
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(value.day)}/${two(value.month)}/${value.year}';
  return withTime ? '$date às ${two(value.hour)}:${two(value.minute)}' : date;
}
