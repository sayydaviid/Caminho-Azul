// P2-12 — listas paginadas: a consulta usa limit e a tela pede mais páginas.
import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/screens/casos_screen.dart';
import 'package:caminho_azul/screens/encaminhamentos_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:caminho_azul/widgets/load_more.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/empty_referral_repository.dart';
import 'widget_test.dart' show EmptyCaseRepository, EmptyStudentRepository;

StudentCase _case(int i) => StudentCase(
      id: 'c$i',
      studentId: 's$i',
      studentName: 'Estudante Sintético $i',
      schoolInstitutionId: 'escola-a',
      primaryTeacherUid: 'prof',
      teacherUids: const ['prof'],
      status: CaseStatus.draft,
      familyVisible: false,
      complementOpen: false,
      activeReferrals: const {},
      lastEventId: 'e',
    );

class _PagedCases extends EmptyCaseRepository {
  _PagedCases(this.total);
  final int total;
  final limits = <int>[];

  @override
  Stream<List<StudentCase>> watchTeacherCases(AppUser teacher, String schoolId,
      {int limit = 30}) {
    limits.add(limit);
    return Stream.value([for (var i = 0; i < total && i < limit; i++) _case(i)]);
  }
}

class _PagedReferrals extends EmptyReferralRepository {
  _PagedReferrals(this.total);
  final int total;
  final limits = <int>[];

  @override
  Stream<List<Referral>> watchPsychologistReferrals(String uid, {int limit = 30}) {
    limits.add(limit);
    return Stream.value([
      for (var i = 0; i < total && i < limit; i++)
        Referral(
          id: 'r$i',
          caseId: 'c$i',
          studentId: 's$i',
          studentName: 'Estudante Sintético $i',
          originInstitutionId: 'escola-a',
          destinationInstitutionId: 'ubs-a',
          status: ReferralStatus.assigned,
          lastEventId: 'e',
        ),
    ]);
  }
}

Future<void> _loadMore(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('casos: página de 30 e "Carregar mais" pede a próxima', (tester) async {
    final repository = _PagedCases(45);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CasosScreen(
          user: const AppUser(
            uid: 'prof',
            email: 'prof@caminhoazul.test',
            role: UserRole.school,
            schoolRole: SchoolRole.teacher,
            institutionIds: ['escola-a'],
          ),
          caseRepository: repository,
          studentRepository: EmptyStudentRepository(),
          referralRepository: EmptyReferralRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(repository.limits, [listPageSize]);
    await _loadMore(tester, 'cases-load-more');
    expect(repository.limits.last, listPageSize * 2);
    // 45 < 60: última página, sem botão.
    expect(find.byKey(const Key('cases-load-more')), findsNothing);
  });

  testWidgets('encaminhamentos: lista do psicólogo paginada', (tester) async {
    final repository = _PagedReferrals(31);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EncaminhamentosScreen(
          user: const AppUser(
            uid: 'psi',
            email: 'psi@caminhoazul.test',
            role: UserRole.health,
            healthRole: HealthRole.psychologist,
            institutionIds: ['ubs-a'],
          ),
          repository: repository,
          caseRepository: EmptyCaseRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(repository.limits, [listPageSize]);
    await _loadMore(tester, 'referrals-load-more');
    expect(repository.limits.last, listPageSize * 2);
  });
}
