import 'dart:async';

import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../models/student_models.dart';
import '../repositories/case_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/referral_repository.dart';
import '../repositories/student_repository.dart';
import '../services/auth_service.dart';
import 'report_models.dart';

/// Item que o usuário pode incluir no documento (R-06: seleção explícita;
/// nada entra por padrão).
class ReportCandidate {
  const ReportCandidate({
    required this.id,
    required this.title,
    this.date,
    this.meta,
    this.body,
    this.bullets = const [],
  });

  final String id;
  final String title;
  final DateTime? date;
  final String? meta;
  final String? body;
  final List<String> bullets;

  ReportEntry toEntry() =>
      ReportEntry(title: title, meta: meta, body: body, bullets: bullets);
}

class ReportCandidateGroup {
  const ReportCandidateGroup({
    required this.key,
    required this.heading,
    required this.items,
    this.intro,
  });

  final String key;
  final String heading;
  final String? intro;
  final List<ReportCandidate> items;
}

/// Tudo o que o usuário pode pôr no documento, já carregado por consultas
/// que as regras permitem a ele. A geração nunca consulta mais nada.
class ReportSource {
  const ReportSource({
    required this.kind,
    required this.caseId,
    required this.identification,
    required this.responsible,
    required this.groups,
    this.referralId,
    this.subtitle,
    this.notice,
  });

  final ReportKind kind;
  final String caseId;
  final String? referralId;
  final String? subtitle;
  final List<ReportField> identification;
  final ReportResponsible responsible;
  final List<ReportCandidateGroup> groups;
  final String? notice;

  Iterable<ReportCandidate> get allItems => groups.expand((g) => g.items);
}

/// Período de inclusão (datas inclusivas). Itens sem data só entram se não
/// houver período definido.
class ReportPeriod {
  const ReportPeriod({this.from, this.to});
  final DateTime? from;
  final DateTime? to;

  bool get isOpen => from == null && to == null;

  bool contains(DateTime? date) {
    if (isOpen) return true;
    if (date == null) return false;
    final start = from == null ? null : DateTime(from!.year, from!.month, from!.day);
    final end = to == null ? null : DateTime(to!.year, to!.month, to!.day, 23, 59, 59);
    return (start == null || !date.isBefore(start)) && (end == null || !date.isAfter(end));
  }

  String? get label {
    if (isOpen) return null;
    if (from != null && to != null) {
      return '${formatReportDate(from)} a ${formatReportDate(to)}';
    }
    return from != null ? 'A partir de ${formatReportDate(from)}' : 'Até ${formatReportDate(to)}';
  }
}

/// Monta o documento só com os itens selecionados e dentro do período.
ReportDocument buildReportDocument(
  ReportSource source, {
  required Set<String> selected,
  ReportPeriod period = const ReportPeriod(),
  DateTime? issuedAt,
}) {
  final sections = <ReportSection>[
    for (final group in source.groups)
      if (group.items.any((i) => selected.contains(i.id)))
        ReportSection(
          heading: group.heading,
          intro: group.intro,
          entries: [
            for (final item in group.items)
              if (selected.contains(item.id) && period.contains(item.date)) item.toEntry(),
          ],
          emptyText: 'Nenhum registro selecionado no período.',
        ),
  ];
  return ReportDocument(
    kind: source.kind,
    subtitle: source.subtitle,
    identification: source.identification,
    sections: sections,
    responsible: source.responsible,
    issuedAt: issuedAt ?? DateTime.now(),
    periodLabel: period.label,
    notice: source.notice,
  );
}

// ----------------------------------------------------------------- rótulos

String roleLabelOf(AppUser user) => switch (user.role) {
      UserRole.school => user.schoolRole == SchoolRole.director
          ? 'Direção escolar'
          : 'Professor(a)',
      UserRole.health => user.healthRole == HealthRole.ubsDirector
          ? 'Direção da UBS'
          : 'Psicólogo(a)',
      UserRole.family => 'Responsável familiar',
      UserRole.administration => 'Administração',
    };

String actorRoleLabel(String actorRole) => switch (actorRole) {
      'school/teacher' => 'Professor(a)',
      'school/director' => 'Direção escolar',
      'health/ubs_director' => 'Direção da UBS',
      'health/psychologist' => 'Psicólogo(a)',
      _ => 'Equipe',
    };

String _short(String id) => id.length <= 6 ? id.toUpperCase() : id.substring(0, 6).toUpperCase();

List<ReportCandidate> _events(Iterable<TimelineEvent> events) => [
      for (final e in events)
        ReportCandidate(
          id: 'event:${e.id}',
          title: e.label,
          date: e.createdAt,
          meta: '${e.actorName} (${actorRoleLabel(e.actorRole)}) • '
              '${formatReportDate(e.createdAt, withTime: true)}',
        ),
    ];

