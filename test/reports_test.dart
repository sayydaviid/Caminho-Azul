// R-01..R-08 — relatórios em PDF: montagem, permissões dos dados, template
// e fluxo de geração/compartilhamento (com fakes; sem Firebase).
import 'dart:io';
import 'dart:typed_data';

import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/reports/report_builders.dart';
import 'package:caminho_azul/reports/report_export_log.dart';
import 'package:caminho_azul/reports/report_models.dart';
import 'package:caminho_azul/reports/report_pdf.dart';
import 'package:caminho_azul/reports/report_share.dart';
import 'package:caminho_azul/screens/gerar_relatorio_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'referral_family_screens_test.dart' show FakeFamilyRepository;
import 'support/empty_referral_repository.dart';

ByteData _font(String name) =>
    ByteData.sublistView(File('assets/fonts/$name.ttf').readAsBytesSync());

final _fonts = ReportFonts.fromBytes(
  regular: _font('Roboto-Regular'),
  medium: _font('Roboto-Medium'),
  bold: _font('Roboto-Bold'),
  italic: _font('Roboto-Italic'),
);

/// Com CAMINHO_AZUL_PDF_OUT definido, grava os PDFs para inspeção visual.
void _maybeSave(String name, Uint8List bytes) {
  final dir = Platform.environment['CAMINHO_AZUL_PDF_OUT'];
  if (dir == null) return;
  File('$dir/$name').writeAsBytesSync(bytes);
}

const _teacher = AppUser(
  uid: 'prof',
  email: 'prof@caminhoazul.test',
  name: 'Professora Sintética',
  role: UserRole.school,
  schoolRole: SchoolRole.teacher,
  institutionIds: ['escola-a'],
);

const _psychologist = AppUser(
  uid: 'psi',
  email: 'psi@caminhoazul.test',
  name: 'Psicóloga Sintética',
  role: UserRole.health,
  healthRole: HealthRole.psychologist,
  institutionIds: ['ubs-a'],
);

const _family = AppUser(
  uid: 'fam',
  email: 'familia@caminhoazul.test',
  name: 'Família Sintética',
  role: UserRole.family,
  studentIds: ['s1'],
);

const _referral = Referral(
  id: 'r1',
  caseId: 'c1',
  studentId: 's1',
  studentName: 'Estudante Sintético',
  originInstitutionId: 'escola-a',
  destinationInstitutionId: 'ubs-a',
  status: ReferralStatus.returnRegistered,
  assignedPsychologistUid: 'psi',
  assignedPsychologistName: 'Psicóloga Sintética',
  lastEventId: 'e1',
);

const _case = StudentCase(
  id: 'c1',
  studentId: 's1',
  studentName: 'Estudante Sintético',
  schoolInstitutionId: 'escola-a',
  primaryTeacherUid: 'prof',
  teacherUids: ['prof'],
  status: CaseStatus.inFollowUp,
  familyVisible: true,
  complementOpen: false,
  activeReferrals: {'r1': 'ubs-a'},
  lastEventId: 'e',
);

/// Psicólogo: devolutivas próprias; as notas restritas existem no
/// repositório, mas o carregador não deve usá-las.
class _HealthRepository extends EmptyReferralRepository {
  int notesCalls = 0;

  @override
  Stream<List<HealthReturn>> watchReturnsForReferral(String referralId,
          {String? audience, String? caseId}) =>
      Stream.value([
        HealthReturn(
          id: 'h1',
          referralId: referralId,
          caseId: 'c1',
          studentId: 's1',
          audience: const ['school', 'family'],
          content: 'Orientações à família: rotina visual e antecipação de mudanças.',
          authorName: 'Psicóloga Sintética',
          createdAt: DateTime(2026, 11, 20),
        ),
      ]);

  @override
  Stream<List<ReferralNote>> watchNotes(String referralId, String audience) {
    notesCalls++;
    return Stream.value(const [
      ReferralNote(
          id: 'n1', kind: 'progress', text: 'NOTA RESTRITA', authorName: 'Psicóloga'),
    ]);
  }

  @override
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async =>
      {for (final id in ids) id: id == 'ubs-a' ? 'UBS Horizonte (sintética)' : 'Escola Azul (sintética)'};
}

