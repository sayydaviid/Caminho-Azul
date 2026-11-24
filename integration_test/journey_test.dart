// Jornada principal contra o Emulator Suite (projeto demo-caminhoazul), com
// os repositórios reais e as Security Rules reais. Cresce a cada tarefa P1.
// Executar com emuladores + seed recém-aplicado:
//   flutter test integration_test/journey_test.dart -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/repositories/case_repository.dart';
import 'package:caminho_azul/repositories/referral_repository.dart';
import 'package:caminho_azul/repositories/student_repository.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _password =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseCaseRepository cases;
  late FirebaseStudentRepository students;
  late FirebaseReferralRepository referrals;

  setUpAll(() async {
    if (!useFirebaseEmulators) {
      fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    }
    await Firebase.initializeApp(
      options: firebaseOptionsFor(
        DefaultFirebaseOptions.currentPlatform,
        useEmulators: true,
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    cases = FirebaseCaseRepository();
    students = FirebaseStudentRepository();
    referrals = FirebaseReferralRepository(cases: cases);
  });

  Future<AppUser> signInAs(String email) async {
    await FirebaseAuthService().signOut();
    return FirebaseAuthService().signIn(email: email, password: _password);
  }

  Matcher denied() => isA<FirebaseException>()
      .having((e) => e.code, 'code', 'permission-denied');

  testWidgets('P1-01/P1-03/P1-04: caso, observação e registro; isolamento por perfil',
      (tester) async {
    // Professor seleciona o estudante cadastrado pela Direção e registra o caso.
    final teacher = await signInAs('professor@caminhoazul.test');
    final student = (await students.watchSchoolStudents('seed-escola-a').first)
        .firstWhere((s) => s.id == 'seed-estudante-2');
    final caseId = await cases.createCase(teacher, student);
    // P2-06 (RN-20): um caso em andamento por estudante.
    await expectLater(
      cases.createCase(teacher, student),
      throwsA(isA<CaseRepositoryException>().having(
          (e) => e.message, 'message', contains('já possui um caso em andamento'))),
    );

    var value = await cases.watchCase(caseId).firstWhere((c) => c != null);
    expect(value!.status, CaseStatus.draft);
    expect(value.studentId, student.id);
    expect(value.teacherUids, [teacher.uid]);
    expect(value.familyVisible, isFalse);
    var events = await cases.watchSchoolTimeline(caseId).first;
    expect(events.map((e) => e.type), [TimelineEventType.caseCreated]);
    expect(events.single.actorName, teacher.name);

    final mine = await cases.watchTeacherCases(teacher, 'seed-escola-a').first;
    expect(mine.any((c) => c.id == caseId), isTrue);

    // P1-03 / P1-04: observação e registro pedagógico internos.
    await cases.addObservation(teacher, value,
        context: 'Sala de aula',
        description: 'Evitou contato visual durante a leitura coletiva.',
        observedAt: DateTime(2026, 11, 20));
    final observations = await cases.watchObservations(caseId).first;
    expect(observations, hasLength(1));
    expect(observations.single.authorUid, teacher.uid);
    await cases.addRecord(teacher, value,
        summary: 'Necessita de apoio nas transições entre atividades.',
        actions: ['Antecipar rotina', 'Agenda visual'],
        observationIds: [observations.single.id]);
    final records = await cases.watchRecords(caseId).first;
    expect(records.single.observationIds, [observations.single.id]);
    events = await cases.watchSchoolTimeline(caseId).first;
    expect(events.where((e) => e.visibility == 'interno'), hasLength(2));

    await cases.submitCase(teacher, value);
    value = await cases
        .watchCase(caseId)
        .firstWhere((c) => c?.status == CaseStatus.awaitingReview);
    events = await cases.watchSchoolTimeline(caseId).first;
    expect(events.first.type, TimelineEventType.caseSubmitted);
    // Professor não aprova (regras).
    await expectLater(
      cases.transition(teacher, value!, {
        'status': CaseStatus.approved.value,
        'familyVisible': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': teacher.uid,
      }, TimelineEventType.caseApproved),
      throwsA(denied()),
    );

    // Fora do estado editável o professor não registra mais.
    await expectLater(
      cases.addObservation(teacher, value,
          context: 'x', description: 'y', observedAt: DateTime(2026, 11, 21)),
      throwsA(isA<CaseRepositoryException>()),
    );

    // Direção da escola vê o caso e o conteúdo pedagógico.
    await signInAs('direcao.escola@caminhoazul.test');
    final school = await cases.watchSchoolCases('seed-escola-a').first;
    expect(school.any((c) => c.id == caseId), isTrue);
    expect(await cases.watchObservations(caseId).first, hasLength(1));
    expect(await cases.watchRecords(caseId).first, hasLength(1));

    // Saúde não lê observações internas.
    await signInAs('direcao.ubs@caminhoazul.test');
    await expectLater(cases.watchObservations(caseId).first, throwsA(denied()));

    // Professor de outra escola e família (antes da aprovação): negados.
    await signInAs('professor.b@caminhoazul.test');
    await expectLater(cases.watchCase(caseId).first, throwsA(denied()));
    await signInAs('familia@caminhoazul.test');
    await expectLater(cases.watchCase(caseId).first, throwsA(denied()));

    // Admin: só metadados do caso; linha do tempo negada (D-11).
    await signInAs('admin@caminhoazul.test');
    expect((await cases.watchCase(caseId).first)?.id, caseId);
    await expectLater(cases.watchSchoolTimeline(caseId).first, throwsA(denied()));
    await expectLater(cases.watchObservations(caseId).first, throwsA(denied()));
    await expectLater(cases.watchRecords(caseId).first, throwsA(denied()));
    await FirebaseAuthService().signOut();
  });

  testWidgets('P1-05 → P1-08: análise, encaminhamento, UBS, devolutiva e família',
      (tester) async {
    final firestore = FirebaseFirestore.instance;
    Future<StudentCase> caseNow(String id, [bool Function(StudentCase c)? until]) async =>
        (await cases.watchCase(id).firstWhere((c) => c != null && (until?.call(c) ?? true)))!;
    Future<Referral> referralNow(String id, [bool Function(Referral r)? until]) async =>
        (await referrals.watchReferral(id).firstWhere((r) => r != null && (until?.call(r) ?? true)))!;

    // Professor registra e envia.
    var teacher = await signInAs('professor@caminhoazul.test');
    final student = (await students.watchSchoolStudents('seed-escola-a').first)
        .firstWhere((s) => s.id == 'seed-estudante-1');
    final caseId = await cases.createCase(teacher, student);
    await cases.addObservation(teacher, await caseNow(caseId),
        context: 'Sala de aula', description: 'Fato observável sintético.',
        observedAt: DateTime(2026, 11, 20));
    await cases.submitCase(teacher, await caseNow(caseId));

    // P1-05: Direção solicita complementação; professor complementa; Direção aprova.
    var director = await signInAs('direcao.escola@caminhoazul.test');
    await referrals.requestSchoolComplement(director, await caseNow(caseId));
    teacher = await signInAs('professor@caminhoazul.test');
    var value = await caseNow(caseId, (c) => c.status == CaseStatus.complementRequested);
    await cases.addObservation(teacher, value,
        context: 'Recreio', description: 'Complemento sintético.',
        observedAt: DateTime(2026, 11, 21));
    await cases.submitCase(teacher, value);
    director = await signInAs('direcao.escola@caminhoazul.test');
    value = await caseNow(caseId, (c) => c.status == CaseStatus.awaitingReview);
    await referrals.approve(director, value);
    value = await caseNow(caseId, (c) => c.status == CaseStatus.approved);
    expect(value.familyVisible, isTrue);

    // Encaminhamentos simultâneos para UBS A e UBS B; segundo para a mesma UBS recusado.
    final ubsList = await referrals.activeUbs();
    expect(ubsList.map((u) => u.id), containsAll(['seed-ubs-a', 'seed-ubs-b']));
    final refA = await referrals.send(director, value,
        ubsId: 'seed-ubs-a', reason: 'Motivo sintético A', summary: 'Resumo mínimo A');
    value = await caseNow(caseId, (c) => c.status == CaseStatus.referred);
    final refB = await referrals.send(director, value,
        ubsId: 'seed-ubs-b', reason: 'Motivo sintético B', summary: 'Resumo mínimo B');
    value = await caseNow(caseId, (c) => c.activeReferrals.length == 2);
    await expectLater(
        referrals.send(director, value, ubsId: 'seed-ubs-a', reason: 'x', summary: 'y'),
        throwsA(isA<ReferralRepositoryException>()));
    await expectLater(referrals.conclude(director, value),
        throwsA(isA<ReferralRepositoryException>()));
    final schoolRefs = await referrals
        .watchSchoolCaseReferrals(caseId, 'seed-escola-a').first;
    expect(schoolRefs, hasLength(2));

    // P1-16: UBS B recusa com justificativa; UBS A recebe e atribui.
    var ubsB = await signInAs('direcao.ubs.b@caminhoazul.test');
    expect((await referrals.watchUbsReferrals('seed-ubs-b').first).map((r) => r.id),
        contains(refB));
    await expectLater(referrals.watchReferral(refA).first, throwsA(denied()));
    await referrals.refuse(ubsB, await referralNow(refB), 'Fora da área de cobertura (sintético).');

    final ubsA = await signInAs('direcao.ubs@caminhoazul.test');
    final details = await referrals.getDetails(refA);
    expect(details?.summary, 'Resumo mínimo A');
    await expectLater(cases.watchObservations(caseId).first, throwsA(denied()));
    await referrals.receive(ubsA, await referralNow(refA));
    final psychologists = await referrals.psychologistsOf('seed-ubs-a');
    expect(psychologists.map((p) => p.uid),
        containsAll(['seed-psicologo', 'seed-psicologo-2']));
    final caseForUbs = await caseNow(caseId);
    await referrals.assign(
      ubsA,
      await referralNow(refA, (r) => r.status == ReferralStatus.received),
      psychologists.firstWhere((p) => p.uid == 'seed-psicologo-2'),
      caseNeedsFollowUp: caseForUbs.status == CaseStatus.referred,
    );
    // Transferência: o psicólogo 2 perde o acesso; o psicólogo 1 assume.
    await referrals.assign(
      ubsA,
      await referralNow(refA, (r) => r.status == ReferralStatus.assigned),
      psychologists.firstWhere((p) => p.uid == 'seed-psicologo'),
      caseNeedsFollowUp: false,
    );
    var ref = await referralNow(refA, (r) => r.assignedPsychologistUid == 'seed-psicologo');
    // Complementação: UBS → Direção escolar → Professor → Direção escolar → UBS (D-20).
    await referrals.requestUbsComplement(ubsA, ref, 'Informar rotina escolar (sintético).');

    await signInAs('psicologo2@caminhoazul.test');
    await expectLater(referrals.watchReferral(refA).first, throwsA(denied()));

    director = await signInAs('direcao.escola@caminhoazul.test');
    value = await caseNow(caseId, (c) => c.status == CaseStatus.inFollowUp);
    final notes = await referrals.watchNotes(refA, 'school').first;
    expect(notes.map((n) => n.kind), contains('complementRequest'));
    await referrals.forwardComplementToTeacher(director, value);
    teacher = await signInAs('professor@caminhoazul.test');
    value = await caseNow(caseId, (c) => c.complementOpen);
    await cases.addObservation(teacher, value,
        context: 'Rotina', description: 'Rotina escolar sintética.',
        observedAt: DateTime(2026, 11, 22));
    director = await signInAs('direcao.escola@caminhoazul.test');
    ref = await referralNow(refA, (r) => r.status == ReferralStatus.complementRequested);
    await referrals.answerUbsComplement(
        director, await caseNow(caseId), ref, 'Rotina: aulas pela manhã (sintético).');
    value = await caseNow(caseId, (c) => !c.complementOpen);

    // P1-06: psicólogo atende, registra atualização e devolutiva para escola e família.
    final psychologist = await signInAs('psicologo@caminhoazul.test');
    ref = await referralNow(refA, (r) => r.status == ReferralStatus.assigned);
    expect((await referrals.watchNotes(refA, 'psychologist').first).map((n) => n.kind),
        contains('complementAnswer'));
    await referrals.startAttendance(psychologist, ref);
    ref = await referralNow(refA, (r) => r.status == ReferralStatus.inAttendance);
    await referrals.addProgressNote(psychologist, ref, 'Acompanhamento iniciado (sintético).');
    await referrals.registerReturn(psychologist, ref,
        content: 'Orientações à escola e à família (sintético).',
        audience: const ['school', 'family']);
    ref = await referralNow(refA, (r) => r.status == ReferralStatus.returnRegistered);
    // Segunda devolutiva, só para a escola: evento restrito.
    await referrals.registerReturn(psychologist, ref,
        content: 'Orientação técnica só para a escola (sintético).',
        audience: const ['school']);
    ref = await referralNow(refA, (r) => r.lastEventId != ref.lastEventId);

    // UBS finaliza; Direção UBS não lê o conteúdo da devolutiva.
    final ubsA2 = await signInAs('direcao.ubs@caminhoazul.test');
    await expectLater(
        referrals.watchReturnsForReferral(refA).first, throwsA(denied()));
    final ubsTimeline = await referrals.watchReferralTimeline(caseId, refA).first;
    expect(ubsTimeline.map((e) => e.type), contains(TimelineEventType.referralAssigned));
    await referrals.finalize(ubsA2, ref);

    // P1-08: família vê o caso aprovado, o histórico completo e a devolutiva destinada a ela.
    await signInAs('familia@caminhoazul.test');
    final familyCases = await firestore
        .collection('cases')
        .where('studentId', isEqualTo: 'seed-estudante-1')
        .where('familyVisible', isEqualTo: true)
        .get();
    expect(familyCases.docs.map((d) => d.id), contains(caseId));
    final familyEvents = await firestore
        .collection('cases/$caseId/timelineEvents')
        .where('visibility', isEqualTo: 'familia')
        .get();
    final types = familyEvents.docs.map((d) => d['type'] as String).toSet();
    expect(types, containsAll([
      TimelineEventType.caseCreated, // anterior à aprovação (D-16)
      TimelineEventType.caseApproved,
      TimelineEventType.referralSent,
      TimelineEventType.referralReceived,
      TimelineEventType.referralAssigned,
      TimelineEventType.referralTransferred,
      TimelineEventType.referralRefused,
      TimelineEventType.healthReturnCreated,
      TimelineEventType.referralFinalized,
    ]));
    expect(types.contains(TimelineEventType.observationCreated), isFalse);
    expect(familyEvents.docs.where((d) => d['visibility'] != 'familia'), isEmpty);
    final familyReturns = await firestore
        .collection('healthReturns')
        .where('studentId', isEqualTo: 'seed-estudante-1')
        .where('audience', arrayContains: 'family')
        .get();
    expect(familyReturns.docs, isNotEmpty);
    await expectLater(cases.watchObservations(caseId).first, throwsA(denied()));
    await expectLater(referrals.getDetails(refA), throwsA(denied()));
    await expectLater(
      firestore.doc('cases/$caseId').update({'status': 'rascunho'}),
      throwsA(denied()),
    );

    // Direção conclui: não há mais encaminhamentos ativos.
    director = await signInAs('direcao.escola@caminhoazul.test');
    value = await caseNow(caseId, (c) => c.activeReferrals.isEmpty);
    await referrals.conclude(director, value);
    value = await caseNow(caseId, (c) => c.status == CaseStatus.concluded);
    final schoolReturns = await referrals
        .watchReturnsForReferral(refA, audience: 'school').first;
    expect(schoolReturns.map((r) => r.audienceLabel),
        containsAll(['Escola e Família', 'Escola']));
    // Linha do tempo da escola inclui o evento restrito destinado a ela.
    final schoolTimeline = await cases.watchSchoolTimeline(caseId).first;
    expect(schoolTimeline.map((e) => e.visibility).toSet(),
        containsAll(['familia', 'interno', 'restrito']));
    await FirebaseAuthService().signOut();
  });
}
