import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

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

    return 'Nao foi possivel validar o acesso administrativo.';
  }

  void _redirectToLogin(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
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