ReportSource sampleSource({int bodyRepeat = 1}) => _source(bodyRepeat: bodyRepeat);

ReportSource _source({int bodyRepeat = 1}) => ReportSource(
      kind: ReportKind.pedagogical,
      caseId: 'c1',
      identification: const [
        ReportField('Instituição', 'Escola Municipal Azul (sintética)'),
        ReportField('Estudante', 'Estudante Sintético'),
        ReportField('Turma', '3º ano B'),
        ReportField('Caso', 'Nº C1 • Em acompanhamento'),
      ],
      responsible: const ReportResponsible(
          name: 'Professora Sintética', roleLabel: 'Professor(a)', institution: 'Escola Azul'),
      groups: [
        ReportCandidateGroup(key: 'observations', heading: 'Observações selecionadas', items: [
          ReportCandidate(
            id: 'observation:o1',
            title: 'Sala de aula — atenção compartilhada',
            date: DateTime(2026, 10, 2),
            meta: 'Observado em 02/10/2026',
            body: List.filled(bodyRepeat,
                    'Participou da roda de conversa com apoio visual; ação, atenção, ênfase, '
                    'coração, pôr do sol, "aspas" – travessão — e símbolos º ª § ½.')
                .join(' '),
          ),
          ReportCandidate(
            id: 'observation:o2',
            title: 'Recreio — interação',
            date: DateTime(2026, 11, 15),
            body: 'Brincou em dupla durante o recreio.',
          ),
        ]),
        ReportCandidateGroup(key: 'records', heading: 'Síntese e ações pedagógicas', items: [
          ReportCandidate(
            id: 'record:p1',
            title: 'Registro pedagógico de 16/11/2026',
            date: DateTime(2026, 11, 16),
            body: 'Síntese das observações do bimestre.',
            bullets: const ['Ação: rotina visual', 'Ação: tempo extra nas atividades'],
          ),
        ]),
      ],
    );

class FakeOutput implements ReportOutput {
  final calls = <String>[];

  @override
  bool get isWeb => true; // sem PdfPreview (rasterização) no teste

  @override
  bool get canShareFiles => true;

  @override
  Future<bool> share(Uint8List bytes, String fileName, String title) async {
    calls.add('share:$fileName');
    return true;
  }

  @override
  Future<void> printOrSave(Uint8List bytes, String fileName) async => calls.add('print');

  @override
  Future<void> download(Uint8List bytes, String fileName) async => calls.add('download');
}

class FakeLog implements ReportExportLog {
  final actions = <String>[];

  @override
  Future<void> record({
    required AppUser actor,
    required ReportKind kind,
    required ReportExportAction action,
    required String caseId,
    String? referralId,
    required int itemCount,
  }) async =>
      actions.add('${kind.value}:${action.value}:$itemCount');
}

