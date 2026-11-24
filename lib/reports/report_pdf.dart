import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/brand_mark.dart' show brandMarkSvg;
import 'report_models.dart';

/// Fontes embutidas no PDF (Roboto, Apache 2.0): acentuação e símbolos do
/// português sem depender de rede nem das fontes padrão do PDF.
class ReportFonts {
  const ReportFonts({
    required this.regular,
    required this.medium,
    required this.bold,
    required this.italic,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;
  final pw.Font italic;

  static ReportFonts? _cached;

  static Future<ReportFonts> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    Future<pw.Font> font(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
    return _cached = ReportFonts(
      regular: await font('Roboto-Regular'),
      medium: await font('Roboto-Medium'),
      bold: await font('Roboto-Bold'),
      italic: await font('Roboto-Italic'),
    );
  }

  factory ReportFonts.fromBytes({
    required ByteData regular,
    required ByteData medium,
    required ByteData bold,
    required ByteData italic,
  }) =>
      ReportFonts(
        regular: pw.Font.ttf(regular),
        medium: pw.Font.ttf(medium),
        bold: pw.Font.ttf(bold),
        italic: pw.Font.ttf(italic),
      );
}

/// Identidade visual do documento. Sem [logoPng], o documento usa o símbolo
/// vetorial da marca (docs/identidade/).
class ReportBranding {
  const ReportBranding({this.logoPng});
  final Uint8List? logoPng;
}

// Paleta do app (lib/app/theme.dart).
const _navy = PdfColor.fromInt(0xFF1E3A5F);
const _blue = PdfColor.fromInt(0xFF2563EB);
const _sky = PdfColor.fromInt(0xFF93C5FD);
const _ice = PdfColor.fromInt(0xFFDBEAFE);
const _mist = PdfColor.fromInt(0xFFF1F5F9);
const _ink = PdfColor.fromInt(0xFF1E293B);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFE2E8F0);

/// Gera o PDF A4 do [document] (papel timbrado do Caminho Azul).
Future<Uint8List> buildReportPdf(
  ReportDocument document, {
  required ReportFonts fonts,
  ReportBranding branding = const ReportBranding(),
}) async {
  final pdf = pw.Document(
    title: document.title,
    subject: document.title,
    author: 'Caminho Azul',
    creator: 'Caminho Azul',
    producer: 'Caminho Azul',
    keywords: 'Caminho Azul, acompanhamento',
  );
  final theme = pw.ThemeData.withFont(
    base: fonts.regular,
    bold: fonts.bold,
    italic: fonts.italic,
    boldItalic: fonts.bold,
  ).copyWith(
    defaultTextStyle: pw.TextStyle(
        font: fonts.regular, fontSize: 10.5, lineSpacing: 2.2, color: _ink),
  );
  final logo = branding.logoPng == null ? null : pw.MemoryImage(branding.logoPng!);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(52, 40, 52, 46),
        theme: theme,
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.CustomPaint(
            painter: (canvas, size) =>
                _paintGeometry(canvas, size, first: context.pageNumber == 1),
          ),
        ),
      ),
      header: (context) => context.pageNumber == 1
          ? _letterhead(document, fonts, logo)
          : _compactHeader(document, fonts),
      footer: (context) => _footer(document, fonts, context),
      build: (context) => [
        _titleBlock(document, fonts),
        pw.SizedBox(height: 14),
        _identification(document, fonts),
        for (final section in document.sections) ..._section(section, fonts),
        pw.SizedBox(height: 22),
        _responsible(document, fonts),
        if (document.notice != null) ...[
          pw.SizedBox(height: 14),
          pw.Text(document.notice!,
              style: pw.TextStyle(font: fonts.italic, fontSize: 8.5, color: _muted)),
        ],
      ],
    ),
  );
  return pdf.save();
}

// ------------------------------------------------------------- papel timbrado

/// Composição geométrica discreta: triângulos no canto superior direito e
/// faixa no canto inferior esquerdo (origem do PDF no canto inferior esquerdo).
void _paintGeometry(PdfGraphics canvas, PdfPoint size, {required bool first}) {
  void poly(List<PdfPoint> points, PdfColor color) {
    canvas
      ..setFillColor(color)
      ..moveTo(points.first.x, points.first.y);
    for (final p in points.skip(1)) {
      canvas.lineTo(p.x, p.y);
    }
    canvas
      ..closePath()
      ..fillPath();
  }

  final w = size.x;
  final h = size.y;
  final scale = first ? 1.0 : 0.55;
  // Canto superior direito.
  poly([PdfPoint(w - 210 * scale, h), PdfPoint(w, h), PdfPoint(w, h - 120 * scale)], _ice);
  poly([PdfPoint(w - 120 * scale, h), PdfPoint(w, h), PdfPoint(w, h - 78 * scale)], _sky);
  poly([PdfPoint(w - 56 * scale, h), PdfPoint(w, h), PdfPoint(w, h - 40 * scale)], _blue);
  // Canto inferior esquerdo.
  poly([const PdfPoint(0, 0), PdfPoint(150 * scale, 0), PdfPoint(0, 64 * scale)], _ice);
  poly([const PdfPoint(0, 0), PdfPoint(72 * scale, 0), PdfPoint(0, 32 * scale)], _navy);
  // Filete lateral.
  canvas
    ..setFillColor(_blue)
    ..drawRect(0, 64 * scale + 8, 3, h - 64 * scale - 8 - (first ? 150 : 90))
    ..fillPath();
}

/// Símbolo da marca (Acolhida), vetorial, enquanto o documento não recebe um
/// [ReportBranding.logoPng]. Mesma geometria de `BrandMark` no app.
pw.Widget _mark({double size = 34}) => pw.SizedBox(
      width: size,
      height: size,
      child: pw.SvgImage(svg: brandMarkSvg()),
    );

