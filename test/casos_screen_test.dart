import 'dart:async';

import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/models/student_models.dart';
import 'package:caminho_azul/repositories/case_repository.dart';
import 'package:caminho_azul/repositories/student_repository.dart';
import 'package:caminho_azul/screens/casos_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/empty_referral_repository.dart';

class FakeCaseRepository implements CaseRepository {
  final cases = <StudentCase>[];
  final events = <String, List<TimelineEvent>>{};
  final _changes = StreamController<void>.broadcast();

  StudentCase _build(String id, Student s, AppUser t, CaseStatus status) =>
      StudentCase(
        id: id,
        studentId: s.id,
        studentName: s.name,
        schoolInstitutionId: s.schoolInstitutionId,
        primaryTeacherUid: t.uid,
        teacherUids: [t.uid],
        status: status,
        familyVisible: false,
        complementOpen: false,
        activeReferrals: const {},
        lastEventId: 'e',
      );

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  void _event(String caseId, String type, AppUser actor) {
    events.putIfAbsent(caseId, () => []).insert(
        0,
        TimelineEvent(
          id: 'ev${events[caseId]!.length}',
          type: type,
          visibility: TimelineEventType.visibilityOf(type),
          actorName: actor.name ?? '',
          actorRole: actorRoleOf(actor),
        ));
  }

  @override
  Stream<List<StudentCase>> watchTeacherCases(AppUser teacher, String schoolId,
          {int limit = 30}) =>
      _watch(() => cases.where((c) => c.teacherUids.contains(teacher.uid)).toList());

  @override
  Stream<List<StudentCase>> watchSchoolCases(String schoolId, {int limit = 30}) =>
      _watch(() => List.of(cases));

  @override
  Stream<StudentCase?> watchCase(String caseId) =>
      _watch(() => cases.where((c) => c.id == caseId).firstOrNull);

  @override
  Stream<List<TimelineEvent>> watchSchoolTimeline(String caseId) =>
      _watch(() => List.of(events[caseId] ?? const []));

  @override
  Future<String> createCase(AppUser teacher, Student student) async {
    final id = 'c${cases.length + 1}';
    cases.add(_build(id, student, teacher, CaseStatus.draft));
    _event(id, TimelineEventType.caseCreated, teacher);
    _changes.add(null);
    return id;
  }

  @override
  Future<void> submitCase(AppUser teacher, StudentCase value) async {
    final index = cases.indexWhere((c) => c.id == value.id);
    cases[index] = StudentCase(
      id: value.id,
      studentId: value.studentId,
      studentName: value.studentName,
      schoolInstitutionId: value.schoolInstitutionId,
      primaryTeacherUid: value.primaryTeacherUid,
      teacherUids: value.teacherUids,
      status: CaseStatus.awaitingReview,
      familyVisible: false,
      complementOpen: false,
      activeReferrals: const {},
      lastEventId: 'e2',
    );
    _event(value.id, TimelineEventType.caseSubmitted, teacher);
    _changes.add(null);
  }

  final observations = <String, List<Observation>>{};
  final records = <String, List<PedagogicalRecord>>{};

  @override
  Stream<List<Observation>> watchObservations(String caseId) =>
      _watch(() => List.of(observations[caseId] ?? const []));

  @override
  Future<void> addObservation(AppUser teacher, StudentCase value,
      {required String context,
      required String description,
      required DateTime observedAt}) async {
    final list = observations.putIfAbsent(value.id, () => []);
    list.add(Observation(
      id: 'o${list.length + 1}',
      authorUid: teacher.uid,
      authorName: teacher.name ?? '',
      context: context,
      description: description,
      observedAt: observedAt,
    ));
    _event(value.id, TimelineEventType.observationCreated, teacher);
    _changes.add(null);
  }

  @override
  Stream<List<PedagogicalRecord>> watchRecords(String caseId) =>
      _watch(() => List.of(records[caseId] ?? const []));