List<ReportCandidate> _referrals(Iterable<Referral> items, Map<String, String> names) => [
      for (final r in items)
        ReportCandidate(
          id: 'referral:${r.id}',
          title: names[r.destinationInstitutionId] ?? 'Unidade de saúde',
          date: r.createdAt,
          meta: 'Situação: ${r.status.label} • Enviado em ${formatReportDate(r.createdAt)}',
          bullets: [
            if (r.assignedPsychologistName != null)
              'Profissional responsável: ${r.assignedPsychologistName}'
            else
              'Profissional responsável: ainda não definido',
            'Última atualização: ${formatReportDate(r.updatedAt)}',
          ],
        ),
    ];

List<ReportCandidate> _returns(Iterable<HealthReturn> items, {String prefix = 'return'}) => [
      for (final h in items)
        ReportCandidate(
          id: '$prefix:${h.id}',
          title: 'Devolutiva de ${formatReportDate(h.createdAt)}',
          date: h.createdAt,
          meta: 'Elaborada por ${h.authorName} (Psicólogo(a)) • Destinada a: ${h.audienceLabel}',
          body: h.content,
        ),
    ];

Future<T> _first<T>(Stream<T> stream) =>
    stream.first.timeout(const Duration(seconds: 20));

// ------------------------------------------------------------------ loaders

/// R-02: professor vinculado. Observações e registros pedagógicos do caso.
Future<ReportSource> loadPedagogicalSource({
  required AppUser teacher,
  required StudentCase value,
  required CaseRepository cases,
  required ReferralRepository referrals,
  StudentRepository? students,
}) async {
  final observations = await _first(cases.watchObservations(value.id));
  final records = await _first(cases.watchRecords(value.id));
  final names = await referrals.institutionNames([value.schoolInstitutionId]);
  final student = await _student(students, value);
  final observationTitles = {for (final o in observations) o.id: o.context};
  return ReportSource(
    kind: ReportKind.pedagogical,
    caseId: value.id,
    subtitle: 'Registros da escola sobre o desenvolvimento do estudante',
    identification: [
      ReportField('Instituição', names[value.schoolInstitutionId] ?? 'Escola'),
      ReportField('Estudante', value.studentName),
      ReportField('Turma', student?.grade ?? 'Não informada'),
      ReportField('Caso', 'Nº ${_short(value.id)} • ${value.status.label}'),
      ReportField('Professor(a) responsável', teacher.name ?? teacher.email),
    ],
    responsible: ReportResponsible(
      name: teacher.name ?? teacher.email,
      roleLabel: roleLabelOf(teacher),
      institution: names[value.schoolInstitutionId],
    ),
    groups: [
      ReportCandidateGroup(
        key: 'observations',
        heading: 'Observações selecionadas',
        intro: 'Registros descritivos feitos pela equipe pedagógica, sem caráter diagnóstico.',
        items: [
          for (final o in observations)
            ReportCandidate(
              id: 'observation:${o.id}',
              title: o.context,
              date: o.observedAt ?? o.createdAt,
              meta: 'Observado em ${formatReportDate(o.observedAt)} • Registrado por ${o.authorName}',
              body: o.description,
            ),
        ],
      ),
      ReportCandidateGroup(
        key: 'records',
        heading: 'Síntese e ações pedagógicas',
        items: [
          for (final r in records)
            ReportCandidate(
              id: 'record:${r.id}',
              title: 'Registro pedagógico de ${formatReportDate(r.createdAt)}',
              date: r.createdAt,
              meta: 'Elaborado por ${r.authorName}'
                  '${r.observationIds.isEmpty ? '' : ' • Baseado em: ${r.observationIds.map((id) => observationTitles[id] ?? 'observação').join(', ')}'}',
              body: r.summary,
              bullets: [for (final action in r.actions) 'Ação: $action'],
            ),
        ],
      ),
    ],
    notice: 'Documento pedagógico: descreve observações e ações da escola e não contém '
        'diagnóstico ou conclusão clínica.',
  );
}

