import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/models/student_models.dart';
import 'package:caminho_azul/repositories/family_repository.dart';
import 'package:caminho_azul/screens/encaminhamentos_screen.dart';
import 'package:caminho_azul/screens/familia_acompanhamento_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'casos_screen_test.dart' show FakeCaseRepository;
import 'support/empty_referral_repository.dart';

const _referral = Referral(
  id: 'r1',
  caseId: 'c1',
  studentId: 's1',
  studentName: 'Estudante Sintético',
  originInstitutionId: 'escola-a',
  destinationInstitutionId: 'ubs-a',
  status: ReferralStatus.sent,
  lastEventId: 'e1',
);

class RecordingReferralRepository extends EmptyReferralRepository {
  RecordingReferralRepository(this.current);
  Referral current;
  final calls = <String>[];

  @override
  Stream<List<Referral>> watchUbsReferrals(String ubsId, {int limit = 30}) => Stream.value([current]);
  @override
  Stream<List<Referral>> watchPsychologistReferrals(String uid, {int limit = 30}) =>
      Stream.value([current]);
  @override
  Stream<Referral?> watchReferral(String referralId) => Stream.value(current);
  @override
  Future<ReferralDetails?> getDetails(String referralId) async =>
      const ReferralDetails(reason: 'Motivo sintético', summary: 'Resumo mínimo');
  @override
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async =>
      {for (final id in ids) id: 'Escola Sintética'};
  @override
  Future<void> receive(AppUser ubsDirector, Referral referral) async =>
      calls.add('receive');
  @override
  Future<void> refuse(AppUser ubsDirector, Referral referral, String text) async =>
      calls.add('refuse:$text');
  @override
  Future<void> startAttendance(AppUser psychologist, Referral referral) async =>
      calls.add('start');
  @override
  Future<void> registerReturn(AppUser psychologist, Referral referral,
          {required String content, required List<String> audience}) async =>
      calls.add('return:${audience.join(',')}');
}

AppUser _health(HealthRole role) => AppUser(
      uid: role == HealthRole.ubsDirector ? 'dir-ubs' : 'psi',
      email: 'x@caminhoazul.test',
      name: 'Pessoa Sintética',
      role: UserRole.health,
      healthRole: role,
      professionalId: 'p',
      institutionIds: const ['ubs-a'],
    );

class FakeFamilyRepository implements FamilyRepository {
  @override
  Future<Student?> student(String studentId) async => const Student(
      id: 's1', name: 'Estudante Sintético', schoolInstitutionId: 'escola-a', active: true);
  @override
  Stream<List<StudentCase>> watchCases(String studentId) => Stream.value(const [
        StudentCase(
          id: 'c1',
          studentId: 's1',
          studentName: 'Estudante Sintético',
          schoolInstitutionId: 'escola-a',
          primaryTeacherUid: 't',
          teacherUids: ['t'],
          status: CaseStatus.inFollowUp,
          familyVisible: true,
          complementOpen: false,
          activeReferrals: {'r1': 'ubs-a'},
          lastEventId: 'e',
        ),
      ]);
  @override
  Stream<List<TimelineEvent>> watchTimeline(String caseId) => Stream.value(const [
        TimelineEvent(
            id: 'e2',
            type: TimelineEventType.referralAssigned,
            visibility: 'familia',
            actorName: 'Diretor UBS',
            actorRole: 'health/ubs_director'),
        TimelineEvent(
            id: 'e1',
            type: TimelineEventType.caseCreated,
            visibility: 'familia',
            actorName: 'Professor',
            actorRole: 'school/teacher'),
      ]);
  @override
  Stream<List<Referral>> watchReferrals(String studentId) => Stream.value(const [
        Referral(
          id: 'r1',
          caseId: 'c1',
          studentId: 's1',
          studentName: 'Estudante Sintético',
          originInstitutionId: 'escola-a',
          destinationInstitutionId: 'ubs-a',
          status: ReferralStatus.assigned,
          assignedPsychologistName: 'Psicóloga Sintética',
          lastEventId: 'e2',
        ),
      ]);
  @override
  Stream<List<HealthReturn>> watchReturns(String studentId) => Stream.value(const [
        HealthReturn(
            id: 'h1',
            referralId: 'r1',
            caseId: 'c1',
            studentId: 's1',
            audience: ['family'],
            content: 'Orientação sintética para a família.',
            authorName: 'Psicóloga Sintética'),
      ]);
  @override
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async =>
      {for (final id in ids) id: 'UBS Sintética'};
}

