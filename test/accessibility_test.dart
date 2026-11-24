// P2-03 — auditoria automatizada de acessibilidade nas telas reais (com
// fakes): alvos de toque com rótulo, tamanho mínimo (48 dp no Android) e
// contraste de texto (WCAG AA), incluindo notificações e geração de PDF.
import 'package:caminho_azul/app/router.dart';
import 'package:caminho_azul/app/theme.dart';
import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/reports/report_models.dart';
import 'package:caminho_azul/screens/gerar_relatorio_screen.dart';
import 'package:caminho_azul/screens/login_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notifications_test.dart' show FakeNotificationRepository, notification;
import 'referral_family_screens_test.dart' show FakeFamilyRepository;
import 'reports_test.dart' as reports;
import 'support/empty_referral_repository.dart';
import 'widget_test.dart'
    show EmptyCaseRepository, EmptyStudentRepository, FakeAdminRepository, FakeAuthService;

const _family = AppUser(
  uid: 'fam',
  email: 'familia@caminhoazul.test',
  name: 'Família Sintética',
  role: UserRole.family,
  studentIds: ['s1'],
);

Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Widget _routed(String route, AppUser user) => MaterialApp(
      theme: AppTheme.light,
      initialRoute: route,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings,
        authService: FakeAuthService(appUser: user),
        familyRepository: FakeFamilyRepository(),
        notificationRepository: FakeNotificationRepository([
          notification('e2', TimelineEventType.healthReturnCreated, referralId: 'r1', minute: 2),
          notification('e1', TimelineEventType.caseApproved, read: true, minute: 1),
        ]),
        caseRepository: EmptyCaseRepository(),
        studentRepository: EmptyStudentRepository(),
        referralRepository: EmptyReferralRepository(),
        adminRepository: FakeAdminRepository(),
      ),
    );

void main() {
  testWidgets('login', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(authService: FakeAuthService()),
    ));
    await tester.pumpAndSettle();
    await _meetsGuidelines(tester);
    handle.dispose();
  });

  testWidgets('família: acompanhamento', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_routed(AppRoutes.family, _family));
    await tester.pumpAndSettle();
    await _meetsGuidelines(tester);
    handle.dispose();
  });

  testWidgets('família: central de notificações', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_routed(AppRoutes.notifications, _family));
    await tester.pumpAndSettle();
    await _meetsGuidelines(tester);
    // O item é anunciado como botão com estado de leitura e conteúdo.
    expect(
      find.bySemanticsLabel(RegExp(r'^Não lida\. Nova devolutiva\.')),
      findsOneWidget,
    );
    expect(find.byTooltip('Notificações, 1 não lida'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('geração de PDF: seleção de registros', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: GerarRelatorioScreen(
        user: _family,
        kind: ReportKind.pedagogical,
        loadSource: () async => reports.sampleSource(),
        exportLog: reports.FakeLog(),
        output: reports.FakeOutput(),
      ),
    ));
    await tester.pumpAndSettle();
    await _meetsGuidelines(tester);
    handle.dispose();
  });

  for (final (name, route, user) in [
    (
      'escola: casos (professor)',
      AppRoutes.cases,
      const AppUser(
          uid: 'p', email: 'p@caminhoazul.test', name: 'Professora', role: UserRole.school,
          schoolRole: SchoolRole.teacher, institutionIds: ['escola-a'])
    ),
    (
      'escola: estudantes (Direção)',
      AppRoutes.students,
      const AppUser(
          uid: 'd', email: 'd@caminhoazul.test', name: 'Direção', role: UserRole.school,
          schoolRole: SchoolRole.director, institutionIds: ['escola-a'])
    ),
    (
      'saúde: encaminhamentos (Direção UBS)',
      AppRoutes.health,
      const AppUser(
          uid: 'u', email: 'u@caminhoazul.test', name: 'Direção UBS', role: UserRole.health,
          healthRole: HealthRole.ubsDirector, institutionIds: ['ubs-a'])
    ),
  ]) {
    testWidgets(name, (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_routed(route, user));
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      handle.dispose();
    });
  }
}
