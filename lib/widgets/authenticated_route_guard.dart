import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../repositories/notification_repository.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

/// `false` quando a rota que contém [context] já saiu da navegação (por
/// exemplo, removida por `pushNamedAndRemoveUntil` na saída da conta).
bool isRouteActive(BuildContext context) =>
    ModalRoute.of(context)?.isActive ?? true;

/// Área inicial de cada perfil (sempre permitida para ele).
String homeRouteFor(UserRole role) => switch (role) {
      UserRole.administration => AppRoutes.admin,
      UserRole.school => AppRoutes.cases,
      UserRole.health => AppRoutes.health,
      UserRole.family => AppRoutes.family,
    };

class AuthenticatedRouteGuard extends StatelessWidget {
  const AuthenticatedRouteGuard({
    required this.authService,
    required this.currentRoute,
    required this.allowedRoles,
    this.child,
    this.builder,
    this.notificationRepository,
    super.key,
  }) : assert(child != null || builder != null);

  /// Central de notificações da família (ícone com contador na barra).
  final NotificationRepository? notificationRepository;

  final AuthService authService;
  final String currentRoute;
  final Widget? child;

  /// Telas reais recebem o usuário validado (instituições, subrole etc.).
  final Widget Function(BuildContext context, AppUser user)? builder;
  final Set<UserRole> allowedRoles;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authService.sessionChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // Rota já removida (ex.: saída da conta): não reage ao fim da sessão.
        if (!isRouteActive(context)) {
          return const Scaffold(backgroundColor: AppColors.background);
        }
        final user = snapshot.data;
        if (!snapshot.hasError &&
            user != null &&
            !allowedRoles.contains(user.role)) {
          // D-A12: em um link direto (ex.: #/app/notificacoes) o Flutter também
          // empilha os prefixos (/app). Uma rota por baixo da pilha não
          // redireciona: o redirecionamento substituiria a rota do topo. Se o
          // usuário voltar até ela, a rota passa a ser a atual e redireciona.
          if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
            return const Scaffold(backgroundColor: AppColors.background);
          }
          // Usuário válido fora da sua área (menu, URL digitada ou histórico):
          // volta à própria área inicial, sem encerrar a sessão (D-A00/D-A05).
          final home = homeRouteFor(user.role);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || !isRouteActive(context)) return;
            Navigator.pushReplacementNamed(context, home);
            if (user.role != UserRole.administration) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(
                    content: Text('Você não possui acesso a esta área.')));
            }
          });
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || user == null) {
          _redirect(
            context,
            snapshot.hasError
                ? _message(snapshot.error)
                : 'Entre novamente para continuar.',
          );
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppShell(
          currentRoute: currentRoute,
          authService: authService,
          displayName: user.name ?? user.email,
          role: user.role,
          notificationRepository: notificationRepository,
          notificationStudentId:
              user.studentIds.isEmpty ? null : user.studentIds.first,
          child: builder?.call(context, user) ?? child!,
        );
      },
    );
  }

  String _message(Object? error) => error is AuthException
      ? error.message
      : 'Não foi possível validar seu acesso.';

  void _redirect(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Um guard de rota antiga nunca pode derrubar a sessão seguinte.
      if (!context.mounted || !isRouteActive(context)) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
