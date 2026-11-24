import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'authenticated_route_guard.dart' show homeRouteFor, isRouteActive;

class AdminRouteGuard extends StatelessWidget {
  const AdminRouteGuard({
    required this.authService,
    required this.builder,
    super.key,
  });

  final AuthService authService;
  final Widget Function(BuildContext context, AppUser user) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authService.adminSessionChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminValidationLoading();
        }
        // Rota já removida (saída da conta): não reage ao fim da sessão.
        if (!isRouteActive(context)) {
          return const _AdminValidationLoading();
        }

        final error = snapshot.error;
        if (error is NotAdminSessionException) {
          // Outro perfil com sessão válida: volta à própria área (D-A05).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || !isRouteActive(context)) return;
            Navigator.pushReplacementNamed(context, homeRouteFor(error.role));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(const SnackBar(
                  content: Text('Você não possui acesso a esta área.')));
          });
          return const _AdminValidationLoading();
        }

        if (snapshot.hasError) {
          _redirectToLogin(context, _messageForError(snapshot.error));
          return const _AdminValidationLoading();
        }

        final user = snapshot.data;
        if (user == null) {
          _redirectToLogin(context, 'Entre novamente para continuar.');
          return const _AdminValidationLoading();
        }

        return AppShell(
          currentRoute: AppRoutes.admin,
          authService: authService,
          displayName: user.name ?? user.email,
          role: user.role,
          child: builder(context, user),
        );
      },
    );
  }

  String _messageForError(Object? error) {
    if (error is AuthException) {
      return error.message;
    }

    return 'Não foi possível validar o acesso administrativo.';
  }

  void _redirectToLogin(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || !isRouteActive(context)) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
      );

      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}

class _AdminValidationLoading extends StatelessWidget {
  const _AdminValidationLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