pw.Widget _letterhead(ReportDocument d, ReportFonts f, pw.ImageProvider? logo) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          logo == null
              ? _mark()
              : pw.SizedBox(width: 34, height: 34, child: pw.Image(logo)),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Caminho Azul',
                    style: pw.TextStyle(font: f.bold, fontSize: 16, color: _navy)),
                pw.Text('Integração entre escola, família e rede de cuidado',
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(right: 70),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('DOCUMENTO DE ACOMPANHAMENTO',
                    style: pw.TextStyle(
                        font: f.medium, fontSize: 7.5, color: _blue, letterSpacing: 0.8)),
                pw.Text('Emitido em ${formatReportDate(d.issuedAt, withTime: true)}',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );

pw.Widget _compactHeader(ReportDocument d, ReportFonts f) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
      ),
      child: pw.Row(children: [
        _mark(size: 16),
        pw.SizedBox(width: 6),
        pw.Text('Caminho Azul', style: pw.TextStyle(font: f.bold, fontSize: 9, color: _navy)),
        pw.Text('  •  ${d.title}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
      ]),
    );

pw.Widget _footer(ReportDocument d, ReportFonts f, pw.Context context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Caminho Azul  •  Documento gerado a partir de registros autorizados  •  '
              'Uso restrito ao acompanhamento do estudante',
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(font: f.medium, fontSize: 8, color: _navy)),
        ],
      ),
    );

// ------------------------------------------------------------------- corpo

pw.Widget _titleBlock(ReportDocument d, ReportFonts f) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 36, height: 3, color: _blue),
        pw.SizedBox(height: 8),
        pw.Text(d.title, style: pw.TextStyle(font: f.bold, fontSize: 20, color: _navy)),
        if (d.subtitle != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(d.subtitle!, style: const pw.TextStyle(fontSize: 10, color: _muted)),
        ],
      ],
    );

pw.Widget _identification(ReportDocument d, ReportFonts f) {
  final fields = [
    ...d.identification,
    if (d.periodLabel != null) ReportField('Período', d.periodLabel!),
  ];
  final rows = <pw.TableRow>[];
  for (var i = 0; i < fields.length; i += 2) {
    pw.Widget cell(ReportField? field) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: field == null
              ? pw.SizedBox()
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(field.label.toUpperCase(),
                        style: pw.TextStyle(
                            font: f.medium, fontSize: 7, color: _muted, letterSpacing: 0.6)),
                    pw.SizedBox(height: 1),
                    pw.Text(field.value, style: pw.TextStyle(font: f.medium, fontSize: 10)),
                  ],
                ),
        );
    rows.add(pw.TableRow(children: [
      cell(fields[i]),
      cell(i + 1 < fields.length ? fields[i + 1] : null),
    ]));
  }
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: _mist,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _line),
    ),
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth()},
      children: rows,
    ),
  );
}

/// Widgets de nível superior (o MultiPage só quebra página entre eles e
/// dentro de parágrafos): textos longos seguem para as páginas seguintes.
List<pw.Widget> _section(ReportSection s, ReportFonts f) => [
      pw.SizedBox(height: 18),
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _sky, width: 1.2)),
        ),
        child: pw.Text(s.heading.toUpperCase(),
            style: pw.TextStyle(font: f.bold, fontSize: 10, color: _blue, letterSpacing: 0.9)),
      ),
      if (s.intro != null) ...[
        pw.SizedBox(height: 6),
        pw.Paragraph(
            text: s.intro!,
            style: const pw.TextStyle(fontSize: 9.5, color: _muted),
            margin: pw.EdgeInsets.zero),
      ],
      if (s.entries.isEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(s.emptyText, style: pw.TextStyle(font: f.italic, fontSize: 9.5, color: _muted)),
      ],
      for (final entry in s.entries) ..._entry(entry, f),
    ];

List<pw.Widget> _entry(ReportEntry e, ReportFonts f) => [
      pw.SizedBox(height: 10),
      pw.Text(e.title, style: pw.TextStyle(font: f.bold, fontSize: 10.5, color: _ink)),
      if (e.meta != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(e.meta!, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        ),
      if (e.body != null && e.body!.trim().isNotEmpty)
        for (final paragraph in e.body!.trim().split(RegExp(r'\n\s*\n')))
          pw.Paragraph(
            text: paragraph.replaceAll('\n', ' '),
            margin: const pw.EdgeInsets.only(top: 4),
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.2, color: _ink),
          ),
      for (final bullet in e.bullets)
        pw.Bullet(
          text: bullet,
          margin: const pw.EdgeInsets.only(top: 3, left: 4),
          bulletColor: _blue,
          bulletSize: 3.2,
          style: const pw.TextStyle(fontSize: 10),
        ),
    ];

pw.Widget _responsible(ReportDocument d, ReportFonts f) => pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RESPONSÁVEL PELA EMISSÃO',
                    style: pw.TextStyle(
                        font: f.medium, fontSize: 7, color: _muted, letterSpacing: 0.6)),
                pw.SizedBox(height: 3),
                pw.Text(d.responsible.name,
                    style: pw.TextStyle(font: f.bold, fontSize: 11, color: _navy)),
                pw.Text(
                  [d.responsible.roleLabel, d.responsible.institution]
                      .whereType<String>()
                      .join(' • '),
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(width: 150, height: 0.8, color: _muted),
              pw.SizedBox(height: 3),
              pw.Text('Emitido em ${formatReportDate(d.issuedAt)}',
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
        ],
      ),
    );