/// Leitura negada/indisponível nas seções de encaminhamentos e devolutivas.
class FailingSectionsFamilyRepository extends FakeFamilyRepository {
  @override
  Stream<List<Referral>> watchReferrals(String studentId) =>
      Stream.error(StateError('permission-denied'));
  @override
  Stream<List<HealthReturn>> watchReturns(String studentId) =>
      Stream.error(StateError('unavailable'));
}

void main() {
  testWidgets('Direção da UBS registra recebimento e recusa com justificativa',
      (tester) async {
    final repo = RecordingReferralRepository(_referral);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncaminhamentosScreen(
          user: _health(HealthRole.ubsDirector),
          repository: repo,
          caseRepository: FakeCaseRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recebidos pela unidade de saúde'), findsOneWidget);
    await tester.tap(find.byKey(const Key('referral-tile-r1')));
    await tester.pumpAndSettle();
    expect(find.text('Resumo mínimo'), findsOneWidget);
    expect(find.byKey(const Key('referral-health-return')), findsNothing);

    await tester.tap(find.byKey(const Key('referral-receive')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['receive']);

    await tester.tap(find.byKey(const Key('referral-refuse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ask-text-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ask-text-field')), 'Fora da área.');
    await tester.tap(find.byKey(const Key('ask-text-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'refuse:Fora da área.');
  });

  testWidgets('psicólogo inicia atendimento e registra devolutiva por audiência',
      (tester) async {
    final repo = RecordingReferralRepository(const Referral(
      id: 'r1',
      caseId: 'c1',
      studentId: 's1',
      studentName: 'Estudante Sintético',
      originInstitutionId: 'escola-a',
      destinationInstitutionId: 'ubs-a',
      status: ReferralStatus.assigned,
      assignedPsychologistUid: 'psi',
      assignedPsychologistName: 'Pessoa Sintética',
      lastEventId: 'e1',
    ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncaminhamentosScreen(
          user: _health(HealthRole.psychologist),
          repository: repo,
          caseRepository: FakeCaseRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('referral-tile-r1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('referral-receive')), findsNothing);
    await tester.tap(find.byKey(const Key('referral-start')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['start']);

    await tester.tap(find.byKey(const Key('referral-health-return')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('health-return-content')), 'Orientações sintéticas.');
    await tester.tap(find.byKey(const Key('health-return-family')));
    await tester.tap(find.byKey(const Key('health-return-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'return:school,family');
  });

  testWidgets('família só consulta: status, linha do tempo, encaminhamento e devolutiva',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamiliaAcompanhamentoScreen(
          user: const AppUser(
            uid: 'fam',
            email: 'f@caminhoazul.test',
            role: UserRole.family,
            studentIds: ['s1'],
          ),
          repository: FakeFamilyRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Em acompanhamento'), findsOneWidget);
    expect(find.text('Caso registrado'), findsOneWidget);
    expect(find.text('Profissional responsável atribuído'), findsOneWidget);
    expect(find.text('Profissional responsável: Psicóloga Sintética'), findsOneWidget);
    expect(find.text('Orientação sintética para a família.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('família: falha de leitura aparece como erro, não como vazio (P1-11)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamiliaAcompanhamentoScreen(
          user: const AppUser(
            uid: 'fam',
            email: 'f@caminhoazul.test',
            role: UserRole.family,
            studentIds: ['s1'],
          ),
          repository: FailingSectionsFamilyRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Em acompanhamento'), findsOneWidget);
    expect(find.text('Não foi possível carregar os encaminhamentos.'),
        findsOneWidget);
    expect(find.text('Não foi possível carregar as devolutivas.'), findsOneWidget);
  });
}