/// R-03: Direção escolar. Situação, histórico, registros, encaminhamentos e
/// devolutivas destinadas à escola.
Future<ReportSource> loadSchoolSource({
  required AppUser director,
  required StudentCase value,
  required CaseRepository cases,
  required ReferralRepository referrals,
  StudentRepository? students,
}) async {
  final timeline = await _first(cases.watchSchoolTimeline(value.id));
  final observations = await _first(cases.watchObservations(value.id));
  final records = await _first(cases.watchRecords(value.id));
  final caseReferrals =
      await _first(referrals.watchSchoolCaseReferrals(value.id, value.schoolInstitutionId));
  final names = await referrals.institutionNames(
      [value.schoolInstitutionId, ...caseReferrals.map((r) => r.destinationInstitutionId)]);
  final details = <ReportCandidate>[];
  final returns = <HealthReturn>[];
  for (final r in caseReferrals) {
    final d = await referrals.getDetails(r.id);
    if (d != null) {
      details.add(ReportCandidate(
        id: 'details:${r.id}',
        title: 'Encaminhamento a ${names[r.destinationInstitutionId] ?? 'UBS'}',
        date: r.createdAt,
        meta: 'Motivo e resumo mínimo enviados pela Direção escolar',
        body: 'Motivo: ${d.reason}\n\nResumo: ${d.summary}',
      ));
    }
    returns.addAll(await _first(
        referrals.watchReturnsForReferral(r.id, audience: 'school', caseId: value.id)));
  }
  final student = await _student(students, value);
  return ReportSource(
    kind: ReportKind.school,
    caseId: value.id,
    subtitle: 'Situação administrativa e acompanhamento escolar do caso',
    identification: [
      ReportField('Instituição', names[value.schoolInstitutionId] ?? 'Escola'),
      ReportField('Estudante', value.studentName),
      ReportField('Turma', student?.grade ?? 'Não informada'),
      ReportField('Caso', 'Nº ${_short(value.id)}'),
      ReportField('Situação atual', value.status.label),
      ReportField('Aprovado em', formatReportDate(value.approvedAt)),
    ],
    responsible: ReportResponsible(
      name: director.name ?? director.email,
      roleLabel: roleLabelOf(director),
      institution: names[value.schoolInstitutionId],
    ),
    groups: [
      ReportCandidateGroup(key: 'timeline', heading: 'Histórico relevante', items: _events(timeline)),
      ReportCandidateGroup(
        key: 'records',
        heading: 'Registros pedagógicos autorizados',
        items: [
          for (final r in records)
            ReportCandidate(
              id: 'record:${r.id}',
              title: 'Registro pedagógico de ${formatReportDate(r.createdAt)}',
              date: r.createdAt,
              meta: 'Elaborado por ${r.authorName}',
              body: r.summary,
              bullets: [for (final action in r.actions) 'Ação: $action'],
            ),
        ],
      ),
      ReportCandidateGroup(
        key: 'observations',
        heading: 'Observações pedagógicas',
        items: [
          for (final o in observations)
            ReportCandidate(
              id: 'observation:${o.id}',
              title: o.context,
              date: o.observedAt ?? o.createdAt,
              meta: 'Observado em ${formatReportDate(o.observedAt)} • ${o.authorName}',
              body: o.description,
            ),
        ],
      ),
      ReportCandidateGroup(
          key: 'referrals', heading: 'Encaminhamentos', items: _referrals(caseReferrals, names)),
      ReportCandidateGroup(key: 'details', heading: 'Motivo e resumo dos encaminhamentos', items: details),
      ReportCandidateGroup(
        key: 'returns',
        heading: 'Devolutivas destinadas à escola',
        intro: 'Conteúdo elaborado pelo psicólogo responsável e liberado para a escola.',
        items: _returns(returns),
      ),
    ],
    notice: 'Uso interno da escola. Contém informações pessoais do estudante: compartilhe '
        'apenas com quem participa do acompanhamento.',
  );
}

/// R-04: psicólogo atribuído. Devolutivas que ele registrou no
/// encaminhamento; notas restritas de atendimento nunca entram.
Future<ReportSource> loadHealthSource({
  required AppUser psychologist,
  required Referral referral,
  required ReferralRepository referrals,
}) async {
  final returns = await _first(referrals.watchReturnsForReferral(referral.id));
  final names = await referrals.institutionNames(
      [referral.destinationInstitutionId, referral.originInstitutionId]);
  return ReportSource(
    kind: ReportKind.health,
    caseId: referral.caseId,
    referralId: referral.id,
    subtitle: 'Devolutiva do atendimento na unidade de saúde',
    identification: [
      ReportField('Unidade de saúde', names[referral.destinationInstitutionId] ?? 'UBS'),
      ReportField('Escola de origem', names[referral.originInstitutionId] ?? 'Escola'),
      ReportField('Estudante', referral.studentName),
      ReportField('Encaminhamento', 'Nº ${_short(referral.id)} • ${referral.status.label}'),
      ReportField('Profissional responsável', psychologist.name ?? psychologist.email),
      ReportField('Acompanhamento',
          '${formatReportDate(referral.createdAt)} a ${formatReportDate(referral.updatedAt)}'),
    ],
    responsible: ReportResponsible(
      name: psychologist.name ?? psychologist.email,
      roleLabel: roleLabelOf(psychologist),
      institution: names[referral.destinationInstitutionId],
    ),
    groups: [
      ReportCandidateGroup(
        key: 'returns',
        heading: 'Devolutiva',
        intro: 'Texto registrado pelo profissional responsável, com a autoria preservada.',
        items: _returns(returns),
      ),
    ],
    notice: 'Notas restritas de atendimento não fazem parte deste documento. Verifique a '
        'audiência de cada devolutiva antes de compartilhar.',
  );
}