void main() {
  test('R-06: só itens selecionados e no período entram no documento', () {
    final source = _source();
    final doc = buildReportDocument(source,
        selected: {'observation:o1', 'observation:o2'},
        period: ReportPeriod(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30)),
        issuedAt: DateTime(2026, 11, 24, 9, 5));
    expect(doc.sections, hasLength(1));
    expect(doc.sections.single.entries.map((e) => e.title), ['Recreio — interação']);
    expect(doc.periodLabel, '01/11/2026 a 30/11/2026');
    // Nome padronizado e sem o nome do estudante.
    expect(doc.fileName, 'caminho-azul-relatorio-pedagogico-20261124-0905.pdf');
    expect(doc.fileName.toLowerCase(), isNot(contains('estudante')));
    final nothing = buildReportDocument(source, selected: const {});
    expect(nothing.entryCount, 0);
  });

  test('R-04: devolutiva do psicólogo não usa notas restritas', () async {
    final repository = _HealthRepository();
    final source = await loadHealthSource(
        psychologist: _psychologist, referral: _referral, referrals: repository);
    expect(repository.notesCalls, 0);
    final texts = source.allItems.map((i) => '${i.title} ${i.meta} ${i.body}').join(' ');
    expect(texts, isNot(contains('NOTA RESTRITA')));
    expect(texts, contains('Elaborada por Psicóloga Sintética'));
    expect(source.responsible.roleLabel, 'Psicólogo(a)');
  });

  test('R-05: relatório da família só com o que é destinado a ela', () async {
    final source = await loadFamilySource(
        family: _family, value: _case, repository: FakeFamilyRepository());
    final returns = source.groups.firstWhere((g) => g.key == 'returns').items;
    // FakeFamilyRepository devolve devolutivas da família e uma só da escola.
    for (final item in returns) {
      expect(item.meta, contains('Família'));
    }
    expect(source.groups.map((g) => g.key), ['timeline', 'referrals', 'returns']);
  });

  test('R-01: PDF A4 com várias páginas, acentuação e metadados', () async {
    final source = _source(bodyRepeat: 120);
    final doc = buildReportDocument(source,
        selected: source.allItems.map((i) => i.id).toSet(),
        issuedAt: DateTime(2026, 11, 24, 9, 5));
    final bytes = await buildReportPdf(doc, fonts: _fonts);
    _maybeSave('teste_multipaginas.pdf', bytes);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(pdfPageCount(bytes), greaterThan(2));
    final raw = String.fromCharCodes(bytes);
    expect(raw, contains('/MediaBox[0 0 595.27559 841.88976]')); // A4
    expect(raw, contains('/Title(Relat'));
    expect(raw, contains('Caminho Azul'));

    final shortSource = _source();
    final short = await buildReportPdf(
        buildReportDocument(shortSource,
            selected: shortSource.allItems.map((i) => i.id).toSet(),
            issuedAt: DateTime(2026, 11, 24, 9, 5)),
        fonts: _fonts);
    _maybeSave('teste_curto.pdf', short);
    expect(pdfPageCount(short), 1);
  });

  testWidgets('R-06..R-08: selecionar, gerar, pré-visualizar e compartilhar com confirmação',
      (tester) async {
    final output = FakeOutput();
    final log = FakeLog();
    await tester.pumpWidget(MaterialApp(
      home: GerarRelatorioScreen(
        user: _teacher,
        kind: ReportKind.pedagogical,
        loadSource: () async => _source(),
        exportLog: log,
        output: output,
        fonts: () async => _fonts,
      ),
    ));
    await tester.pumpAndSettle();
    // Nada selecionado por padrão: não gera.
    final generate = find.byKey(const Key('report-generate'));
    expect(tester.widget<ButtonStyleButton>(generate).onPressed, isNull);
    await tester.tap(find.byKey(const Key('report-item-observation:o1')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-toggle-records')));
    await tester.pump();
    expect(find.text('2 registros selecionados'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(generate);
      for (var i = 0; i < 50 && find.byType(RelatorioPreviewScreen).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(RelatorioPreviewScreen), findsOneWidget);
    expect(log.actions, ['pedagogical:generated:2']);
    expect(find.textContaining('2 registros'), findsOneWidget);

    // Compartilhar exige confirmação; cancelar não abre o menu.
    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();
    expect(find.textContaining('informações pessoais do estudante'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(output.calls, isEmpty);
    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-share-confirm')));
    await tester.pumpAndSettle();
    expect(output.calls.single, startsWith('share:caminho-azul-relatorio-pedagogico-'));
    expect(log.actions.last, 'pedagogical:share_opened:2');
    // O app não afirma que o envio foi entregue.
    expect(find.textContaining('O envio é concluído no aplicativo escolhido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-download')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-print')));
    await tester.pumpAndSettle();
    expect(output.calls.skip(1), ['download', 'print']);
    expect(log.actions.skip(2), ['pedagogical:downloaded:2', 'pedagogical:print_opened:2']);
  });

  testWidgets('R-06: falha de permissão ao carregar mostra aviso e não gera', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GerarRelatorioScreen(
        user: _teacher,
        kind: ReportKind.pedagogical,
        loadSource: () async => throw Exception('permission-denied'),
        exportLog: FakeLog(),
        output: FakeOutput(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verifique se você ainda tem acesso'), findsOneWidget);
    expect(find.byKey(const Key('report-generate')), findsNothing);
  });
}