  @override
  Future<void> addRecord(AppUser teacher, StudentCase value,
      {required String summary,
      required List<String> actions,
      required List<String> observationIds}) async {
    final list = records.putIfAbsent(value.id, () => []);
    list.add(PedagogicalRecord(
      id: 'r${list.length + 1}',
      authorUid: teacher.uid,
      authorName: teacher.name ?? '',
      summary: summary,
      actions: actions.where((a) => a.trim().isNotEmpty).toList(),
      observationIds: observationIds,
    ));
    _event(value.id, TimelineEventType.pedagogicalRecordCreated, teacher);
    _changes.add(null);
  }

  var staff = const <StaffOption>[];

  @override
  Future<List<StaffOption>> teachersOf(String schoolId) async => staff;

  @override
  Future<void> updateTeachers(AppUser director, StudentCase value,
      {required List<String> teacherUids,
      required String primaryTeacherUid}) async {
    final index = cases.indexWhere((c) => c.id == value.id);
    cases[index] = StudentCase(
      id: value.id,
      studentId: value.studentId,
      studentName: value.studentName,
      schoolInstitutionId: value.schoolInstitutionId,
      primaryTeacherUid: primaryTeacherUid,
      teacherUids: teacherUids,
      status: value.status,
      familyVisible: value.familyVisible,
      complementOpen: value.complementOpen,
      activeReferrals: value.activeReferrals,
      lastEventId: 'e-t',
    );
    _event(value.id, TimelineEventType.caseTeachersUpdated, director);
    _changes.add(null);
  }
}

/// Um encaminhamento com devolutiva destinada à escola.
class SchoolReturnReferralRepository extends EmptyReferralRepository {
  String? queriedCaseId;

  @override
  Stream<List<Referral>> watchSchoolCaseReferrals(String caseId, String schoolId) =>
      Stream.value([
        Referral(
          id: 'r1',
          caseId: caseId,
          studentId: 'st1',
          studentName: 'Estudante Sintético',
          originInstitutionId: 'escola-a',
          destinationInstitutionId: 'ubs-a',
          status: ReferralStatus.returnRegistered,
          assignedPsychologistName: 'Psicóloga Sintética',
          lastEventId: 'e',
        ),
      ]);

  @override
  Stream<List<HealthReturn>> watchReturnsForReferral(String referralId,
      {String? audience, String? caseId}) {
    queriedCaseId = caseId;
    return Stream.value(const [
      HealthReturn(
          id: 'h1',
          referralId: 'r1',
          caseId: 'c1',
          studentId: 'st1',
          audience: ['school'],
          content: 'Orientação sintética para a escola.',
          authorName: 'Psicóloga Sintética'),
    ]);
  }
}

class StaticStudentRepository implements StudentRepository {
  @override
  Stream<List<Student>> watchSchoolStudents(String schoolInstitutionId, {int limit = 30}) =>
      Stream.value(const [
        Student(
            id: 'st1',
            name: 'Estudante Sintético',
            schoolInstitutionId: 'escola-a',
            active: true),
      ]);
  @override
  Future<Map<String, String>> institutionNames(List<String> ids) async => {};
  @override
  Future<void> createStudent({
    required String schoolInstitutionId,
    required String name,
    required String actorUid,
    String? grade,
  }) async {}
  @override
  Future<void> updateStudent(Student student,
      {required String name,
      required bool active,
      required String actorUid,
      String? grade}) async {}
}

AppUser _school(SchoolRole role) => AppUser(
      uid: role == SchoolRole.teacher ? 'prof' : 'dir',
      email: 'x@caminhoazul.test',
      name: role == SchoolRole.teacher ? 'Professor Sintético' : 'Diretora',
      role: UserRole.school,
      schoolRole: role,
      professionalId: 'p',
      institutionIds: const ['escola-a'],
    );