/// R-05: Direção da UBS. Somente dados administrativos do encaminhamento.
Future<ReportSource> loadUbsSource({
  required AppUser ubsDirector,
  required Referral referral,
  required ReferralRepository referrals,
}) async {
  final timeline = await _first(referrals.watchReferralTimeline(referral.caseId, referral.id));
  final details = await referrals.getDetails(referral.id);
  final names = await referrals.institutionNames(
      [referral.destinationInstitutionId, referral.originInstitutionId]);
  return ReportSource(
    kind: ReportKind.ubs,
    caseId: referral.caseId,
    referralId: referral.id,
    subtitle: 'Situação e histórico administrativo do encaminhamento',
    identification: [
      ReportField('Unidade de saúde', names[referral.destinationInstitutionId] ?? 'UBS'),
      ReportField('Escola de origem', names[referral.originInstitutionId] ?? 'Escola'),
      ReportField('Estudante', referral.studentName),
      ReportField('Encaminhamento', 'Nº ${_short(referral.id)}'),
      ReportField('Situação atual', referral.status.label),
      ReportField('Profissional responsável', referral.assignedPsychologistName ?? 'Não definido'),
    ],
    responsible: ReportResponsible(
      name: ubsDirector.name ?? ubsDirector.email,
      roleLabel: roleLabelOf(ubsDirector),
      institution: names[referral.destinationInstitutionId],
    ),
    groups: [
      ReportCandidateGroup(key: 'timeline', heading: 'Histórico do encaminhamento', items: _events(timeline)),
      if (details != null)
        ReportCandidateGroup(
          key: 'details',
          heading: 'Motivo e resumo mínimo recebidos',
          items: [
            ReportCandidate(
              id: 'details:${referral.id}',
              title: 'Enviado pela Direção escolar',
              date: referral.createdAt,
              body: 'Motivo: ${details.reason}\n\nResumo: ${details.summary}',
            ),
          ],
        ),
    ],
    notice: 'Documento administrativo: não inclui devolutivas nem notas de atendimento.',
  );
}

/// R-05: família. Só o que ela já vê no app: situação, histórico
/// administrativo, encaminhamentos e devolutivas destinadas à família.
Future<ReportSource> loadFamilySource({
  required AppUser family,
  required StudentCase value,
  required FamilyRepository repository,
}) async {
  final timeline = await _first(repository.watchTimeline(value.id));
  final referrals = (await _first(repository.watchReferrals(value.studentId)))
      .where((r) => r.caseId == value.id)
      .toList();
  final returns = (await _first(repository.watchReturns(value.studentId)))
      .where((h) => h.caseId == value.id && h.audience.contains('family'))
      .toList();
  final student = await repository.student(value.studentId);
  final names = await repository.institutionNames(
      [value.schoolInstitutionId, ...referrals.map((r) => r.destinationInstitutionId)]);
  return ReportSource(
    kind: ReportKind.family,
    caseId: value.id,
    subtitle: 'Informações do acompanhamento disponíveis para a família',
    identification: [
      ReportField('Estudante', value.studentName),
      ReportField('Turma', student?.grade ?? 'Não informada'),
      ReportField('Escola', names[value.schoolInstitutionId] ?? 'Escola'),
      ReportField('Situação atual', value.status.label),
    ],
    responsible: ReportResponsible(
      name: family.name ?? family.email,
      roleLabel: roleLabelOf(family),
    ),
    groups: [
      ReportCandidateGroup(key: 'timeline', heading: 'Histórico do acompanhamento', items: _events(timeline)),
      ReportCandidateGroup(key: 'referrals', heading: 'Encaminhamentos', items: _referrals(referrals, names)),
      ReportCandidateGroup(
        key: 'returns',
        heading: 'Devolutivas destinadas à família',
        items: _returns(returns),
      ),
    ],
    notice: 'Documento emitido pela família a partir das informações liberadas a ela no '
        'Caminho Azul.',
  );
}

Future<Student?> _student(StudentRepository? students, StudentCase value) async {
  if (students == null) return null;
  try {
    final list = await _first(students.watchSchoolStudents(value.schoolInstitutionId));
    for (final s in list) {
      if (s.id == value.studentId) return s;
    }
  } catch (_) {
    // Turma é opcional no documento.
  }
  return null;
}
