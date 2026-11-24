import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../screens/casos_screen.dart';
import '../screens/documentos_screen.dart';
import '../screens/estudantes_screen.dart';
import '../screens/encaminhamentos_screen.dart';
import '../screens/familia_acompanhamento_screen.dart';
import '../screens/familia_screen.dart';
import '../screens/ficha_observacao_screen.dart';
import '../screens/linha_tempo_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notificacoes_screen.dart';
import '../screens/relatorio_screen.dart';
import '../screens/saude_screen.dart';
import '../repositories/admin_repository.dart';
import '../repositories/case_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/referral_repository.dart';
import '../repositories/student_repository.dart';
import '../services/auth_service.dart';
import '../widgets/admin_route_guard.dart';
import '../widgets/app_shell.dart';
import '../widgets/authenticated_route_guard.dart';
import '../widgets/demo_only.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const dashboard = '/app';
  static const cases = '/app/casos';
  static const observation = '/app/ficha-observacao';
  static const reports = '/app/relatorios';
  static const referrals = '/app/encaminhamentos';
  static const timeline = '/app/linha-do-tempo';
  static const documents = '/app/documentos';
  static const family = '/app/familia';
  static const health = '/app/saude';
  static const admin = '/app/administracao';
  static const students = '/app/estudantes';
  static const notifications = '/app/notificacoes';
}

abstract final class AppRouter {
  static Route<dynamic> generateRoute(
    RouteSettings settings, {
    AuthService? authService,
    AdminRepository? adminRepository,
    StudentRepository? studentRepository,
    CaseRepository? caseRepository,
    ReferralRepository? referralRepository,
    FamilyRepository? familyRepository,
    NotificationRepository? notificationRepository,
  }) {
    final effectiveAuthService = authService ?? FirebaseAuthService();
    // Com a autenticação real, a central de notificações usa o Firestore real;
    // testes de widget injetam o próprio repositório (ou ficam sem o ícone).
    final notifications = notificationRepository ??
        (authService == null ? FirebaseNotificationRepository() : null);

    if (settings.name == AppRoutes.login) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LoginScreen(authService: effectiveAuthService),
      );
    }

    if (settings.name == AppRoutes.admin) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AdminRouteGuard(
          authService: effectiveAuthService,
          builder: (_, user) => AdminScreen(
            user: user,
            authService: effectiveAuthService,
            repository: adminRepository,
          ),
        ),
      );
    }

    if (settings.name == AppRoutes.notifications) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AuthenticatedRouteGuard(
          authService: effectiveAuthService,
          currentRoute: AppRoutes.notifications,
          allowedRoles: _allowedRoles(AppRoutes.notifications),
          notificationRepository: notifications,
          builder: (_, user) => user.role == UserRole.family
              ? NotificacoesScreen(
                  user: user,
                  repository: notifications,
                  familyRepository: familyRepository,
                )
              : const DemoOnly(title: 'Notificações', child: SizedBox.shrink()),
        ),
      );
    }

    if (settings.name == AppRoutes.students) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AuthenticatedRouteGuard(
          authService: effectiveAuthService,
          currentRoute: AppRoutes.students,
          allowedRoles: const {UserRole.school},
          builder: (_, user) =>
              EstudantesScreen(user: user, repository: studentRepository),
        ),
      );
    }

    if (settings.name == AppRoutes.dashboard ||
        settings.name == AppRoutes.cases ||
        settings.name == null) {
      final route = settings.name ?? AppRoutes.dashboard;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AuthenticatedRouteGuard(
          authService: effectiveAuthService,
          currentRoute: route,
          allowedRoles: _allowedRoles(route),
          builder: (_, user) => user.role == UserRole.school
              ? CasosScreen(
                  user: user,
                  caseRepository: caseRepository,
                  studentRepository: studentRepository,
                  referralRepository: referralRepository,
                )
              : const DemoOnly(title: 'Casos', child: SizedBox.shrink()),
        ),
      );
    }

    if (settings.name == AppRoutes.health ||
        settings.name == AppRoutes.referrals ||
        settings.name == AppRoutes.family) {
      final route = settings.name!;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AuthenticatedRouteGuard(
          authService: effectiveAuthService,
          currentRoute: route,
          allowedRoles: _allowedRoles(route),
          notificationRepository: notifications,
          builder: (_, user) => switch (user.role) {
            UserRole.health => EncaminhamentosScreen(
                user: user,
                repository: referralRepository,
                caseRepository: caseRepository,
              ),
            UserRole.family => FamiliaAcompanhamentoScreen(
                user: user,
                repository: familyRepository,
                focusCaseId: settings.arguments is FamilyRouteArguments
                    ? (settings.arguments as FamilyRouteArguments).caseId
                    : null,
              ),
            // Admin não acessa conteúdo de casos (D-11).
            _ => DemoOnly(
                title: route == AppRoutes.family
                    ? 'Acompanhamento familiar'
                    : 'Encaminhamentos',
                child: route == AppRoutes.family
                    ? const FamiliaScreen()
                    : const SaudeScreen(),
              ),
          },
        ),
      );
    }

    // P0-05: telas ainda baseadas em MockData só exibem dados no modo
    // demonstração; cada tarefa P1 substitui o protótipo pela tela real.
    final child = switch (settings.name) {
      AppRoutes.observation => const DemoOnly(
          title: 'Ficha de observação', child: FichaObservacaoScreen()),
      AppRoutes.reports =>
        const DemoOnly(title: 'Relatórios', child: RelatorioScreen()),
      AppRoutes.referrals || AppRoutes.health =>
        const DemoOnly(title: 'Encaminhamentos', child: SaudeScreen()),
      AppRoutes.timeline =>
        const DemoOnly(title: 'Linha do tempo', child: LinhaTempoScreen()),
      AppRoutes.documents =>
        const DemoOnly(title: 'Documentos', child: DocumentosScreen()),
      AppRoutes.family =>
        const DemoOnly(title: 'Acompanhamento familiar', child: FamiliaScreen()),
      _ => const DemoOnly(title: 'Casos', child: SizedBox.shrink()),
    };

    final route = settings.name ?? AppRoutes.dashboard;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => AuthenticatedRouteGuard(
        authService: effectiveAuthService,
        currentRoute: route,
        allowedRoles: _allowedRoles(route),
        child: child,
      ),
    );
  }

  /// Fora do modo demonstração cada perfil só acessa as áreas reais
  /// (`AppShell.implementedRoutes`); o admin usa só o painel (D-11). O guard
  /// devolve quem não tem acesso à própria área inicial (D-A00, D-A05).
  static Set<UserRole> _allowedRoles(String route) {
    if (!demoMode) {
      return {
        for (final entry in AppShell.implementedRoutes.entries)
          if (entry.value.contains(route) ||
              (route == AppRoutes.dashboard && entry.key == UserRole.school))
            entry.key,
      };
    }
    return switch (route) {
      AppRoutes.family ||
      AppRoutes.notifications =>
        {UserRole.family, UserRole.administration},
      AppRoutes.health || AppRoutes.referrals => {
          UserRole.health,
          UserRole.administration,
        },
      AppRoutes.timeline || AppRoutes.documents => UserRole.values.toSet(),
      _ => {UserRole.school, UserRole.administration},
    };
  }
}
