import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

class AuthenticatedRouteGuard extends StatelessWidget {
  const AuthenticatedRouteGuard({
    required this.authService,
    required this.currentRoute,
    required this.child,
    required this.allowedRoles,
    super.key,
  });

  final AuthService authService;
  final String currentRoute;
  final Widget child;
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
        final user = snapshot.data;
        if (snapshot.hasError ||
            user == null ||
            !allowedRoles.contains(user.role)) {
          _redirect(
            context,
            snapshot.hasError
                ? _message(snapshot.error)
                : 'Você não possui acesso a esta área.',
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
          child: child,
        );
      },
    );
  }

  String _message(Object? error) => error is AuthException
      ? error.message
      : 'Não foi possível validar seu acesso.';

  void _redirect(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