void main() {
  testWidgets('professor abre caso para estudante cadastrado e envia à Direção',
      (tester) async {
    final cases = FakeCaseRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.teacher),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cases-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cases-new-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-student-st1')));
    await tester.pumpAndSettle();

    // Detalhe aberto com o caso em registro inicial e o evento de criação.
    expect(find.byKey(const Key('case-detail-student')), findsOneWidget);
    expect(find.text('Registro inicial'), findsOneWidget);
    expect(find.text('Caso registrado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('case-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Aguardando análise da Direção'), findsOneWidget);
    expect(find.text('Caso enviado à Direção escolar'), findsOneWidget);
    expect(find.text('Caso registrado'), findsOneWidget);
    expect(find.byKey(const Key('case-submit-button')), findsNothing);
  });

  testWidgets('Direção vê os casos da escola e não abre casos', (tester) async {
    final cases = FakeCaseRepository();
    await cases.createCase(
        _school(SchoolRole.teacher),
        const Student(
            id: 'st1',
            name: 'Estudante Sintético',
            schoolInstitutionId: 'escola-a',
            active: true));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.director),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cases-new-button')), findsNothing);
    expect(find.text('Estudante Sintético'), findsOneWidget);
  });

  testWidgets('professor registra observação e registro pedagógico no caso',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cases = FakeCaseRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.teacher),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cases-new-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-student-st1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('case-add-observation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório.'), findsWidgets);
    await tester.enterText(find.byKey(const Key('observation-context')), 'Recreio');
    await tester.enterText(find.byKey(const Key('observation-description')),
        'Permaneceu isolado durante a atividade coletiva.');
    await tester.tap(find.byKey(const Key('case-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Observação registrada.'), findsOneWidget);
    expect(find.text('Permaneceu isolado durante a atividade coletiva.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('case-add-record')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-summary')),
        'Necessita de apoio em transições.');
    await tester.enterText(
        find.byKey(const Key('record-actions')), 'Antecipar rotina\nAgenda visual');
    await tester.tap(find.byKey(const Key('record-observation-o1')));
    await tester.tap(find.byKey(const Key('case-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Registro pedagógico salvo.'), findsOneWidget);
    expect(find.text('• Agenda visual'), findsOneWidget);
    expect(cases.records.values.single.single.observationIds, ['o1']);
    expect(find.text('Observação pedagógica registrada'), findsOneWidget);
  });

  testWidgets('Direção vincula outro professor e define o principal (P1-02)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cases = FakeCaseRepository()
      ..staff = const [
        StaffOption(uid: 'prof', name: 'Professor Sintético'),
        StaffOption(uid: 'prof2', name: 'Professora Dois'),
      ];
    await cases.createCase(
        _school(SchoolRole.teacher),
        const Student(
            id: 'st1',
            name: 'Estudante Sintético',
            schoolInstitutionId: 'escola-a',
            active: true));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.director),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estudante Sintético'));
    await tester.pumpAndSettle();
    expect(find.text('Professor Sintético (principal)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('case-teachers-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-teacher-prof2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-teacher-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Professora Dois').last);
    await tester.pumpAndSettle();
    // Desvincula o professor original: só a nova professora permanece.
    await tester.tap(find.byKey(const Key('case-teacher-prof')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-teachers-save')));
    await tester.pumpAndSettle();

    expect(cases.cases.single.teacherUids, ['prof2']);
    expect(cases.cases.single.primaryTeacherUid, 'prof2');
    expect(find.text('Professores do caso atualizados.'), findsOneWidget);
    expect(find.text('Professora Dois (principal)'), findsOneWidget);
    expect(find.text('Professores vinculados atualizados'), findsOneWidget);
  });

  testWidgets('professor vê os vinculados, sem alterar', (tester) async {
    final cases = FakeCaseRepository()
      ..staff = const [StaffOption(uid: 'prof', name: 'Professor Sintético')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.teacher),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cases-new-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-student-st1')));
    await tester.pumpAndSettle();
    expect(find.text('Professor Sintético (principal)'), findsOneWidget);
    expect(find.byKey(const Key('case-teachers-edit')), findsNothing);
  });

  testWidgets('professor vinculado vê a devolutiva destinada à escola (P1-09)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cases = FakeCaseRepository();
    final referrals = SchoolReturnReferralRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: _school(SchoolRole.teacher),
          caseRepository: cases,
          studentRepository: StaticStudentRepository(),
          referralRepository: referrals,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cases-new-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-student-st1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Orientação sintética para a escola.'), findsOneWidget);
    // A consulta leva o caso, como exige a regra do professor.
    expect(referrals.queriedCaseId, 'c1');
  });
}
